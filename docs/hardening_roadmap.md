# Hardening roadmap — bedrock-serverless-rag

**Reference of record.** This file is the deep record: the evaluation that produced the
work, the locked decisions, the sprint sequence, and the public-repo data-handling rules.
It doubles as this repo's **threat model** (`.ai/project.yml: threat_model`), so
`security-critic` reads it as ground truth. `CLAUDE.md` routes; this file explains.

The live cursor — which sprint, which task, which model — is `.ai/next-steps.md`, not here.

- **Evaluated:** 2026-08-05, against `main` @ `429ca10`.
- **Posture today:** public repo, no branch protection, CI applies to AWS unreviewed with a
  role that can escalate to account administrator. Sprints S0–S2 exist to close that
  sentence; everything after hardens what is left.

> ### ⚠️ Scope correction, 2026-08-05 — nothing in this workload is precious (BR-D20)
>
> The operator confirmed this project is **ephemeral by design**: built to be spun up and
> torn down, nothing in it is "live", and the RAG corpus is **empty**. Breaking changes are
> acceptable and carry no consequence.
>
> That does **not** flatten this roadmap — it **re-ranks** it, along one line:
>
> **What is ephemeral is the workload. What is not ephemeral is the blast radius.**
>
> - **Unchanged, and now unambiguously the top priority:** anything reaching the **shared AWS
>   account** — **F1**, **F41**, **F47** (five CI roles that can each become account
>   administrator, in the account holding bounty-infra's findings archive), **F45** (the
>   transfer activating one of them), **F40**/**F48** (this repo's state owning the OIDC
>   provider the whole organization authenticates through). None of that is disposable
>   because this lab is.
> - **Unchanged:** the governance and pipeline work (**F17**, **F13**, **F33**–**F38**). A
>   repo that is rebuilt often needs its guardrails *more*, not less.
> - **Sharply downgraded, and their fixes get simpler:** everything whose severity rested on
>   *losing data or state* — **F39**, **F23**, and the replacement hazards in S3. The correct
>   remedy for those is no longer a careful migration. It is **tear it down and rebuild it
>   right** (BR-D19, reversed).
> - **Reversed outright:** `force_destroy` (S3-T2) and the "freeze the current names as
>   defaults" rule (S3-T6). Both existed to protect data that does not exist, and both were
>   working *against* the project's actual design goal.
>
> And one finding the correction creates rather than removes: **the project does not
> currently do the thing it was designed to do.** See **F51**.

---

## 1. The system, as it actually is

Three OpenTofu roots with sharply different trust levels:

| Root | Applied by | Owns | Trust level |
| --- | --- | --- | --- |
| `bootstrap/` | a human, with admin SSO credentials | state bucket, lock table, GitHub OIDC provider, `github-actions-deploy-role` | **defines what CI may do**; highest consequence |
| `modules/aws-bedrock-rag/` | CI, via the deploy role | S3 source bucket, KB execution role, AOSS collection + 3 policies, Knowledge Base + data source, `local-exec` index bootstrap | the product |
| `environments/ai-lab/` | CI, via the deploy role | S3 backend wiring, the one module instantiation, the Python data-plane scripts | the only environment |

**Dataflow.** Documents land in S3 → the Bedrock Knowledge Base chunks and embeds them with
`amazon.titan-embed-text-v2:0` → vectors and the **full chunk text** land in the OpenSearch
Serverless `VECTORSEARCH` collection → a query calls
`bedrock-agent-runtime:RetrieveAndGenerate`, which retrieves chunks and passes them, as
prompt context, to `anthropic.claude-3-haiku-20240307-v1:0`.

## 2. Threat model

### 2.1 Trust boundaries

- **TB1 — GitHub → AWS (OIDC/STS).** A GitHub Actions job presents an OIDC token; AWS
  exchanges it for credentials on `github-actions-deploy-role`. What crosses is *whatever
  the trust policy's `sub` condition admits*. Today that condition is
  `repo:<owner>/<repo>:*` — every branch, every PR, every environment (**F2**) — and the
  role it admits can create IAM roles and policies on `*` (**F1**).
- **TB2 — the repo → CI.** A merged (or pushed) commit becomes an `apply`. With no branch
  protection (**F17**) and no approval gate (**F13**), the boundary is a formality.
- **TB3 — S3 source documents → the model.** Ingested document text is **untrusted input**
  that is placed verbatim into a model prompt on every query. This is the classic **indirect
  prompt-injection** channel, and it is presently unguarded (**F22**). Anyone with
  `PutObject` on the source bucket controls part of every answer.
- **TB4 — the AOSS data plane → the internet.** The network policy is
  `AllowFromPublic = true` (**F6**). The full text of every ingested chunk sits behind a
  public endpoint with SigV4 as the only control.
- **TB5 — the public repo → the world.** Everything committed, every workflow log, every PR
  comment, and every build artifact is world-readable.

### 2.2 Assets, ranked

> **⚠ The account is shared with the whole organization** (confirmed 2026-08-05). This repo's
> state, `global-bootstrap`'s state, **and bounty-infra's KMS-encrypted findings archive** —
> third-party vulnerability data — all live in one AWS account. So the assets below are not
> this project's alone, and F1/F41/F47 are escalation paths *to all of them*.

1. **bounty-infra's findings archive** — third-party vulnerability data, the most restricted
   asset any glunk-works repo holds. Not this repo's, but reachable from this repo's CI role
   via F1 + F47.
2. The **AWS account** itself (reachable via TB1 + F1, and via four sibling roles + F41).
3. The **document corpus** and its embeddings — the chunk text is stored in cleartext in the
   vector store and is the thing the system exists to protect (TB4).
4. The **OpenTofu state** — this repo's *and* the org's; renders every ARN, bucket name, and
   account id.
5. **Account reconnaissance** — account id, role ARNs, collection endpoint (TB5, BR-D4).

### 2.3 Out of scope, deliberately

Multi-tenant isolation, per-document ACLs, and data residency: this is a single-operator lab
with a single corpus (**BR-D11**). Recorded, not ignored — this is the assumption that must
be revisited before a second consumer or any non-public source document.

---

## 3. Finding inventory

Severity is *this repo's* risk, not a generic CVSS. **Critical** = an unauthenticated or
lightly-authenticated path to account compromise or total data loss.

### 3.1 Identity and privilege

| ID | Sev | Finding | Where | Sprint |
| --- | --- | --- | --- | --- |
| **F1** | **Critical** | *(Closed in S2-T2 by **deleting** the role, not by hardening it — BR-D17. The boundary construction originally drafted here moved upstream to ST-T2 and the F41 issue.)* `state_access_policy` grants `iam:CreateRole`, `iam:PutRolePolicy`, `iam:AttachRolePolicy`, `iam:DeleteRolePolicy`, `iam:DeleteRole` on `Resource = "*"`. This is **privilege escalation to account administrator**: the CI role can mint a role with `AdministratorAccess` and attach a trust policy naming itself. The `Resource = "*"` even carries an in-file comment conceding it. | `bootstrap/state-backend.tf:82-111` | S2-T1 |
| **F2** | High | OIDC trust condition is `StringLike sub = "repo:${var.github_repo_path}:*"`. The `*` admits every branch, every `pull_request`, and every environment — and in IAM `StringLike`, `*` matches `:` too, so it also admits claim shapes that do not exist yet. **Closed by adoption:** the upstream role's trust is already `StringEquals` over an enumerated subject list. ST-T3 widens this glob temporarily during the transfer, then S2-T2 deletes the role entirely. | `bootstrap/oidc-setup.tf:37` | S2-T2 |
| **F3** | High | **One role for plan and apply.** The PR-triggered plan job assumes the same role the apply job does, so read-only review work holds credentials that can destroy the account. **Closed by adoption rather than by fixing:** `global-bootstrap`'s `plan_roles.tf` already provides a separate read-only identity trusted only on `:pull_request`, opted into by ST-T2 and switched to in S2-T2. | `bootstrap/oidc-setup.tf`, `.github/workflows/deploy-ai-lab.yml` | S2-T2 |
| **F4** | Medium | Confused-deputy: `bedrock_kb_role`'s trust policy conditions on `aws:SourceAccount` but not `aws:SourceArn`, so any Bedrock resource in the account can induce the service to assume it. Filed as **#6**. | `modules/aws-bedrock-rag/iam.tf:33-37` | S2-T4 |
| **F5** | **High** *(confirmed live 2026-08-05)* | The AOSS data-access policy names `data.aws_arn.current_identity.arn` — *whoever ran the last apply*. Locally that is a human SSO session; in CI it is the deploy role. It also resolves to an **`sts` assumed-role ARN**, not an IAM role ARN, so the granted principal can be a session that no longer exists, and alternating local/CI applies produce a perpetual diff. **This is not theoretical: run `26788807269` shows `create_index.py` failing `AuthorizationException(403, '')` six times in a row** — the policy had been applied from a human SSO session, so the CI role has no data-plane access at all. | `modules/aws-bedrock-rag/iam.tf:121` | S2 |
| **F50** | ~~High~~ **Medium** *(confirmed live 2026-08-05; downgraded by BR-D20 — the fix is a one-line commit, and a broken lab apply costs nothing)* | **`bootstrap/` has uncommitted drift, and the next `tofu apply` there would silently revoke a permission CI needs.** `tofu plan` in `bootstrap/` reports **`1 to change`**: it removes `iam:ListAttachedRolePolicies` from `state_access_policy`. That action is present in the **live** AWS policy and absent from the committed HCL, and `git log -- bootstrap/state-backend.tf` shows no commit that ever added it — so it was granted out-of-band, almost certainly to fix a failing apply. It is **needed**: the AWS provider calls `ListAttachedRolePolicies` when refreshing an `aws_iam_role`, which CI does for `bedrock_kb_role` on every plan. **Operational trap:** `bootstrap/` is human-applied with admin credentials, gets no CI and no review, so this revocation rides along with the *next* apply for any unrelated reason — e.g. ST-T1 or ST-T3 widening the OIDC trust for the transfer. CI would then break and the trust-policy change would take the blame. **Resolution: commit the action to the HCL** (code matches live) before any `bootstrap/` apply. This is F39's class — committed IaC ≠ deployed system — in the root previously assumed to be in sync. | `bootstrap/state-backend.tf:82-111` vs live | **before ST-T1** |
| **F39** | ~~Critical~~ **Medium** *(confirmed 2026-08-05; downgraded by BR-D20)* | **The OpenTofu state CI uses does not describe the deployed system.** Run `26788807269` (the last push to `main`) fails with `EntityAlreadyExists: Role with name personal-bedrock-kb-execution-role already exists` and `waiting for S3 Bucket (…-source) create: empty result`. The resources **exist in AWS**, created out-of-band with human SSO credentials, and are **absent from the state file CI reads** — a split brain. **No CI apply has ever succeeded** (every `push`-to-`main` run is `failure` or `cancelled`). **Remedy reversed by BR-D19/BR-D20:** the corpus is empty and nothing here is precious, so this is *not* an import exercise. **Delete the orphaned resources and apply clean.** That is faster, carries no data risk, and avoids freezing the current bad resource names into `import` blocks. It stays worth doing early only because `tofu plan` output is meaningless until it is done — and S3/S4 lean on plan output as an acceptance criterion. | `environments/ai-lab` state vs live AWS | S2-T1 |

### 3.1b Cross-repo coupling with `glunk-works/global-bootstrap`

`glunk-works/global-bootstrap` is the organization's centralized IaC foundation: it owns the
org state bucket + lock table, **consumes** the GitHub OIDC provider as a `data` source, and
generates one CI role per project from `var.projects` — **including an entry for this repo**.
Full analysis in § 9. These five findings come from reading it against this repo.

| ID | Sev | Finding | Where | Sprint |
| --- | --- | --- | --- | --- |
| **F40** | **High** | **OIDC provider ownership collision, with a destroy hazard.** This repo's `bootstrap/oidc-setup.tf` **creates** `aws_iam_openid_connect_provider` for `token.actions.githubusercontent.com`; global-bootstrap **reads** the same provider via `data.aws_iam_openid_connect_provider.github`. **An AWS account can hold only one provider per URL.** If both target the same account, this repo's OpenTofu state owns the federation endpoint that *every glunk-works pipeline* depends on — and unlike the state bucket, it carries **no `prevent_destroy`**. A `tofu destroy` in this repo's `bootstrap/` would break CI for the entire organization. **✅ Stopgap DONE 2026-08-05 — `prevent_destroy` merged to `main` (PR #17, `1ad5aa7`) and verified against live state: a targeted destroy plan now fails with `Instance cannot be destroyed`. The durable fix — moving ownership to `global-bootstrap` — remains open (BR-D18, S2-T3).** | `bootstrap/oidc-setup.tf:13-16` vs `global-bootstrap/main.tf:81-83` | ST-T1, S2 |
| **F41** | **Critical** *(cross-repo — not fixable here)* | **F1 exists in `global-bootstrap` too, four times over.** Every project workload policy in `project_policies.tf` grants `iam:CreateRole`, `iam:PutRolePolicy`, `iam:AttachRolePolicy`, `iam:DetachRolePolicy` and `iam:PassRole` on `Resource = "*"` — `bounty_infra_policy`, `tri_loop_policy` (which also holds `ecs:*` and `rds:*`), `bedrock_rag_policy`, `resume_optimizer_policy`. Each is the same escalation-to-account-admin as F1, at organization scope. Fixing F1 in this repo alone leaves it standing for four pipelines. | `global-bootstrap/project_policies.tf` | file upstream (§ 9) |
| **F42** | High | **The org role's policy does not match this repo's workload — and after the transfer it becomes reachable.** `bedrock_rag_policy` grants `lambda:*`, `apigateway:*`, `bedrock:InvokeModel[WithResponseStream]` — the permission set of a Lambda + API Gateway application. This repo provisions S3 buckets, an OpenSearch Serverless collection and three policies, and a Bedrock **Knowledge Base** (`bedrock:CreateKnowledgeBase`, not `InvokeModel`). Nothing in it grants `s3:CreateBucket`, `aoss:*`, or `bedrock:CreateKnowledgeBase`. If CI assumes `github-actions-bedrock-serverless-rag`, apply cannot succeed. **Must be corrected upstream BEFORE the transfer (F45).** | `global-bootstrap/project_policies.tf:144-168` | ST-T2 |
| **F43** | Medium | **Two state backends where the org pattern has one.** global-bootstrap owns `glunk-works-tofu-state-00042` + `global-tofu-lock` with genuine per-project isolation (`s3:prefix` conditions and `key = <project>/terraform.tfstate`). This repo runs its own `personal-bedrock-lab-state` + `bedrock-lab-state-locks`, outside that model — two backends, two lock tables, two sets of controls to harden. **RESOLVED: the org backend wins (BR-D17); this repo's backend is retired and its state migrated under the `bedrock-serverless-rag/` prefix.** | `bootstrap/state-backend.tf`, `environments/ai-lab/backend.tf` | S2 |
| **F44** | High | **The org scaffolding for this project is inert, because of the owner name.** `var.projects` builds the trust subject as `repo:${var.github_organization}/${repo_name}:…`, and global-bootstrap's README documents `github_organization=glunk-works` — but this repo is `Seuss27/bedrock-serverless-rag`. So `github-actions-bedrock-serverless-rag` **cannot be assumed from here at all**. The entry also sets no `plan_role = true` and no `extra_oidc_subjects`, so **S2-T3's read-only plan role and S1-T5's `environment:production` subject are both changes to `global-bootstrap`, not to this repo.** **RESOLVED 2026-08-05: the repo transfers to `glunk-works` (BR-D13), which makes the org role match — see F45 for what that silently switches on.** | `global-bootstrap/variables.tf:43-53` | ST |

### 3.1c Consequences of the two answers given 2026-08-05

The operator confirmed **(1) one shared AWS account** and **(2) the repo transfers to
`glunk-works`**. Each answer creates a finding the other does not.

| ID | Sev | Finding | Where | Sprint |
| --- | --- | --- | --- | --- |
| **F45** | **High** | **The transfer silently activates a dormant, over-privileged, wrong-workload role.** Today `github-actions-bedrock-serverless-rag` cannot be assumed from `Seuss27/…` (F44). The moment the repo becomes `glunk-works/bedrock-serverless-rag`, its trust subject `repo:glunk-works/bedrock-serverless-rag:ref:refs/heads/main` **matches** — and that role carries `lambda:*`, `apigateway:*` (F42) **and** `iam:CreateRole`/`PutRolePolicy`/`AttachRolePolicy`/`PassRole` on `Resource = "*"` (F41). So a repository-settings change, with no IaC diff anywhere, creates a **new escalation path into the shared account**. The upstream fix must land **before** the transfer, not after. | `global-bootstrap/project_policies.tf` + the transfer | **ST-T2, blocking ST-T3** |
| **F46** | Medium | **The retry loop reports an authorization failure as a propagation delay, and the most recent commit made it worse.** `create_index.py` retries any `Exception` six times; run `26788807269` shows six consecutive `AuthorizationException(403, '')` — a condition that can never resolve by waiting, because it is F5, not IAM eventual consistency. Commit `0aa56dc` raised the delay to 45 s, so CI now spends **~12 minutes** failing at it. The most recent work on this repo was tuning the wrong variable. | `environments/ai-lab/create_index.py:71-93` | S4-T4 |
| **F48** | **High** *(found 2026-08-05 while applying the F40 stopgap; severity SURVIVES BR-D20 — see below)* | **`bootstrap/`'s OpenTofu state is a local, gitignored file on one workstation.** `bootstrap/` declares **no `backend` block** — despite `state-backend.tf` creating a state bucket *for the other root*. So `bootstrap/terraform.tfstate` (plus `.backup` and a `terraform.tfvars`) lives only in the working tree, unversioned and unbacked-up, and it is the state describing the **org-shared OIDC provider**, the CI deploy role, and the state backend itself. Three consequences: **(a)** losing that laptop makes the highest-consequence root in the org unmanaged; **(b)** `prevent_destroy` (F40's stopgap) **only works while that file exists** — no state, no tracked resource, no guard; **(c)** re-applying from an empty state would try to *create* the provider and fail `EntityAlreadyExists`, reproducing F39's split brain in the one root where it hurts most. Superseded rather than fixed by BR-D17/BR-D18: `bootstrap/` is retired and its resources move to `global-bootstrap`, whose state *is* remote and locked. Until then, **back the file up out-of-band.** **BR-D20 does not downgrade this**: the state file is disposable in respect of *this repo's* resources, but it is the only record of the **org-shared OIDC provider**, whose loss is an organization-wide outage. That single resource is what makes an otherwise-disposable file matter — and moving it upstream (BR-D18) is what makes the rest of `bootstrap/` freely destroyable, as the design intends. | `bootstrap/` (no `backend` block) | S2-T3, S2-T4 |
| **F47** | **High** | **The shared account changes F1's and F41's blast radius from "a personal lab" to "the organization."** One account holds this repo's state, the org state bucket, **and bounty-infra's KMS-encrypted findings archive** — third-party vulnerability data, the most restricted asset any glunk-works repo holds (bounty-infra's BI-D4). Five CI roles in that account each hold `iam:CreateRole`/`PutRolePolicy`/`AttachRolePolicy` on `Resource = "*"` — this repo's `github-actions-deploy-role` (F1) plus all four org project roles (F41). Compromise of **any one** of the five yields account administrator, and therefore the findings archive. `global-bootstrap`'s explicit `DenyBountyFindingsDataAccess` on the *plan* roles shows the risk was seen; the *apply* roles have no equivalent. | account-wide | S2, upstream |

### 3.2 Pipeline

| ID | Sev | Finding | Where | Sprint |
| --- | --- | --- | --- | --- |
| **F51** | **High** *(created by the 2026-08-05 scope correction)* | **The project does not do the thing it was designed to do.** Its stated purpose is to be stood up and torn down on demand (BR-D20) — yet **no `tofu apply` has ever completed successfully** (every push-to-`main` run is `failure` or `cancelled`), and a full `destroy` → `apply` → verify cycle has never been demonstrated. At least four defects sit on that path: the AOSS data-access policy grants a human SSO session rather than the CI role (**F5**), the index bootstrap then fails `403` and retries for ~12 minutes (**F46**), the state is orphaned so apply collides with `EntityAlreadyExists` (**F39**), and `prevent_destroy` on the shared OIDC provider now blocks `tofu destroy` of `bootstrap/` outright until ownership moves upstream (**BR-D18**). Each was recorded separately as a security or correctness defect; together they are a **functional** one. **A clean create/destroy/create cycle is the acceptance test for S2 (BR-D20)** and the cheapest possible route to closing F39, F5 and F46 at once. | whole-system | **S2** |
| **F17** | **Critical** | **No branch-protection ruleset exists.** `gh api repos/Seuss27/bedrock-serverless-rag/rulesets` returns `[]`. `main` accepts a direct push, no check is required, and every gate in `.github/workflows/` is therefore advisory. This is the multiplier on F13 and F1. | GitHub settings | S0-T1 |
| **F13** | **Critical** | `tofu apply -auto-approve` runs on every push to `main` with **no `environment:`, no approval, no plan artifact**. With F17 and F1, one push is unreviewed admin-capable execution. | `.github/workflows/deploy-ai-lab.yml:85-87` | S1-T5 |
| **F14** | High | The apply job **re-plans** rather than applying a saved plan file, so what applies is not what was reviewed. Adding an approval without fixing this buys a signature on a different change. | same | S1-T5 |
| **F15** | High | **No action is SHA-pinned.** `aws-actions/configure-aws-credentials@v4` receives the OIDC claim on a mutable tag — moving that tag is a credential handoff. | `.github/workflows/deploy-ai-lab.yml` | S1-T1 |
| **F16** | Medium | `tofu plan -no-color` dumps the full plan into a **world-readable log on a public repo**, rendering the account id, bucket names, role ARNs, and the collection endpoint (BR-D4). | same, `:82` | S1-T6 |
| **F18** | Medium | The workflow carries a **`paths:` filter** and **`name:` overrides on both jobs**. A required check on a path-filtered workflow deadlocks (a docs-only PR leaves it pending forever); a `name:` override renames the check run and silently un-requires the gate. Both must be gone *before* any job here is required. | same, `:5,8,15,54` | S1-T2 |
| **F19** | Medium | Scanner coverage gap: Checkov runs against `modules/` **only** — `bootstrap/`, where F1 and F2 live, is never scanned. There is no tflint, no secrets scan, no dependency audit, no SBOM, and no workflow-security scan. | same, `:37-42` | S1-T3, S1-T4 |
| **F20** | Medium | No `concurrency:` group. Two merges in quick succession race for the same state; the DynamoDB lock turns that into a hard failure rather than a queue. | same | S1-T7 |
| **F21** | Low | `actions/checkout` without `persist-credentials: false` leaves a usable token on disk for every later step. | same | S1-T1 |

### 3.3 Data plane and IaC posture

| ID | Sev | Finding | Where | Sprint |
| --- | --- | --- | --- | --- |
| **F6** | High | AOSS network policy sets `AllowFromPublic = true` for **both** the collection and its **dashboard** endpoint. The vector store holds the full text of every chunk; SigV4 is the only boundary and there is no network one. | `modules/aws-bedrock-rag/opensearch.tf:25-41` | S3-T1 |
| **F7** | High | The S3 source bucket has **no public-access block**, **no versioning**, **no TLS-only bucket policy**, **no access logging**, and `force_destroy = true`. The public-access block is the single highest-value missing control: nothing structurally prevents a future policy change from exposing the corpus. | `modules/aws-bedrock-rag/iam.tf:3-17` | S3-T2 |
| **F8** | Medium | The **state** bucket has versioning and SSE but no public-access block and no TLS-only policy. `prevent_destroy` guards the bucket but **not** the lock table — a `tofu destroy` in `bootstrap/` silently removes state locking while leaving state intact. | `bootstrap/state-backend.tf` | S3-T3 |
| **F9** | Medium | `AWSOwnedKey = true` on the AOSS encryption policy; `AES256` (SSE-S3) on both buckets. No customer-managed key means no key policy, no rotation control, no revocation, and no CloudTrail record of key use over the corpus. | `opensearch.tf:15`, `iam.tf:14`, `state-backend.tf:32` | S3-T4 |
| **F10** | Medium | **Zero tags on every resource.** The conventions require owner + managing-repo on everything so drift is attributable, and this system bills OpenSearch Serverless OCUs hourly with no cost attribution. | all `.tf` | S3-T5 |
| **F11** | Medium | Hardcoded, unparameterized names (`bedrock-rag-store`, `personal-rag-index`, `serverless-rag-kb`, `personal-bedrock-kb-execution-role`), and `collection/bedrock-rag-store` written as a **string literal** in both security policies instead of referencing the collection resource. The module cannot be instantiated twice, and a rename desynchronizes policy from collection — which surfaces as an unauthorized data plane, not a plan error. | `opensearch.tf:11,31`, `bedrock.tf:3,20`, `iam.tf:22` | S3-T6 |
| **F49** | Low *(demonstrated 2026-08-05)* | **`bootstrap/` cannot be run by following the README.** `bootstrap/providers.tf` declares only `region` — no `profile` — so the AWS provider falls through to the default credential chain and dies on IMDS unless `AWS_PROFILE` is exported first. The README's Step 2 says `aws sso login --profile admin-sso` but never says to export it, and `$env:AWS_PROFILE` does not survive a new shell. The sibling `glunk-works/global-bootstrap` gets this right (`profile = var.aws_profile`, default `admin-sso`). **And the local workaround makes it worse, not better:** `AWS_PROFILE` *is* set in the untracked `.env`, sourced by `Invoke-Tofu.ps1` — a helper that is **gitignored**, so the one thing making local development work exists on a single machine, invisible to review, to CI, and to the devcontainer. A repo whose usability depends on an unshippable file is not reproducible; SD is the structural answer. Minor in normal use; **material in a break-glass**, which is exactly when nobody wants to debug a credential chain — so the fix belongs with the runbook that assumes it works. | `bootstrap/providers.tf:10-12`, `README.md` | S6-T2 |
| **F12** | Low | Provider constraint split: `~> 5.0` in `environments/ai-lab`, `~> 6.0` in `bootstrap`. The backend also uses `dynamodb_table`, superseded by native S3 locking in provider 6. | `providers.tf` ×2, `backend.tf` | S3-T7 |

### 3.4 RAG implementation

| ID | Sev | Finding | Where | Sprint |
| --- | --- | --- | --- | --- |
| **F22** | High | **No Bedrock Guardrail exists or is attached.** `retrieve_and_generate` is called with no `guardrailConfiguration`, so untrusted document text reaches the model and the model's answer reaches the user with no input or output filtering. This is the unmitigated form of TB3. | `environments/ai-lab/test_rag.py:30-41`; absent from `modules/` | S4-T1 |
| **F23** | ~~High~~ **Low** *(downgraded by BR-D20 — the index is empty; this is a rule for the future, not a live risk)* | `create_index.py` **deletes the index if it exists** before creating it — destroying every embedding — on a path reachable from `tofu apply` whose only trigger is the collection id. A recovery means a full re-ingest, at cost. | `environments/ai-lab/create_index.py:78-80` | S4-T4 |
| **F24** | Medium | No Bedrock model-invocation logging and no CloudTrail data events for S3 or AOSS. There is **no record** of what was asked, what was retrieved, or what was answered — so a successful prompt injection leaves no evidence. | absent | S4-T2 |
| **F25** | Medium | No ingestion controls: any object of any type or size is ingested, with no provenance metadata, no declared `vector_ingestion_configuration` chunking, and no allowlist. Chunking silently takes a provider default the field mapping depends on. | `modules/aws-bedrock-rag/bedrock.tf:39-49` | S4-T3 |
| **F26** | Low | `local-exec` inside a **reusable module** shells `python create_index.py` with a path relative to the *caller's* working directory. It works only because the single caller happens to sit beside the script; the module is not portable, and it silently requires Python + four packages on whatever runs `apply`. | `modules/aws-bedrock-rag/automation.tf:12-21` | S4-T4 |
| **F27** | Low | Retrieval is unfiltered — every query can reach every chunk; no metadata filter, no document-level control. **Accepted** under BR-D11. | design | — |
| **F28** | Low | `anthropic.claude-3-haiku-20240307-v1:0` is a 2024 model id, and the invoke path is not IaC-managed — it runs on ambient human SSO credentials, so there is no least-privilege statement governing generation. | `test_rag.py:21` | S4-T5 |

### 3.5 Python and supply chain

| ID | Sev | Finding | Where | Sprint |
| --- | --- | --- | --- | --- |
| **F29** | Medium | `requirements.txt` uses `~=` ranges with no hashes and no lockfile; there is no `pip-audit` and no SBOM. The file also carries a **UTF-8 BOM**, which makes its first requirement parse as `﻿boto3` on strict readers. | `environments/ai-lab/requirements.txt:1` | S5-T1 |
| **F30** | Medium | No `pyproject.toml`, no ruff or bandit configuration, **no tests at all**. CI's `ruff check .` therefore runs default rules from a directory-scoped working dir — enforcing neither the conventions' `E,F,I,B,S` rule set nor its line length, while appearing to be a lint gate. | `environments/ai-lab/` | S5-T2, S5-T3 |
| **F31** | Low | Both scripts catch bare `Exception` and print the exception text to stdout. In CI that reaches a **public** workflow log and can render the collection endpoint and caller identity (BR-D4). | `create_index.py:86-87`, `test_rag.py:60-61` | S5-T4 |
| **F32** | Low | `test_rag.py` is an interactive script named like a test: it reads unbounded `input()` and prints raw model output. Once S5 adds pytest, default collection will try to import and run it. | `environments/ai-lab/test_rag.py` | S5-T4 |

### 3.6 Governance, nomenclature, taxonomy

| ID | Sev | Finding | Where | Sprint |
| --- | --- | --- | --- | --- |
| **F54** | Medium *(near-miss, 2026-08-05)* | **`.gitignore` covers `.env` but no `.env.*` variant.** `.env.local`, `.env.bak`, `.env.prod`, `.env.save` and every per-directory equivalent are all **committable** — verified with `git check-ignore`. Found the hard way: cleaning F52 created a `.env.bak-preinfisical` backup that was immediately committable and held the (by then revoked) Infisical secret. The backup was deleted, nothing was committed, and the credential was already dead — but the gap is real and the trigger is mundane, since making a `.env` backup before editing it is exactly what a careful person does. Fix: `.env` → `.env*` plus `!.env.example`, and let S1-T3's `secrets-scan` job be the backstop rather than the only line. | `.gitignore:10` | **S0-T5** (with the other baseline files) |
| **F52** | **High** *(found 2026-08-05)* | **A live Infisical machine-identity credential sits in plaintext on disk.** `environments/ai-lab/.env` holds `INFISICAL_CLIENT_ID`, a 64-hex-char `INFISICAL_CLIENT_SECRET`, and a workspace id. **Verified NOT disclosed**: the file is untracked, matched by `.gitignore:10`, and neither the path nor the secret value appears anywhere in `git log --all --full-history` — so it never reached the public repo. It is still a credential for a system this project is leaving (BR-D21), which makes it pure liability: **it must be REVOKED in Infisical, not merely deleted from disk.** Deleting the file removes the copy, not the credential. **✅ CLOSED 2026-08-05: the machine identity was revoked by the operator, and the three `INFISICAL_*` keys were stripped from `.env` (the other keys — bucket name, region, `AWS_PROFILE` — were preserved).** | `environments/ai-lab/.env` (untracked) | **done** |
| **F53** | Medium *(found 2026-08-05)* | **Dead Infisical scaffolding, and a README that actively instructs the reader to use it.** The provider block, the `infisical_secrets` data source, the Cloudflare provider it fed, and `var.infisical_workspace_id` are all present but **commented out** (PR #13 disabled rather than removed them). Meanwhile `README.md` still lists Infisical as the secrets manager, names it a prerequisite, and tells the reader to create a `.env` with `INFISICAL_CLIENT_ID` / `INFISICAL_CLIENT_SECRET` — i.e. the documentation instructs a newcomer to provision exactly the credential F52 says to revoke. Commented-out code that contradicts live docs is worse than either alone. | `environments/ai-lab/providers.tf:10-38`, `variables.tf:7-10`, `README.md:5,13,26,37,44-48` | S3-T8, S6-T1 |
| **F33** | Medium | Merge settings: **auto-delete head branches is OFF**, and the squash-title source is not pinned to *PR title*. With the default source, a **single-commit PR silently uses the commit subject** — bypassing the `pr-title` check entirely, which makes that gate decorative the moment it is added. | GitHub settings | S0-T2 |
| **F34** | Low | Label taxonomy diverges from the Global Conventions on two axes: `type/*` is prefixed where the conventions use bare `bug`/`feature`/`chore`/`docs`, and `scope/*` is used where the conventions use `area/*` — the conventions make area labels share the **commit-scope vocabulary** on purpose, so an issue and the commit that closes it filter on the same word. | GitHub labels | S0-T3 |
| **F35** | Low | All four issue templates hardcode a **title prefix** (`[Global]`, `[Env]`), which the conventions explicitly reject: the label already carries the type, and the prefix wastes the most scannable characters in the UI. | `.github/ISSUE_TEMPLATE/*.yml` | S0-T3 |
| **F36** | Low | Commit `7d1df64` is `style(bootstrap): …`. The conventions deliberately have **no `style` type** — the formatter owns formatting, so a style-only commit should not exist. Nothing checks PR titles, so the next one lands too. | git history | S0-T4 |
| **F37** | Low | No `CODEOWNERS`, no `SECURITY.md`, no pull-request template, no Dependabot config, no `.gitattributes` (a Windows workstation commits files a Linux runner executes; CRLF in a future `run:` script is a silent `bad interpreter`). | `.github/`, root | S0-T5 |
| **F38** | Low | Three issue templates describe an **ArgoCD/Flux/Kubernetes GitOps estate this repo does not have** — `drift_sync.yml` asks for "the ArgoCD app, Flux Kustomization, or Helm Release," and `bug_report.yml` offers Production/Staging environments that do not exist. They were copied from a platform-repo template set. | `.github/ISSUE_TEMPLATE/*.yml` | S0-T3 |

**Totals:** 4 Critical · 17 High · 19 Medium · 15 Low — **54 findings**. Two are now closed
(**F40**'s stopgap half, **F52**). The count barely moved; the *ordering* did. Three findings were downgraded
because they threatened data that does not exist (**F39**, **F23**, **F50**), one was created
because the correction exposed an unmet functional requirement (**F51**), and everything
touching the **shared AWS account** was untouched — that blast radius is not ephemeral. Two (F41, and the
account-wide half of F47) cannot be fixed in this repo; they are filed upstream (§ 9.4).

---

## 4. Locked decisions

| ID | Decision |
| --- | --- |
| **BR-D1** | **`bootstrap/` is never applied by CI.** It defines what CI may do; a pipeline that can rewrite its own trust policy has no boundary. It stays a human, admin-credentialed, local apply — but it is still reviewed, scanned, and planned in CI (S1-T3). |
| **BR-D2** | **No infra change reaches AWS without a visible plan and a human approval.** `tofu plan` on every PR touching a code path; apply only on merge to `main`, behind a protected `production` Environment. `-auto-approve` is permitted **only** after that approval, and only against a saved plan file. |
| **BR-D3** | **Least privilege is enforced structurally, not by review.** The deploy role's IAM verbs are constrained by an `iam:PermissionsBoundary` condition and a role-path scope, so an escalation attempt fails in IAM rather than in code review. |
| **BR-D4** | **Public-repo posture.** This repo is public. Restricted values — the AWS account id, role ARNs, bucket names, the AOSS collection endpoint, and full `tofu plan` output — must never reach a workflow log, a PR comment, or a build artifact. Plans are summarized to change counts + resource addresses. Retrieved chunks and model answers never leave S3/AOSS. |
| **BR-D5** | **The vector store is treated as holding the documents, not just their embeddings.** `AMAZON_BEDROCK_TEXT_CHUNK` is cleartext source text, so every control that would apply to the S3 corpus applies to the collection. |
| **BR-D6** | **Ingested documents are untrusted input.** Retrieval-augmented context is attacker-influenced by construction; a Guardrail is a required control, not a feature. |
| **BR-D7** | **Two roles, not one:** a read-only `plan` role assumed by PR jobs, and a mutating `apply` role assumed only by the `production` Environment job. A PR must never hold credentials that can change AWS. |
| **BR-D8** | **OIDC trust conditions are subject-scoped, never globbed.** `repo:<owner>/<repo>:*` is forbidden; subjects are enumerated (`:ref:refs/heads/main`, `:pull_request`, `:environment:production`). A new trigger or environment generally needs a **new role**, not a widened one — and where the verifier takes a list, **append**, never replace. |
| **BR-D9** | **Required checks are added to the ruleset in the same PR that creates the check**, never in a batch afterwards. See §6 — this is the ordering rule that keeps S0 from deadlocking the repo. |
| **BR-D10** | **A destructive data-plane operation is never reachable from `tofu apply`.** Index deletion, corpus deletion, and collection replacement require an explicit, separately-authorized action. **Re-scoped 2026-08-05 (BR-D20):** this is now a *forward-looking design rule, not an urgent fix*. With an empty corpus nothing is at risk today, so it no longer gates or blocks anything — but it is the rule that must already be in place on the day the first real document is ingested, which is why it stays locked rather than deferred. |
| **BR-D11** | **Single-tenant lab posture, recorded not assumed.** One corpus, one operator, unfiltered retrieval, no per-document ACL. This is the assumption that must be revisited before a second consumer or any non-public source document. |
| **BR-D12** | **The green gate is deterministic.** `tofu fmt`/`validate`, ruff, bandit, pytest, checkov, tflint — no LLM judges IaC. The critic agents are defense-in-depth *around* that gate, never a substitute for it. |
| **BR-D13** | **RESOLVED 2026-08-05 — the repo transfers to `glunk-works`.** Executed by the new **ST** sprint, which must run before S1 and S2 so both are designed against the final identity. Was: ~~open question, revisit at S6~~, then promoted to a blocking pre-S2 decision. This repo lives at `Seuss27/`, not `glunk-works/` — and `global-bootstrap` builds its trust subjects from `github_organization=glunk-works`, so the org role generated *for this project* cannot be assumed from here (**F44**). The owner name is not cosmetic; it is inside every OIDC subject. The `pr_base: main` deviation from the conventions' `develop` is separate, deliberate, and matches both sibling repos — that half stays a S6 confirmation. |
| **BR-D17** | **RESOLVED 2026-08-05 — `global-bootstrap` owns identity and state; this repo owns its workload and nothing else.** The ownership boundary had to be stated before S2 designed a single policy. Exactly one of them owns the GitHub OIDC provider, the CI roles, and the state backend. Today both repos declare overlapping claims on all three (**F40**, **F43**, **F44**) and the account-level truth is unverified. The sibling precedent is unambiguous — bounty-infra's `CLAUDE.md` records that `global-bootstrap` owns "**every GitHub OIDC role**," and that a new workflow trigger generally needs a *new* role from there rather than a widened one locally. Adopting that here is the default; departing from it needs a written reason. Adopted because the operator confirmed the transfer (BR-D13) and one shared account, which makes the sibling precedent both coherent and cheaper than maintaining a second identity plane. **Consequence: this repo's `bootstrap/` is retired, not hardened** — its OIDC provider, deploy role, state bucket and lock table all move or are deleted. S2 is re-scoped accordingly. |
| **BR-D18** | **The GitHub OIDC provider moves to `global-bootstrap`'s ownership.** *(Rationale strengthened by BR-D20: the `prevent_destroy` guard now correctly blocks `tofu destroy` of this repo's entire `bootstrap/` root, which directly conflicts with the project's spin-up/tear-down design. Moving the provider upstream is what makes this repo **freely destroyable** — it is now an enabler of ephemerality, not just a safety fix.)* One account holds one provider per URL; today this repo *creates* it and `global-bootstrap` *reads* it as a `data` source, which inverts the dependency — the org's foundation depends on a lab repo's state (F40). End state: `global-bootstrap` declares it as a `resource` and imports the existing one; this repo drops its declaration entirely. Until that lands, `prevent_destroy` on this repo's copy is the stopgap (ST-T1). |
| **BR-D19** | ~~State is reconciled by import, never by recreate.~~ **REVERSED 2026-08-05 (BR-D20): state is reconciled by TEARDOWN AND REBUILD.** The original rule protected embeddings and source documents. There are none — the corpus is empty and the collection holds nothing. Writing `import` blocks for every drifted resource would be slower, riskier, and would freeze the current (bad) resource names into the configuration. Delete the orphaned resources, fix the IaC, and apply clean. The one exception is anything **shared with the organization** — the OIDC provider above all — which is never in scope for a teardown (BR-D18). |
| **BR-D20** | **Ephemerality is a design requirement, and the acceptance test.** This project exists to be stood up and torn down; nothing in the workload is precious and the corpus is empty. Two consequences that run in opposite directions and must both be honoured. **(1)** Breaking changes to the workload are free — prefer rebuilding correctly over migrating carefully, and never let a data-preservation caution shape a decision when there is no data. **(2)** A clean **`destroy` → `apply` → verify** cycle is therefore a *functional requirement*, not a convenience — and it is the acceptance test every infrastructure sprint must ultimately pass. Today the project fails it (**F51**). Precious-ness returns the day a real corpus is ingested; BR-D10 is what will already be in place when it does. |
| **BR-D21** | **Secrets come from AWS, not Infisical.** Aligning with the move already made under `603identity`. The concrete rule, in three tiers, because most of what this repo handles is *restricted* rather than *secret* and conflating them is how a secret store fills with non-secrets: **(1) Secrets** — anything whose disclosure is itself the harm: **AWS SSM Parameter Store `SecureString`**, `/bedrock-serverless-rag/<env>/<name>`, read at runtime via `data.aws_ssm_parameter`. Parameter Store rather than Secrets Manager **by default**: the standard tier is free where Secrets Manager bills per secret per month, and this is a cost-sensitive ephemeral lab (BR-D20). Secrets Manager only where native rotation or cross-account sharing is genuinely required — a decision to record, not a default. **(2) Restricted-but-not-secret** — account id, role ARNs, bucket names, the collection endpoint: GitHub Actions **variables** and tofu variables, never a secret store, and never a workflow log (BR-D4). **(3) Neither** — plain committed configuration. **This repo currently holds no secrets at all** (`gh secret list` is empty; the only variables are `AWS_OIDC_ROLE_ARN` and `DATA_SOURCE_BUCKET_NAME`), so there is nothing to migrate — this decision sets the pattern *before* the first secret exists, which is the cheapest moment to set it. **Confirmed 2026-08-05 as an ORG-LEVEL direction: this repo is the PILOT, and `bounty-infra` / `loop-orchestrator` follow as time permits.** That promotes S3-T8's deliverable from "clean up one repo" to "produce a pattern another repo can copy" — see § 9.5, including the reason a no-secrets pilot is a *weak* pilot and what S3-T8 does about it. |
| **BR-D14** | **No `architect-review` CI gate yet.** A fresh-session review gate is worth nothing while the deterministic checks beside it do not block a merge (F17). `review.ci_gate` stays `null`; the critic pass is `/critic-gate`, run locally before the PR. Reconsider once S0–S2 have landed. |
| **BR-D15** | **The devcontainer is the reproducible local green gate.** Every tool in it is version-pinned and SHA256-verified, and its pins are kept **equal** to the corresponding CI job pins — a divergence between local and CI results is a defect in this repo, not a local quirk. Recorded by SD; the Python layer is added by S5-T5. |
| **BR-D16** | *(reserved — allocated by S3-T1)* If Amazon Bedrock cannot reach a VPC-restricted OpenSearch Serverless collection, S3-T1 records the accepted public-reach risk here, with a dated documentation citation and the compensating controls that carry it. If Bedrock can, this id is released and the VPC-endpoint design is recorded instead. |

---

## 5. Sprint sequence

| Sprint | Title | Closes | Status |
| --- | --- | --- | --- |
| **S0** | Governance and repository baseline | F17, F33–F38 | **planned** |
| **SD** | Development container *(parallel)* | — (capability; records BR-D15) | planned |
| **ST** | **Organization transfer** — `Seuss27/` → `glunk-works/` | F44, F45, and the ST-T1 half of F40 | planned |
| **S1** | Pipeline hardening | F13–F16, F18–F21 | planned |
| **S2** | Identity, state reconciliation, and `bootstrap/` retirement | F1–F5, F39, F40, F42, F43, F47 (local half) | planned |
| **S3** | Data-plane and IaC posture | F6–F12 | planned |
| **S4** | RAG security | F22–F26, F28 | planned |
| **S5** | Python quality and supply chain | F29–F32 | planned |
| **S6** | Documentation and operational readiness | #8, BR-D13 | planned |

**SD is letter-prefixed, not numbered**, because it runs in **parallel** rather than in
sequence — the same convention the sibling repo uses for its parallel tracks (`SC`, `SE`,
`SG`). Renumbering S1–S6 to insert it would invalidate every cross-reference already written
into these plans.

Plans live at `sprints/S<N>_<slug>/sprint_plan.md`. Each carries a **Critical review**
section recording the security, logic, and execution objections raised against it during
planning and how they were resolved — that review is part of the plan, not a separate
artifact.

### Why this order

The ordering is not by severity, and that is deliberate.

- **S0 before everything** because F17 is the multiplier: until a ruleset exists, every
  control the later sprints add is advisory. Fixing F1 (Critical) while `main` accepts a
  direct push means the fix can be reverted by anyone with push access, unreviewed.
- **ST between S0 and S1**, and this is the sequencing decision the 2026-08-05 answers
  forced. The owner name is inside **every** OIDC subject, and repository *variables* do not
  survive a transfer — so doing S1 (which sets `AWS_PLAN_ROLE_ARN`, creates the `production`
  Environment, and adds an `environment:production` subject) *before* the transfer means
  doing all of it twice. ST also has a hard internal ordering of its own: the upstream policy
  fix must land **before** the transfer, because the transfer is what makes the dormant
  over-privileged org role reachable (**F45**).
- **S1 before S2** because S2 splits one role into two, and a two-role model is only
  meaningful once the pipeline actually has separate plan and apply jobs to assume them.
  Doing S2 first would create a role nothing uses.
- **S2 before S3** because S3's changes are applied *by* the deploy role. Hardening the data
  plane while the role that manages it can escalate to admin protects the wrong thing first.
- **S3 before S4** because Guardrails and logging are new resources the deploy role must be
  allowed to create — and S2/S3 set the boundary that grant has to fit inside.
- **S5 and S6 last** because nothing else depends on them. S6 in particular *must* be last:
  a README rewritten before the architecture stops changing is a README that needs rewriting
  again, which is how #8 came to exist.
- **SD as early as possible, in parallel.** It touches no `.tf`, no workflow, and no AWS
  resource, so it has no dependency beyond S0 (which makes it land through a PR). Every
  sprint after it gets a green gate that runs in a pinned environment instead of on whatever
  the workstation happens to have. Its one deliberate omission — the Python layer — is
  completed by S5-T5.

### Known ordering hazards

1. **S4-T4 and S5 both touch `create_index.py`.** S4-T4 removes the destructive delete and
   the in-module `local-exec`; S5 adds the toolchain that lints and tests it. Run S4-T4
   **first** — otherwise S5 writes tests pinning behavior S4 is about to delete, and S4 then
   lands looking like a regression against a green suite.
2. **SD pins tool versions that CI also pins.** A pin that is not *equal* to CI's pin is
   worse than no pin: it produces confident local results that disagree with the gate. Any
   sprint that changes a CI tool version changes SD's `ARG` in the same PR.
3. **Every sprint that adds a gating check must append it to three places in one PR** — the
   live ruleset, `.ai/project.yml`, and `ruleset-drift.yml` (BR-D9, § 6).
4. **The upstream policy fix precedes the transfer** (F45). Transferring first opens an
   escalation path into the shared account with no IaC diff to review.
5. **State reconciliation (F39) precedes S3 and S4.** Both sprints use "read the `tofu plan`
   output" as an acceptance criterion — for replacements, for `No changes.`, for tag
   updates. Against a split-brain state that reads a plan of a system that is not there.
   S2 reconciles by import (BR-D19); until then, treat every plan as unverified.

---

## 6. The required-check ordering rule (BR-D9)

The obvious way to do governance-first is to install a ruleset in S0 that requires the full
target check list. **That deadlocks the repository**: a required check whose workflow does
not exist never reports, so every PR sits permanently pending — including the PR that would
add the missing workflow. It cannot be fixed from inside a PR.

So the ruleset grows monotonically, one PR at a time:

1. **S0 requires only checks that exist when S0's own PR merges** — that is `pr-title`, plus
   the two `deploy-ai-lab.yml` jobs *after* S1-T2 removes their `name:` overrides. Since
   S0 lands before S1, S0 requires **`pr-title` only**.
2. **Every later sprint that adds a gating check appends it to the ruleset in the same PR**
   that adds the workflow job, and updates `ruleset.required_checks` in `.ai/project.yml` in
   that same PR. Three artifacts, one change: workflow, live ruleset, schema.
3. **`ruleset-drift.yml` is never itself a required check.** A required check is required
   only because the ruleset says so — so requiring the drift detector would un-require it at
   the exact moment the ruleset it watches is deleted, silently, on the one failure it
   exists to catch.

**Target ruleset**, reached at the end of S5 — recorded here as the destination, and
authoritative **only** in `.ai/project.yml`, which always reflects what is live:

`pr-title`, `tofu-fmt`, `tofu-validate`, `tofu-plan`, `checkov`, `tflint`, `secrets-scan`,
`dependency-audit`, `sbom`, `zizmor`, `python-lint`, `python-test`

Rule types throughout: `deletion`, `non_fast_forward`, `pull_request`,
`required_status_checks`.

---

## 7. Nomenclature and taxonomy

### Commits and PR titles

Conventional Commits, per the plugin's Global Conventions:
`type(scope): imperative subject, lower-case, no trailing period`.

Types: `feat`, `fix`, `docs`, `test`, `refactor`, `perf`, `chore`, `ci`, `revert`. There is
deliberately **no `style`** — the formatter owns formatting (F36).

**Scopes are this repo's module boundaries, and the same words are the `area/*` labels:**

`bootstrap` · `module` · `env` · `ci` · `rag` · `docs` · `ai`

Trailers link a commit to the project's id space: `Sprint: S2`, `Finding: F1`, `Closes: #6`.

The PR title is the enforced surface — merges are squashes, so the PR title becomes the
commit subject on `main`. It is the only message worth a CI check (`pr-title`), and it is
only real once the squash-title source is pinned to *PR title* (F33).

### Branches

`sprint/S<N>-slug` for sprint work; `feat|fix|chore|docs|ci/slug` for one-offs. The prefix
matches the commit `type` the branch lands as.

### Labels — three orthogonal axes, plus two local ones

| Axis | Values | Answers |
| --- | --- | --- |
| **type** (bare) | `bug`, `feature`, `chore`, `docs`, `security` | what kind of work |
| **`area/*`** | `area/bootstrap`, `area/module`, `area/env`, `area/ci`, `area/rag`, `area/docs` | where — *same vocabulary as commit scopes* |
| **`status/*`** | `status/triage`, `status/blocked`, `status/in-progress`, `status/needs-human` | where it is |
| **`priority/*`** *(local)* | `priority/critical`, `priority/high`, `priority/medium` | retained; not in the conventions, documented as a local extension |
| **`env/*`** *(local)* | `env/ai-lab`, `env/global` | retained and **corrected** — the current `env/prod`/`env/staging` label the environments that do not exist |

Machine-emitted labels stay namespaced under the emitting system
(`bedrock-serverless-rag/needs-human`), so "did a human or a robot put this here?" is
answerable at a glance. An automated writer never applies an un-namespaced label.

**Issue titles carry no prefix** (F35) — plain imperative statements, same grammar as a
commit subject. The label already says the type.

---

## 9. Cross-repo coupling — `glunk-works/global-bootstrap`

Discovered 2026-08-05, after the initial evaluation. It changes S2's scope materially and
promotes BR-D13, so it is recorded here in full rather than folded into a finding row.

### 9.1 What global-bootstrap actually owns

`glunk-works/global-bootstrap` is the organization's centralized IaC foundation, applied
**locally by a human** (never by CI — the same posture as BR-D1). It owns:

- the org state bucket `glunk-works-tofu-state-00042` and lock table `global-tofu-lock`,
  with **real per-project isolation**: each project's role gets `s3:ListBucket` conditioned
  on `s3:prefix = <project>/*` and object access scoped to `<project>/*` only;
- the **findings** bucket + KMS key (bounty-infra's);
- **one CI role per project**, generated from `var.projects` — and that map already contains
  `"bedrock-serverless-rag" = { repo_name = "bedrock-serverless-rag" }`;
- an opt-in **read-only PR-time plan role** per project (`plan_roles.tf`, `plan_role = true`);
- the `bounty-scanner-s3-writer` chain-only role.

It **consumes** the GitHub OIDC provider — `data.aws_iam_openid_connect_provider.github` —
it does not create one.

### 9.2 The four couplings that matter here

1. **The OIDC provider (F40).** This repo *creates* what global-bootstrap *reads*. One
   provider per URL per account. Same account ⇒ this repo's state owns the org's federation
   endpoint, with no `prevent_destroy`. Different accounts ⇒ the org's scaffolding for this
   project is inert. **Answered 2026-08-05: the SAME account.** Stopgap `prevent_destroy` in
   ST-T1; ownership moves upstream in S2-T3 (BR-D18).
2. **The role and its policy (F42, F44).** `github-actions-bedrock-serverless-rag` exists
   upstream but trusts `repo:glunk-works/bedrock-serverless-rag:ref:refs/heads/main`, which
   this repo cannot present. Its attached policy (`lambda:*`, `apigateway:*`,
   `bedrock:InvokeModel`) describes a serverless API, not this workload — so even if the
   subject matched, apply would fail. Meanwhile this repo maintains its *own*
   `github-actions-deploy-role`. **Confirmed 2026-08-05: `vars.AWS_OIDC_ROLE_ARN` names that
   local role**, consistent with run `26788807269` (OIDC auth and `tofu plan` both succeeded,
   so the inert org role cannot be the one in use). `AWS_PLAN_ROLE_ARN` is **not set**.
   *(An earlier draft of this line said the value could not be read because the token lacked
   the variables scope. That was wrong — the `gh` CLI was authenticated as a second account
   without admin on this repo. Every other `gh`-derived fact in this document has since been
   re-verified as `Seuss27`, and none changed.)*
3. **The state backend (F43).** Two backends, two lock tables, and only the upstream one has
   prefix isolation.
4. **The mechanisms S1 and S2 need already exist upstream — as *upstream* changes.**
   `extra_oidc_subjects` (S1-T5's `environment:production` subject) and `plan_role = true`
   (S2-T2's read-only plan role) are both keys in global-bootstrap's `var.projects` — **ST-T2
   sets both**. Notably,
   global-bootstrap's own comments already record the two lessons S2 was going to
   rediscover: that an Environment subject **replaces** the branch subject rather than adding
   to it, and that allowlisting `:pull_request` on an *apply* role means opening a PR grants
   apply-capable credentials.

### 9.3 What this changed — resolved 2026-08-05

The operator answered the two open questions: **one shared AWS account**, and **the repo
transfers to `glunk-works`**. That resolves BR-D13 and BR-D17 and re-shapes three sprints:

- **A new sprint, ST**, sits between S0 and S1 and performs the transfer — including the
  upstream policy fix that must precede it (**F45**) and the `prevent_destroy` stopgap on the
  shared OIDC provider (**F40**).
- **S2 is re-scoped from "harden `bootstrap/`" to "retire `bootstrap/`."** Under BR-D17,
  `global-bootstrap` owns the OIDC provider, the CI roles, and the state backend; this repo
  owns its workload and nothing else. The permissions-boundary construction originally
  drafted for S2-T1 does not disappear — it moves upstream, as the proposed fix for F41.
- **S2 also absorbs state reconciliation (F39).** The evidence arrived with the answers: run
  `26788807269` shows `EntityAlreadyExists` on the KB role and a stalled S3 bucket create, so
  the resources exist in AWS and are absent from CI's state. Reconcile by import (BR-D19).
- **S3-T3 is settled, not conditional** — the org backend wins; this repo's backend is
  migrated and retired.
- **S6-T4 shrinks** to confirming the `pr_base` deviation; the transfer itself is ST's.

### 9.4 Filed upstream, not fixable here

**F41** — the `iam:CreateRole` / `PutRolePolicy` / `AttachRolePolicy` / `PassRole` on
`Resource = "*"` in all four of global-bootstrap's project workload policies. This is F1 at
organization scope, affecting four pipelines **in the same account that holds bounty-infra's
findings archive** (F47). Raise it as an issue on `glunk-works/global-bootstrap` with the
permissions-boundary construction as the proposed fix, so the two repos converge on one
pattern instead of two.

Note the asymmetry that makes this concrete: `global-bootstrap`'s `plan_roles.tf` already
carries an explicit `DenyBountyFindingsDataAccess` statement on the **plan** roles, with a
comment explaining that it makes reading third-party vulnerability data structurally
impossible "even if a later edit widens the Allow above." The **apply** roles — the ones with
`iam:*` on `*` — have no such Deny. The control exists; it is on the weaker of the two role
classes.

**F45's upstream half** — the `bedrock-serverless-rag` entry in `var.projects` and its
`bedrock_rag_policy`. Both must be corrected **before** the transfer, since the transfer is
what makes them reachable. This is ST-T2 and it is a pull request against another repo, on
this sprint's critical path.

### 9.5 This repo is the secrets-migration pilot (BR-D21)

Decided 2026-08-05. `bounty-infra` and `loop-orchestrator` still resolve account-specific
values through **Infisical**; they move to AWS-native secrets as time permits. This repo goes
first.

**Why here:** it is the only glunk-works repo with **no secrets to migrate**, so the pattern
can be established with zero migration risk and no coordination.

**Which is also the pilot's weakness, and S3-T8 has to answer it.** A pilot that migrates
nothing exercises none of the hard parts — creating a parameter, granting a CI role
`ssm:GetParameter` + `kms:Decrypt`, reading it at runtime through `data.aws_ssm_parameter`,
and keeping the value out of `tofu plan` output (an SSM value read into state **is in state**,
and state renders in plan — BR-D4). A pattern that has never been executed is a proposal.
So S3-T8 must **prove the path end-to-end with a disposable throwaway parameter, created and
destroyed inside the task** — exercising the mechanism without leaving standing scaffolding,
which is exactly the empty-secret-store anti-pattern that same task exists to remove. It is
also the most BR-D20-native way to test anything here: create, verify, destroy.

**The handover insight, which is worth more than the mechanism.** Under BR-D21's three tiers,
**much of what the other repos keep in Infisical is not secret at all.** `bounty-infra` stores
`TF_STATE_BUCKET` and `AWS_OIDC_ROLE_ARN` there — both *restricted* (BR-D4) but neither a
credential, so under this pattern they become GitHub Actions **variables**, not SSM
parameters. Its genuinely secret values are far fewer (`VULTR_API_KEY`, `GITLEAKS_LICENSE`).
So the migration those repos face is **not a lift-and-shift into a new store — it is a
re-tiering**, and most items should leave the secret store entirely rather than move. Saying
that up front is the difference between a two-hour job and a two-day one, and it is the single
most useful thing this pilot can hand over.

**Where the pattern should live:** `glunk-works/global-bootstrap`, which already owns the
account-level primitives an SSM pattern needs — it would own the parameter-path convention and
the per-project read grants — with a pointer from the `way-of-working` plugin's Global
Conventions. **Not** in this repo: a pilot that documents its pattern only in its own README
has not produced a pattern.

## 10. Status log

| Date | Event |
| --- | --- |
| 2026-08-05 | Repo evaluated against `main` @ `429ca10`. `way-of-working` plugin adopted (`.ai/`, `CLAUDE.md`, this roadmap). 39 findings recorded, BR-D1..BR-D16 allocated, S0–S6 + SD planned. Nothing implemented yet. |
| 2026-08-05 | **`glunk-works/global-bootstrap` reviewed** (§ 9). Five cross-repo findings added (**F40–F44**, total now 44), **BR-D17** locked, **BR-D13 promoted** out of S6 to a blocking decision before S2, and **S2-T0** added as the ownership gate every other S2 task branches on. F41 filed as an upstream-only finding. |
| 2026-08-05 | **Operator answered the two open questions: one shared AWS account, and the repo transfers to `glunk-works`.** F40 confirmed; F39 confirmed and raised to Critical after reading run `26788807269` (`EntityAlreadyExists` + six `AuthorizationException(403)` — no CI apply has ever succeeded); F5 confirmed live and raised to High. Three new findings — **F45** (the transfer activates a dormant over-privileged org role), **F46** (the retry loop masks an authz failure the last commit made 12 minutes long), **F47** (shared account puts bounty-infra's findings archive in F1's blast radius). Total **47**. **BR-D13** and **BR-D17** resolved; **BR-D18** and **BR-D19** locked. New sprint **ST** inserted between S0 and S1; **S2 re-scoped from hardening `bootstrap/` to retiring it**. |
| 2026-08-05 | **F40 stopgap applied**: `prevent_destroy` added to the shared OIDC provider (branch `fix/protect-shared-oidc-provider`, staged — GPG pinentry timed out, awaiting the operator's signed commit). Doing so surfaced **F48**: `bootstrap/` has **no `backend` block**, so the state describing the org-shared provider, the CI role, and the state backend is a local gitignored file on one workstation — which also means the new `prevent_destroy` guard only holds while that file exists. Total **48**. |
| 2026-08-05 | **All `gh`-derived facts re-verified under the correct account** (`Seuss27`; earlier reads had run as `JaredGroves-603`). F17 confirmed twice over — `rulesets` is `[]` *and* `branches/main/protection` returns 404. F33 confirmed exactly as predicted: `squash_merge_commit_title` is `COMMIT_OR_PR_TITLE`, so a single-commit PR would bypass the `pr-title` gate; `delete_branch_on_merge` is `false`; rebase merges are on. **No finding changed.** The open question on `vars.AWS_OIDC_ROLE_ARN` is closed (§ 9.2). |
| 2026-08-05 | Verifying the F40 guard surfaced **F49**: `bootstrap/providers.tf` sets no `profile`, so following the README leaves `tofu` unable to authenticate. Recorded against S6-T2 (break-glass runbook) — the one procedure where a broken credential chain costs the most. |
| 2026-08-05 | **F40 guard VERIFIED** against live state — `tofu plan -destroy` on the OIDC provider fails with `Instance cannot be destroyed ... lifecycle.prevent_destroy set` (PR #17). The same plan confirmed **F1 and F2 live, verbatim** (the deployed inline policy really does hold `iam:CreateRole`/`PutRolePolicy`/`AttachRolePolicy` on `Resource = "*"`; the deployed trust really is `StringLike repo:Seuss27/bedrock-serverless-rag:*`) — both had previously been read from committed HCL only. It also surfaced **F50**: `bootstrap/` has live drift the next apply would silently revoke. Total **50**. |
| 2026-08-05 | **Scope correction (BR-D20): the project is ephemeral by design and the corpus is empty.** Re-ranked rather than shortened: **F39**, **F23** and **F50** downgraded (they protected data that does not exist), **BR-D19 reversed** (reconcile by teardown-and-rebuild, not import), `force_destroy` and the frozen-names rule reversed, and **F51** created — the project cannot currently complete the create/destroy/create cycle it exists to perform. Everything touching the **shared AWS account** was left untouched. |
| 2026-08-05 | **Secrets move to AWS-native (BR-D21)**, aligning with `603identity`. Found **F52** — a live Infisical machine-identity secret in plaintext at `environments/ai-lab/.env`; verified never committed and correctly gitignored, but it needs **revoking**, not deleting. Found **F53** — dead commented-out Infisical scaffolding plus a README that still instructs the reader to provision that same credential. Cross-repo inconsistency with `bounty-infra`/`loop-orchestrator` flagged upstream in § 9.4. |
| 2026-08-05 | **BR-D21 confirmed as an org-level direction: this repo is the secrets-migration PILOT**, with `bounty-infra` and `loop-orchestrator` to follow as time permits. S3-T8's deliverable is promoted from a local cleanup to a transferable pattern (§ 9.5) — including proving the SSM path end-to-end with a disposable parameter, since a repo with no secrets otherwise exercises none of the mechanism it is piloting. |
| 2026-08-05 | **PR #17 merged (`1ad5aa7`)** — the `prevent_destroy` guard on the org-shared OIDC provider is live on `main` and verified against real state. **F52 closed**: the Infisical machine identity was revoked and its keys stripped from `.env`. Cleaning it surfaced **F54** — `.gitignore` covers `.env` but not `.env.*`, so a routine backup of a secrets file is committable; found by making exactly that backup. **F49 sharpened**: the `AWS_PROFILE` workaround lives in `Invoke-Tofu.ps1`, which is gitignored — local development depends on an unshippable file. Total **54**. |
