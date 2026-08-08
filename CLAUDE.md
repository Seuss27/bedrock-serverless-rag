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
> (**BR-D1..BR-D26**). It is also the **threat model**.
>
> Three facts shape every judgement call here. **This repo is PUBLIC.** **`main` IS protected
> AND CI can no longer apply to AWS without a human approval** — S0 landed 2026-08-05, so the
> `protected-integration-branches` ruleset is live and `pr-title` is a required check that
> genuinely blocks a merge; and **`S1a` landed 2026-08-08** (PR #69), so `tofu-apply` sits
> behind the `production` Environment with a required reviewer. **Do not assume either is
> absent — and do not assume more than they give you.** The gate is *one human click*, and the
> role it releases is still F1's admin-capable one until `S2`. ~~**S1 has not landed**, so the
> `-auto-approve` path in `deploy-ai-lab.yml` is still ungated — that half is unchanged.~~
> *(This paragraph has now been wrong in **both** directions. Until 2026-08-06 it read "`main`
> has no branch protection … assume nothing in `.github/workflows/` is blocking anything";
> until 2026-08-08 it still said the apply path was ungated, three days after the ruleset
> claim beside it had been corrected for the identical reason. **Both halves are now true and
> measured** — the pause was observed on run `31272226259`, not read off the YAML.)* And ~~**the committed IaC does not describe the deployed system**: the resources
> exist in AWS but are absent from the state CI reads~~ **corrected 2026-08-07 by `MW`-T5: that
> split brain is reconciled.** A from-scratch `environments/ai-lab` apply under admin SSO
> — by teardown and rebuild, never by import (BR-D19, reversed by BR-D20: the corpus is
> empty, so importing would be slower, riskier, and would freeze the current bad resource
> names into the configuration) — put every declared resource into state. ~~**What is still
> true, and is the harder half:** proven *permissions* are not a proven *pipeline* … and
> **no CI apply has ever succeeded** (F39/F51 — every push-to-`main` run remains `failure`)
> … Treat `tofu plan` output as trustworthy for `environments/ai-lab` **locally, under admin
> SSO** — CI's own plan step currently fails before it gets that far, on an unrelated
> missing-variable gap.~~
> **✅ ALL OF THAT IS SPENT — corrected 2026-08-08, and it had gone stale in three separate
> ways at once.** `MW`-T6 proved the CI-driven cycle (**F39 and F51 both closed**): a CI
> apply built all 12 resources from scratch, and `destroy-ai-lab` has since torn all 12 down
> in a single clean pass (run `31274829358`). `tofu-plan-main` now succeeds in CI on every
> push to `main`, so the missing-variable gap is gone too and **CI plan output is as
> trustworthy as a local one**. `state_access_policy` still holds `MW`-T5's widened verb set
> (F55, closed 2026-08-07) until `S2`-T2 deletes the whole resource.
> **What replaces it as the harder half:** a *working* pipeline is not a *least-privileged*
> one. The role CI applies with is still F1's escalation-capable role, and until `S2` retires
> it the `production` Environment approval is the only control in front of it.

## The working method (owned elsewhere — do not restate it here)

Session protocol, Global Conventions, commit/branch grammar, the merge bar, model routing,
and the review agents come from the **`way-of-working` plugin** (`glunk-works/claude-workbench`,
pinned to a tag in `.claude/settings.json`), parameterized by
**[`.ai/project.yml`](.ai/project.yml)** — this repo's required checks, green gate, code
paths, and the paths to the deep record. Read `.ai/project.yml` at the start of a session;
never copy its values into this file, and never shadow a plugin skill with a local copy of
the same name. Both rules, and why, are in the plugin's `reference/project-schema.md`.

**One** of its values is **`null` on purpose today**, and a skill must take the no-gate branch
rather than invent one: `review.ci_gate` (no `architect-review` check — BR-D14).

⚠️ **`ruleset` is NOT null — read it, do not assume it.** It is populated with the live
`protected-integration-branches` values (four rule types, `required_checks: [pr-title]`). This
paragraph asserted the opposite until 2026-08-06, which is worse than a stale fact: it is the
one sentence here that routes a plugin skill down a branch, so it told every skill to behave as
if no gate existed on a repo that has one.

## Local: OpenTofu

- `tofu fmt` is the formatter of record; `tofu validate` must exit 0. Validate with
  `tofu init -backend=false` so no AWS credentials are needed — only a real `plan`/`apply`
  gets creds.
- **`-backend=false` fails in a directory that has already been initialized against the S3
  backend** (`.terraform/terraform.tfstate` still names it, so init reaches for credentials
  and dies on IMDS). This is a local-workstation wrinkle only — CI checks out clean. Run
  `tofu init -backend=false -reconfigure`, or validate from a clean copy.
- **No infra change reaches AWS without a visible plan and a human approval** (BR-D2).
  ~~This is currently **violated by `deploy-ai-lab.yml`**, which runs `tofu apply -auto-approve`
  on every push to `main` with no environment gate — S1-T5 fixes it.~~ **✅ HELD as of
  2026-08-08 (`S1a`-T5, PR #69):** `tofu-plan-main` publishes the summary, `tofu-apply` is
  gated on the `production` Environment, and it applies **the saved plan file** rather than
  re-planning. **`-auto-approve` is permitted in exactly two places and nowhere else** —
  `tofu-apply`, because the Environment approval already happened; and `destroy-ai-lab`, whose
  approval is the typed confirm phrase plus a human watching the run (BR-D25). **Do not add a
  third**, and do not add any new path that reaches AWS without one of those two forms of
  approval in front of it.
- **`tofu plan` output is summarized, never dumped** (BR-D4). This repo is public and plan
  output renders the account id, bucket names, role ARNs, and the AOSS collection endpoint
  at runtime even though none are committed. `-no-color` into a world-readable log is a
  disclosure, not a debugging convenience. Emit change counts + resource addresses only.
- One concern per module; inputs via `variables.tf`, outputs via `outputs.tf`. **Pin
  provider versions** — and note the current split (`~> 5.0` in `environments/ai-lab`,
  `~> 6.0` in `bootstrap`) is drift to reconcile (S3-T7), not an intended matrix.
- **Never hardcode a resource name that a sibling resource also references as a string.**
  `opensearch.tf`'s collection name and `bedrock.tf`/`create_index.py`'s vector index name
  both closed this way (MW-T6, opportunistic): each now derives from one `local` — the
  independently-hardcoded literal is exactly how two resources referencing the same name
  silently diverge, surfacing as an unauthorized data plane rather than a plan error. Apply
  the same pattern to any new resource pair that shares a name.
- Remote, locked state only — never commit `.tfstate` or `.terraform/`. No secrets in `.tf`
  or `.tfvars`.

## Local: GitHub Actions security

- **⚠️ A `pull_request`-triggered job runs the workflow file *from the PR branch*.** This is
  the rule the rest of this section depends on, and it is why **F3** ("one role for plan and
  apply") is not a least-privilege smell but **arbitrary command execution with
  account-admin-capable credentials**. `deploy-ai-lab.yml` runs on `pull_request` and assumes
  the deploy role ARN (`secrets.AWS_OIDC_ROLE_ARN` since `MW`-T6's BR-D21 storage-mechanism
  correction below — the trust policy this paragraph is about is unaffected), whose live trust is `StringLike` over
  `repo:<owner>@<org_id>/<repo>@<repo_id>:*` — which **still admits `:pull_request`**. So
  **anyone who can push a branch can edit the `run:` block and get `iam:CreateRole` on `*`** in
  the account holding bounty-infra's findings archive. Any change that gives a `pull_request`
  job a credential is a change to who can execute code as that credential.
  > **Two corrections, 2026-08-07, and the second one is the trap.** *(a)* The subject was
  > `repo:<owner>/<repo>:*` until ST-T3 narrowed it; it is now a **single** subject rather than
  > a glob over owners — **and the conclusion above is completely unchanged**, because the
  > trailing `:*` is the part that admits `:pull_request` (**F2**, still open, closed in S2-T2).
  > *(b)* **An org-owned repo presents an ID-QUALIFIED subject** —
  > `repo:<owner>@<org_id>/<repo>@<repo_id>:<context>` — which a plain
  > `repo:<owner>/<repo>:*` glob **does not match**. That is what broke CI authentication at
  > the transfer, measured from CloudTrail. **Do not "simplify" this to the plain form**, and
  > do not trust `gh api .../actions/oidc/customization/sub`'s `use_immutable_subject: false` —
  > it contradicts observed behaviour; read `sub_claim_prefix` and confirm against CloudTrail.
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
  gated job — it renames the check run and silently un-requires the gate. ~~`deploy-ai-lab.yml`
  currently has `name:` on both jobs; they must be removed *before* those jobs are required.~~
  **Done 2026-08-08 by `S1a`-T5.** One `name:` survives, on `destroy-ai-lab`, and it is
  **correct**: that job is `workflow_dispatch`-only and can never be a required check, so the
  rule does not bind it. **The rule binds the job's eligibility, not the file** — apply it to
  any job that is or could become required.
- **A required check on a path-filtered workflow deadlocks** — a PR touching only `docs/` would
  leave it pending forever and the PR unmergeable. ~~`deploy-ai-lab.yml` filters on `paths:`
  today; the filter comes off in the same change that makes a job required.~~ **Removed
  2026-08-08 by `S1a`-T5, and note the live consequence rather than re-deriving it:
  EVERY merge to `main` — docs-only ones included — now runs `tofu-plan-main` + `tofu-apply`
  and queues an Environment approval.** That is deliberate and accepted: it exercises the gate
  on every merge instead of once at the end, and a no-op apply costs about a minute. **Do not
  "optimize" it back** with a `paths:` filter or a skip-if-no-changes short-circuit.
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
for infrastructure work; ~~the project currently **fails** it (F51)~~ **the project PASSES it as
of 2026-08-08 — `MW`-T6 closed F51 with a full CI-driven cycle, and a later `destroy-ai-lab`
dispatch tore all 12 resources down in one clean pass (run `31274829358`).** The test is not
retired by passing once: `S1b`-T2 **deletes the workflow file that proof was measured against**,
which is why re-running the cycle against the split `ci.yml`/`deploy.yml` is `S1b`'s own
Definition of Done. **As of this writing the lab is deliberately torn down** — nothing is
deployed, and a merge to `main` will offer to rebuild it (see `.ai/next-steps.md`).

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
  Actions *variables* and tofu variables, and never in a workflow log (BR-D4). ~~They go in
  GitHub Actions *variables*~~ **Correction, 2026-08-07, and it is a GitHub-specific
  exception, not a repeal:** for a value used inside a **GitHub Actions workflow run**
  specifically, that clause is false. Measured live (`MW`-T6, run `31226198865`, deleted
  after capture): GitHub Actions dumps every `vars.*` value used anywhere in a job — an
  `env:` block, a `with:` input, doesn't matter — into the auto-generated log preamble it
  prints for **every step, `uses:` steps included**, before that step's own script logic
  ever runs. There is no ordering fix: even the first step of a job already carries the
  job-level `env:` dump in its own preamble. Only `secrets.*` is masked, unconditionally,
  from the first log line onward. So on GitHub specifically, "restricted, use a variable"
  and "never in a workflow log" are in direct conflict, and `secrets.*` is the only
  mechanism that delivers what this rule actually wants. `deploy-ai-lab.yml`'s deploy role
  ARN, the source bucket name, and the AOSS data-plane SSO principal ARN now ride
  `secrets.*` for exactly this reason — restricted-not-secret by this rule's own
  definition, but a workflow-log exception to it, recorded in-file at each use. **The rule
  is unchanged everywhere else** — `.env`, `tofu` CLI invocations outside CI, and anywhere
  not subject to a GitHub Actions step preamble still use variables as this rule says.
- **Infisical is GONE** — deleted in **S0** (PR #20), not merely commented out, and
  `grep -rni infisical` over `modules/`, `environments/`, `bootstrap/` and `.github/` returns
  nothing. *(This bullet said "being removed (S3-T8) … dead commented-out code" until
  2026-08-06; the removal moved earlier and `S3-T8` no longer exists.)* The README still **describes**
  Infisical in three lines of stale prose (`README.md:5`, `:13`, `:26`) — tracked as #8, fixed
  in S6-T1. *(Corrected 2026-08-07: this read "the README still **tells readers to provision a
  machine identity** for it." It did on 2026-08-05; **S0-T7 deleted the Infisical prerequisite
  and the `INFISICAL_*` lines from the `.env` block in the same PR that deleted the code**, so
  what is left describes an integration that no longer exists rather than instructing anyone to
  create a credential. The distinction matters: one is a live instruction to mint the exact
  credential F52 says to revoke, the other is a stale sentence.)* Do not revive either.
- ~~This repo holds **no secrets** today — that is why the pattern is being set now, before the
  first one exists.~~ **Corrected 2026-08-07: this repo holds exactly ONE secret** —
  `BUDGET_NOTIFICATION_EMAIL`, created by S0-T8 on 2026-08-06 and read by `deploy-ai-lab.yml`
  as a `TF_VAR_`. It is an email address, i.e. **PII**, which is what makes it a secret rather
  than a BR-D4 *restricted* variable. **It is a GitHub Actions secret, not an SSM parameter,
  and that is a recorded exception rather than a violation** — a value a workflow needs at job
  start has no SSM path it can read at that moment. The three-tier rule above is unchanged;
  only the "before the first one exists" framing expired.

## Local: what must not be committed

This repo is **public**. Genuine secrets never land in git; local values live in `.env`
(gitignored) and CI values in GitHub Actions **variables** — ~~not the tree~~ **or, inside
`deploy-ai-lab.yml` specifically, `secrets.*`; see the BR-D21 tier-2 correction above** —
either way, not the tree. Account
identifiers, role ARNs, the state bucket name, and the AOSS collection endpoint are
**restricted** — they are not credentials, but on a public repo they are free
reconnaissance, so they must not reach a PR comment, a workflow log, or a build artifact
(BR-D4). Source documents and their embeddings live in S3 and the vector store only; never
paste retrieved chunks or a model answer into an issue.

**BR-D4 also binds the commands an agent runs, not just what gets committed.** A read-only
command that *prints* a restricted value pulls it into a session transcript, which can be
summarized, logged, or pasted onward — the value is disclosed before anyone decides to commit
anything. **Prefer the projection that omits values:**

- `gh variable list --json name` — the bare form prints every variable's value in full,
  restricted or not. *(Found live 2026-08-07 during an ST-T5 verification step, against
  `AWS_OIDC_ROLE_ARN`, i.e. the account id — that specific variable is deleted as of
  `MW`-T6's BR-D21 correction, moved to `secrets.*`, but the command's behavior is general
  and binds any restricted variable this repo adds later.)*
- `gh secret list` is safe — it never prints values — but `gh variable list` is not, and the
  two look symmetrical.
- `tofu output` / `tofu show` render state, which renders everything; `nonsensitive()` and a
  `length()`/hash check are the pattern (§ 9.5 of the roadmap).
- `aws sts get-caller-identity`, `aws iam get-role` and `aws opensearchserverless
  batch-get-collection` all return restricted values — read them when you must, and quote
  **resource names** rather than ARNs when writing the result down.

The rule is the same one the workflow-log bullet states, applied one layer earlier: **decide
you need the value before you print it.**

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

# `TF_VAR_<name>` is OpenTofu's own variable mechanism and `AWS_PROFILE` is the SDK's — no
# wrapper is involved in either. The first three are what the wrapper used to inject; the
# fourth arrived with S0's `budget.tf`, the fifth with MW-T4's AOSS principal fix — both are
# just as required.
$env:AWS_PROFILE                      = 'admin-sso'   # bootstrap/providers.tf sets no profile (F49)
$env:TF_VAR_aws_region                = '<region>'    # has a default; override only if needed
$env:TF_VAR_data_source_bucket_name   = '<bucket>'    # no default — required
$env:TF_VAR_budget_notification_email = '<email>'     # no default — required; PII, never commit it
$env:TF_VAR_data_plane_principal_arns = '["<deploy-role-arn>","<sso-role-arn>"]'  # no default — required; HCL list literal, not comma-separated

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
  inventory (**F1–F58**), **BR-D1..BR-D26**, the sprint sequence, **§ 5.1 what BR-D23 cut and
  the premise that would bring each cut back**, the public-repo rules.
- **`sprints/*/sprint_plan.md`** — the per-sprint plans: S0, **ST**, **MW**, S1, S2, S3+S4
  (merged), S5, S6, plus **SD** which is **deferred** on a Docker precondition, not parallel.
  Each carries a **Critical review** section recording the security, logic, and execution
  objections raised against it — read that before executing the tasks, not after. **Sprints
  reshaped by BR-D23 carry a banner under the title naming what was cut, moved or kept; the
  task bodies below it were not all rewritten, so the banner wins.**
- **`glunk-works/global-bootstrap`** — **read this before touching `bootstrap/`.** It is the
  organization's IaC foundation: the org state bucket + lock table (with per-project prefix
  isolation), and **one CI role per project** generated from `var.projects` — which
  **no longer contains an entry for `bedrock-serverless-rag`**. *(It did until 2026-08-06;
  `ST-T2′` / upstream PR #5 deleted it to close **F45** by removal.)* **So this project has no
  upstream role today** — `github_actions_role_arns` holds no entry for it, and pointing
  anything there yields an **empty ARN, not an error**. CI runs on this repo's own
  `github-actions-deploy-role`; **S2-T0** re-creates the upstream entry *with* a permissions
  boundary. It **consumes** the GitHub OIDC provider as
  a `data` source; this repo **creates** one, and an AWS account can hold only one per URL.
  **They share one AWS account** (confirmed 2026-08-05), so this repo's state owns the
  federation endpoint every glunk-works pipeline depends on. It **does** carry
  `prevent_destroy` — the ST-T1 stopgap merged in PR #17 and was verified against live state
  (a targeted destroy plan fails). *(This bullet read "with no `prevent_destroy`" until
  2026-08-07; that was true at evaluation and false from 2026-08-05.)* **The guard is a
  stopgap, not the fix, and its limits are the point:** it is a plan-time guard over a **state
  entry**, so it protects nothing if the gitignored local state file is lost (**F48**), and it
  does not stop `tofu state rm` followed by a console delete. **BR-D18 is the fix** — ownership
  moves to `global-bootstrap` in S2-T3. Do not read a "protected" resource here as a solved
  problem (**F40**).
  **The ownership boundary is decided (BR-D17): `global-bootstrap` owns identity and state;
  this repo owns its workload and nothing else.** So `bootstrap/` is being **retired**, not
  hardened — do not design a role, a trust policy, or a state backend change here. Read
  roadmap § 9 and `sprints/S2_identity_least_privilege/sprint_plan.md` first. *(This paragraph
  used to end: "the org role's attached policy grants `lambda:*`/`apigateway:*`, which is **not
  this workload** (F42), and it becomes reachable the moment the repo transfers (**F45**)."
  **Both halves are spent.** The transfer happened 2026-08-06/07 and that policy was **deleted**
  before it, so **F45 is closed by removal** — no boundary was built. **F41 and F42 remain OPEN
  org-wide** against the three surviving project policies: deleting one project's entry removed
  an instance, not the pattern — `glunk-works/global-bootstrap#6`.)*
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
