# CLAUDE.md

Lean routing layer for this repo — kept small and stable so it stays prompt-cached.
What remains here is **local truth**: what this system is, and the rules that hold only
here. The portable working method does not live in this file (see § *The working method*).
The deep record (roadmap, sprint plans, decisions) is in `docs/` and `sprints/`, loaded on
demand. **Where we are right now** lives in `.ai/next-steps.md`.

## What this is

bedrock-serverless-rag provisions a **serverless Retrieval-Augmented Generation pipeline**
on AWS with OpenTofu. An S3 bucket holds source documents; an **Amazon Bedrock Knowledge
Base** (`aws_bedrockagent_knowledge_base`) embeds them with Titan Text Embeddings v2 and
stores the vectors in an **OpenSearch Serverless `VECTORSEARCH` collection**; queries go
through `bedrock-agent-runtime:RetrieveAndGenerate`.

Three OpenTofu roots, and the distinction matters for every change:

- **`bootstrap/`** — applied **by hand with human admin credentials**, never by CI. Owns the
  OpenTofu state bucket + DynamoDB lock table, the **GitHub OIDC provider**, and the
  **`github-actions-deploy-role`** that CI assumes. A diff here changes what CI is allowed
  to do in AWS; treat it as the highest-consequence file set in the repo. **It is scheduled
  for retirement** (BR-D17: `glunk-works/global-bootstrap` owns identity and state) — read
  roadmap § 9 before changing anything in it, and prefer deleting to hardening.
- **`modules/aws-bedrock-rag/`** — the reusable component: S3 source bucket, the KB
  execution role, the AOSS collection and its encryption / network / data-access policies,
  the Knowledge Base and its S3 data source, and a `terraform_data` `local-exec` that shells
  `python create_index.py` to build the vector index.
- **`environments/ai-lab/`** — the only live environment. S3 backend
  (`personal-bedrock-lab-state`, lock table `bedrock-lab-state-locks`), and the Python
  data-plane scripts (`create_index.py`, `test_rag.py`).

> **This repo is under active hardening — read the roadmap before extending it.**
> [`docs/hardening_roadmap.md`](docs/hardening_roadmap.md) is the reference of record: the
> full finding inventory from the 2026-08-05 evaluation (**F1–F58**), the sprint sequence
> (S0 governance → **ST org transfer** → **MW make-it-work** → S1 pipeline → S2 identity +
> `bootstrap/` retirement → **S3+S4 merged** data-plane and RAG → S5 Python cleanup → S6 docs;
> **SD the devcontainer is DEFERRED**, not parallel), and the locked decisions
> (**BR-D1..BR-D24**). It is also the **threat model**.
>
> Three facts shape every judgement call here. **This repo is PUBLIC.** **As of 2026-08-05
> `main` has no branch protection and CI applies to AWS with no human approval** — until S0
> and S1 land, assume nothing in `.github/workflows/` is blocking anything. And **the
> committed IaC does not describe the deployed system**: the resources exist in AWS but are
> absent from the state CI reads, and **no CI apply has ever succeeded** (F39, confirmed from
> run `26788807269`). Treat `tofu plan` output as unverified until **`MW`** reconciles state —
> **by teardown and rebuild, never by import** (BR-D19, reversed by BR-D20: the corpus is
> empty, so importing would be slower, riskier, and would freeze the current bad resource
> names into the configuration).

## The working method (owned elsewhere — do not restate it here)

Session protocol, Global Conventions, commit/branch grammar, the merge bar, model routing,
and the review agents come from the **`way-of-working` plugin** (`glunk-works/claude-workbench`,
pinned to a tag in `.claude/settings.json`), parameterized by
**[`.ai/project.yml`](.ai/project.yml)** — this repo's required checks, green gate, code
paths, and the paths to the deep record. Read `.ai/project.yml` at the start of a session;
never copy its values into this file, and never shadow a plugin skill with a local copy of
the same name. Both rules, and why, are in the plugin's `reference/project-schema.md`.

Two of its values are **`null` on purpose today** and a skill must take the no-gate branch
rather than invent one: `ruleset` (no branch protection exists yet — S0) and
`review.ci_gate` (no `architect-review` check — BR-D14).

## Local: OpenTofu

- `tofu fmt` is the formatter of record; `tofu validate` must exit 0. Validate with
  `tofu init -backend=false` so no AWS credentials are needed — only a real `plan`/`apply`
  gets creds.
- **`-backend=false` fails in a directory that has already been initialized against the S3
  backend** (`.terraform/terraform.tfstate` still names it, so init reaches for credentials
  and dies on IMDS). This is a local-workstation wrinkle only — CI checks out clean. Run
  `tofu init -backend=false -reconfigure`, or validate from a clean copy.
- **No infra change reaches AWS without a visible plan and a human approval** (BR-D2). This
  is currently **violated by `deploy-ai-lab.yml`**, which runs `tofu apply -auto-approve` on
  every push to `main` with no environment gate — S1-T5 fixes it. Do not add a second
  auto-apply path in the meantime.
- **`tofu plan` output is summarized, never dumped** (BR-D4). This repo is public and plan
  output renders the account id, bucket names, role ARNs, and the AOSS collection endpoint
  at runtime even though none are committed. `-no-color` into a world-readable log is a
  disclosure, not a debugging convenience. Emit change counts + resource addresses only.
- One concern per module; inputs via `variables.tf`, outputs via `outputs.tf`. **Pin
  provider versions** — and note the current split (`~> 5.0` in `environments/ai-lab`,
  `~> 6.0` in `bootstrap`) is drift to reconcile (S3-T7), not an intended matrix.
- **Never hardcode a resource name that a sibling resource also references as a string.**
  `opensearch.tf` writes `collection/bedrock-rag-store` as a literal inside both security
  policies while the collection resource declares the same name separately — the two can
  silently diverge and the failure surfaces as an unauthorized data plane, not a plan error.
- Remote, locked state only — never commit `.tfstate` or `.terraform/`. No secrets in `.tf`
  or `.tfvars`.

## Local: GitHub Actions security

- **⚠️ A `pull_request`-triggered job runs the workflow file *from the PR branch*.** This is
  the rule the rest of this section depends on, and it is why **F3** ("one role for plan and
  apply") is not a least-privilege smell but **arbitrary command execution with
  account-admin-capable credentials**. `deploy-ai-lab.yml` runs on `pull_request` and assumes
  `vars.AWS_OIDC_ROLE_ARN`, whose live trust is `StringLike repo:<owner>/<repo>:*` — which
  admits `:pull_request`. So **anyone who can push a branch can edit the `run:` block and get
  `iam:CreateRole` on `*`** in the account holding bounty-infra's findings archive. Any change
  that gives a `pull_request` job a credential is a change to who can execute code as that
  credential.
- **Never interpolate `${{ }}` inline into a `run:` block** — *or into an
  `actions/github-script` `script:` block, which is `run:`-equivalent for injection.* Pass
  values via `env:` (read them as `process.env.X` in `github-script`), quote every expansion,
  and build JSON with `jq -n --arg` — never string concatenation. **A grep that only checks
  `run:` positions will pass a `github-script` step containing
  `${{ github.event.pull_request.body }}`** — attacker-controlled text, straight into a
  JavaScript context.
- **`${{ }}` inside `if:` is also injectable** when the expression embeds attacker-controlled
  text (a PR title, a branch name, an issue body). "Only in `env:`/`with:`/`if:`" is a rule
  about *where*, not about *what* — the value's provenance still matters.
- **Never `pull_request_target`, `workflow_run`, or `issue_comment`/chatops triggers.** All
  three execute in the **base-repo** context with the full token and secrets, which is exactly
  the property `pull_request` deliberately lacks. `workflow_run` is the one someone reaches
  for to post a plan summary back onto a PR without an artifact — don't; that is S1's accepted
  residual and it stays accepted.
- `set -euo pipefail` at the top of any non-trivial `run:` block.
- Pin third-party actions to a **commit SHA**, not a floating tag — a mutable tag on an
  action that receives OIDC claims is a credential handoff to whoever moves the tag. No
  action in this repo is SHA-pinned today (S1-T1).
- Use `persist-credentials: false` on `actions/checkout` unless a later step provably needs
  the token on disk.
- **Required checks match by check-run name = job id**, so never add a `name:` override to a
  gated job — it renames the check run and silently un-requires the gate. `deploy-ai-lab.yml`
  currently has `name:` on both jobs; they must be removed *before* those jobs are required.
- **A required check on a path-filtered workflow deadlocks.** `deploy-ai-lab.yml` filters on
  `paths:` today; a PR touching only `docs/` would leave the required check pending forever
  and the PR unmergeable. The filter comes off in the same change that makes a job required.
- Fork PRs get no secrets, and that is the correct outcome — see the trigger rule above.
- Grant the **narrowest `permissions:`** that works and delete unused ones.
- **Secrets and identity never reach a workflow log.** No `aws sts get-caller-identity`
  echo, no `set -x` around a credentialed step, no raw plan dump (BR-D4).

## Local: the RAG trust boundary

- **Documents ingested from S3 are untrusted input**, exactly like network input. Their text
  reaches the model as retrieved context on every `RetrieveAndGenerate` call, so a document
  is an **indirect prompt-injection vector**. Anyone who can `PutObject` into the source
  bucket can influence every answer the system gives.
- **No Bedrock Guardrail is attached today**, so there is currently no input or output
  filtering between a hostile document and the model's answer. S4-T1 provisions one; do not
  add a new retrieval path before it lands without recording why.
- **Retrieval is unfiltered** — every query can reach every chunk. There is no
  document-level or tenant-level access control. This is an accepted lab posture (BR-D11),
  not an oversight, and it is the constraint that must be revisited before any second
  consumer or any non-public source document.
- **`create_index.py` deletes the index if it already exists** — a destructive path reachable
  from a `tofu apply` whose only trigger is the collection id changing. *Today this costs
  nothing: the index is empty (BR-D20), so it is a forward-looking rule under BR-D10, not an
  urgent fix.* It becomes a data-loss path the day the first real document is ingested — which
  is why the guard goes in before then, not after (S4-T4).
- Model ids are **pinned, dated strings** (`amazon.titan-embed-text-v2:0`,
  `anthropic.claude-3-haiku-20240307-v1:0`). Changing the embedding model changes the
  required index `dimension` — the two are one atomic change, and getting it wrong produces
  runtime ingestion failures, not a plan error.

## Local: ephemerality is the design goal (BR-D20)

**Nothing in this workload is precious.** The project exists to be stood up and torn down,
and the RAG corpus is empty. So: prefer **rebuilding correctly over migrating carefully**,
let a resource be replaced rather than contorting a change to avoid it, and never let a
data-preservation caution shape a decision — there is no data. A clean
**`destroy` → `apply` → verify** cycle is a *functional requirement* and the acceptance test
for infrastructure work; the project currently **fails** it (F51).

**The hard edge, and the one that matters:** what is ephemeral is the *workload*, not the
*blast radius*. The AWS account is shared with the whole organization — it holds
`global-bootstrap`'s state and **bounty-infra's KMS-encrypted findings archive**. Never delete
or weaken anything shared: the GitHub OIDC provider above all (F40, BR-D18). "Nothing here is
precious" is true of this lab and false of the account it runs in.

## Local: secrets come from AWS, never Infisical (BR-D21)

- **Secrets** — anything whose disclosure is itself the harm — live in **AWS SSM Parameter
  Store** `SecureString` at `/bedrock-serverless-rag/<env>/<name>`, read via
  `data.aws_ssm_parameter`. Parameter Store rather than Secrets Manager by default: the
  standard tier is free and this is a cost-sensitive ephemeral lab. Secrets Manager needs a
  recorded reason (rotation, cross-account).
- **Restricted but not secret** — account id, role ARNs, bucket names, the collection
  endpoint — are **not** secrets and do not belong in a secret store. They go in GitHub
  Actions *variables* and tofu variables, and never in a workflow log (BR-D4).
- **Infisical is being removed** (S3-T8). The provider, data source and variable are dead
  commented-out code; the README still tells readers to provision a machine identity for it.
  Do not revive either. This repo holds **no secrets** today — that is why the pattern is
  being set now, before the first one exists.

## Local: what must not be committed

This repo is **public**. Genuine secrets never land in git; local values live in `.env`
(gitignored) and CI values in GitHub Actions **variables**, not the tree. Account
identifiers, role ARNs, the state bucket name, and the AOSS collection endpoint are
**restricted** — they are not credentials, but on a public repo they are free
reconnaissance, so they must not reach a PR comment, a workflow log, or a build artifact
(BR-D4). Source documents and their embeddings live in S3 and the vector store only; never
paste retrieved chunks or a model answer into an issue.

## Commands

The **green gate** — what must pass before a PR — is `gates.green` in `.ai/project.yml`, not
restated here. The rest of the local toolchain:

**Native `tofu` only.** The `Invoke-Tofu.ps1` wrapper was **deleted 2026-08-05** — it existed
solely to load `environments/ai-lab/.env` into the session before shelling `tofu`, which
OpenTofu and the AWS SDK already do natively through environment variables. A gitignored
wrapper meant the one thing making local development work lived on a single machine, invisible
to review, to CI, and to anything reproducible (**F49**). Do not reintroduce it, and do not
write a new wrapper under another name.

```powershell
aws sso login --profile admin-sso

# Set the same three values the wrapper used to inject. `TF_VAR_<name>` is OpenTofu's own
# variable mechanism and `AWS_PROFILE` is the SDK's — no wrapper is involved in either.
$env:AWS_PROFILE                     = 'admin-sso'   # bootstrap/providers.tf sets no profile (F49)
$env:TF_VAR_aws_region               = '<region>'    # has a default; override only if needed
$env:TF_VAR_data_source_bucket_name  = '<bucket>'    # no default — required

tofu -chdir=environments/ai-lab plan
```

`environments/ai-lab/.env` stays as the **gitignored record of which values to set**, not as
something a script sources. Those values are BR-D4 *restricted* — a bucket name and a region on
a public repo are free reconnaissance — so they belong in the shell or a repository variable,
never in a committed `.tf` or `.tfvars`.

A real `plan`/`apply` needs SSO credentials and the S3 backend; it does not run cleanly from a
bare checkout by design.

**Git Bash's `gpg` is not the `gpg` git uses.** Git Bash resolves a bare `gpg` command to its
own bundled `/usr/bin/gpg`, which has an **empty keyring** — running `gpg --list-secret-keys`
or a manual `gpg --clearsign` there to debug commit signing proves nothing about what `git`
actually does. `git` (and PowerShell) resolve to the real Windows GnuPG install instead
(`gpg.exe` under `Program Files\GnuPG\bin`), which holds the key `user.signingkey` points at.
If commit signing needs debugging, invoke that binary explicitly or just retry the real
`git commit` — don't diagnose from a bare `gpg` call in Git Bash. Separately, if the
workstation has more than one secret key, a manual `gpg` command with no `-u` picks GnuPG's
own default key, which is not necessarily the one `git` is configured to sign with — a
mismatch there is not evidence of misconfiguration.

## Pointers (load on demand)

- **`.ai/next-steps.md`** — the live cursor: current sprint/task, next action, which model.
  Read this first.
- **`.ai/project.yml`** — this repo's parameterization of the working method.
- **`docs/hardening_roadmap.md`** — reference of record **and threat model**: the finding
  inventory (**F1–F58**), **BR-D1..BR-D24**, the sprint sequence, **§ 5.1 what BR-D23 cut and
  the premise that would bring each cut back**, the public-repo rules.
- **`sprints/*/sprint_plan.md`** — the per-sprint plans: S0, **ST**, **MW**, S1, S2, S3+S4
  (merged), S5, S6, plus **SD** which is **deferred** on a Docker precondition, not parallel.
  Each carries a **Critical review** section recording the security, logic, and execution
  objections raised against it — read that before executing the tasks, not after. **Sprints
  reshaped by BR-D23 carry a banner under the title naming what was cut, moved or kept; the
  task bodies below it were not all rewritten, so the banner wins.**
- **`glunk-works/global-bootstrap`** — **read this before touching `bootstrap/`.** It is the
  organization's IaC foundation: the org state bucket + lock table (with per-project prefix
  isolation), and **one CI role per project** generated from `var.projects` — which already
  contains an entry for `bedrock-serverless-rag`. It **consumes** the GitHub OIDC provider as
  a `data` source; this repo **creates** one, and an AWS account can hold only one per URL.
  **They share one AWS account** (confirmed 2026-08-05), so this repo's state owns the
  federation endpoint every glunk-works pipeline depends on, with no `prevent_destroy`
  (**F40** — ST-T1 is the stopgap, BR-D18 the fix).
  **The ownership boundary is decided (BR-D17): `global-bootstrap` owns identity and state;
  this repo owns its workload and nothing else.** So `bootstrap/` is being **retired**, not
  hardened — do not design a role, a trust policy, or a state backend change here. Read
  roadmap § 9 and `sprints/S2_identity_least_privilege/sprint_plan.md` first. Note also that
  the org role's attached policy grants `lambda:*`/`apigateway:*`, which is **not this
  workload** (F42), and that it becomes reachable the moment the repo transfers (**F45**).
- **`glunk-works/claude-workbench`** — the `way-of-working` plugin: skills, agents, the
  Global Conventions, and `reference/project-schema.md`.
- **`glunk-works/bounty-infra`** — the sibling IaC repo already running this method. Read
  its `.github/workflows/` before designing a CI or governance pattern here, so the two stay
  diffable. Its `CLAUDE.md` records the org precedent this repo has not yet adopted:
  global-bootstrap owns **every** GitHub OIDC role, and a new workflow trigger generally
  needs a *new* role from there rather than a widened one locally.

> Note: **`README.md` is stale and is not trusted** — it documents a flat root-level layout
> (`bedrock.tf`, `iam.tf` at the repo root) that the module refactor retired, and a Titan v1
> embedding model the code no longer uses. Tracked as #8; rewritten in S6. Trust
> `docs/hardening_roadmap.md` over the README.
