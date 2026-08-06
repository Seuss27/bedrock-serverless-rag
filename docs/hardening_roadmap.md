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
   via F1 + F47. **The asset is two resources, not one: the findings *bucket* and the KMS
   *key* that encrypts it.** They must never be protected asymmetrically — the bucket carries
   confidentiality, but the *durability* of every object rests on the key, which is a
   different resource in a different service, so an `s3:`-scoped control does not constrain a
   `kms:` action against it (**F58**). Any Deny, any scan, any review criterion that names one
   names both.
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

**The multiplier rule (BR-D24).** Several findings are not themselves vulnerabilities — they
are conditions that change what another finding is worth. **A multiplier is rated at the
severity of the worst outcome it enables.** This is stated once, here, because the inventory
previously applied it two ways: **F17** was Critical *because* it is "the multiplier on F13
and F1", while **F47** was High on the opposite reasoning that a multiplier ranks one below
what it multiplies. Both cannot be the rule. The first reading wins, which makes F47 Critical.

**Severity is not schedule.** The ordering in § 5 is deliberately not by severity (see the
rationale there), and **F51** is the sharpest case: it is a *functional* defect — the project
cannot perform the create/destroy/verify cycle it exists to perform — which this scale has no
band for, since the scale measures risk. It is rated **High** and scheduled **first among
non-blast-radius work**, in the `MW` sprint. A `Blocker` severity was considered and rejected
(BR-D24): bolting a delivery band onto a risk scale muddles both, and the scheduling harm it
was meant to signal is already fixed by `MW` existing.

### 3.1 Identity and privilege

| ID | Sev | Finding | Where | Sprint |
| --- | --- | --- | --- | --- |
| **F1** | **Critical** | *(Closed in S2-T2 by **deleting** the role, not by hardening it — BR-D17. The boundary construction originally drafted here moved upstream to ST-T2 and the F41 issue.)* `state_access_policy` grants `iam:CreateRole`, `iam:PutRolePolicy`, `iam:AttachRolePolicy`, `iam:DeleteRolePolicy`, `iam:DeleteRole` on `Resource = "*"`. This is **privilege escalation to account administrator**: the CI role can mint a role with `AdministratorAccess` and attach a trust policy naming itself. The `Resource = "*"` even carries an in-file comment conceding it. | `bootstrap/state-backend.tf:82-111` | S2-T1 |
| **F2** | High | OIDC trust condition is `StringLike sub = "repo:${var.github_repo_path}:*"`. The `*` admits every branch, every `pull_request`, and every environment — and in IAM `StringLike`, `*` matches `:` too, so it also admits claim shapes that do not exist yet. **Closed by adoption — but NOT on the operator this previously claimed.** *(Corrected 2026-08-05, advisory `[M2]` § 6.)* This entry used to read "the upstream role's trust is already `StringEquals` over an enumerated subject list." **It is not.** Live `global-bootstrap/main.tf` uses **`StringLike`** on `…:sub` for the **apply** role; `StringEquals` appears only on the **plan** role, where a comment says so explicitly. The values are wildcard-free today so it is functionally equivalent — but F2's entire substance is *"in IAM `StringLike`, `*` matches `:` too"*, so closing it on an operator the upstream code does not use means any future `extra_oidc_subjects` entry containing a `*` globs silently. **S2-T2 gains an acceptance criterion — "the adopted role's trust condition uses `StringEquals`" — and the `StringLike` → `StringEquals` change is filed with the F41 upstream issue (§ 9.4).** ST-T3 widens this glob temporarily during the transfer, then S2-T2 deletes the role entirely. | `bootstrap/oidc-setup.tf:37` | S2-T2 |
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
| **F45** | **Critical** *(raised from High 2026-08-05, BR-D24)* | **The transfer silently activates a dormant, over-privileged, wrong-workload role.** **Why Critical:** every other Critical here has a diff a human could catch. This one's trigger is an org owner clicking *Transfer* — **no IaC change, no PR, no review surface anywhere** — and it is the one Critical this plan intends to *create*, on a sprint scheduled second. Today `github-actions-bedrock-serverless-rag` cannot be assumed from `Seuss27/…` (F44). The moment the repo becomes `glunk-works/bedrock-serverless-rag`, its trust subject `repo:glunk-works/bedrock-serverless-rag:ref:refs/heads/main` **matches** — and that role carries `lambda:*`, `apigateway:*` (F42) **and** `iam:CreateRole`/`PutRolePolicy`/`AttachRolePolicy`/`PassRole` on `Resource = "*"` (F41). So a repository-settings change, with no IaC diff anywhere, creates a **new escalation path into the shared account**. The upstream fix must land **before** the transfer, not after. | `global-bootstrap/project_policies.tf` + the transfer | **ST-T2, blocking ST-T3** |
| **F46** | Medium | **The retry loop reports an authorization failure as a propagation delay, and the most recent commit made it worse.** `create_index.py` retries any `Exception` six times; run `26788807269` shows six consecutive `AuthorizationException(403, '')` — a condition that can never resolve by waiting, because it is F5, not IAM eventual consistency. Commit `0aa56dc` raised the delay to 45 s, so CI now spends **~12 minutes** failing at it. The most recent work on this repo was tuning the wrong variable. | `environments/ai-lab/create_index.py:71-93` | S4-T4 |
| **F48** | **High** *(found 2026-08-05 while applying the F40 stopgap; severity SURVIVES BR-D20 — see below)* | **`bootstrap/`'s OpenTofu state is a local, gitignored file on one workstation.** `bootstrap/` declares **no `backend` block** — despite `state-backend.tf` creating a state bucket *for the other root*. So `bootstrap/terraform.tfstate` (plus `.backup` and a `terraform.tfvars`) lives only in the working tree, unversioned and unbacked-up, and it is the state describing the **org-shared OIDC provider**, the CI deploy role, and the state backend itself. Three consequences: **(a)** losing that laptop makes the highest-consequence root in the org unmanaged; **(b)** `prevent_destroy` (F40's stopgap) **only works while that file exists** — no state, no tracked resource, no guard; **(c)** re-applying from an empty state would try to *create* the provider and fail `EntityAlreadyExists`, reproducing F39's split brain in the one root where it hurts most. Superseded rather than fixed by BR-D17/BR-D18: `bootstrap/` is retired and its resources move to `global-bootstrap`, whose state *is* remote and locked. Until then, **back the file up out-of-band.** **BR-D20 does not downgrade this**: the state file is disposable in respect of *this repo's* resources, but it is the only record of the **org-shared OIDC provider**, whose loss is an organization-wide outage. That single resource is what makes an otherwise-disposable file matter — and moving it upstream (BR-D18) is what makes the rest of `bootstrap/` freely destroyable, as the design intends. **⚠ The exposure window is ST, not S2** *(added 2026-08-05)*: F48's remedy is assigned to S2-T3/S2-T4, but **ST runs first and mandates three human applies against exactly this file** — ST-T0's drift reconciliation, and ST-T3's trust-policy widen and narrow — on a repository mid-transfer between owners. An interrupted apply drops the OIDC provider from state, `prevent_destroy` evaporates with it (it is a plan-time guard over a state entry, not a property of the AWS resource), and recovery per (c) is a hand-written state file, executed against a repo whose OIDC trust subjects are themselves in flux. **F48's own mitigation is therefore promoted to a blocking ST-T0 acceptance criterion** — back the file up out-of-band before the sprint's first apply, and again immediately before ST-T3's narrow. | `bootstrap/` (no `backend` block) | **ST-T0** (backup), S2-T3, S2-T4 |
| **F47** | **Critical** *(raised from High 2026-08-05 by the multiplier rule, BR-D24)* | **The shared account changes F1's and F41's blast radius from "a personal lab" to "the organization."** **Why Critical:** it is what turns lab compromise into compromise of bounty-infra's KMS-encrypted third-party findings archive — a worse outcome than F1 alone, not a rank below it. Rating it High was the same under-reading `CLAUDE.md`'s "hard edge" paragraph exists to prevent. One account holds this repo's state, the org state bucket, **and bounty-infra's KMS-encrypted findings archive** — third-party vulnerability data, the most restricted asset any glunk-works repo holds (bounty-infra's BI-D4). Five CI roles in that account each hold `iam:CreateRole`/`PutRolePolicy`/`AttachRolePolicy` on `Resource = "*"` — this repo's `github-actions-deploy-role` (F1) plus all four org project roles (F41). Compromise of **any one** of the five yields account administrator, and therefore the findings archive. `global-bootstrap`'s explicit `DenyBountyFindingsDataAccess` on the *plan* roles shows the risk was seen; the *apply* roles have no equivalent. | account-wide | S2, upstream |

### 3.1d Found by the cold-context plan review, 2026-08-05

Four findings surfaced by the adversarial review of PR #18 (the plan itself), all of them
properties of **live** code — this repo's module, or `glunk-works/global-bootstrap` — rather
than of the plan. Defects that exist only *in the plan* were fixed by amending the sprint
plans and are not findings.

> **Disclosure note.** These entries state *what is wrong and what closes it*. The
> step-by-step exploit chains stay in this repo's **private draft security advisories**
> (`gh api repos/<owner>/<repo>/security-advisories`), which is where the review filed them
> and why. This file is public (**TB5**); a finding is a fix instruction here and a recipe
> there. Do not move advisory text into this file wholesale.

| ID | Sev | Finding | Where | Sprint |
| --- | --- | --- | --- | --- |
| **F55** | **High** | **The deploy identity is not provably sufficient for a from-scratch apply, and the teardown that needs it runs first.** `state_access_policy` grants `aoss:Create/DeleteSecurityPolicy`, `aoss:CreateCollection`, `bedrock:CreateKnowledgeBase`, `bedrock:CreateDataSource` — and nothing else in those families. The module declares at least four things it cannot then create or refresh: `aws_opensearchserverless_access_policy` (needs `aoss:*AccessPolicy`), the KB's `roleArn` (needs `iam:PassRole`), `aws_s3_bucket_server_side_encryption_configuration` (needs `s3:*EncryptionConfiguration` — `s3:PutBucket*` matches neither verb), and `aws_s3_bucket` refresh (needs `s3:GetBucketVersioning`/`GetBucketLocation`/`GetBucketTagging`). **These have never been exercised** because run `26788807269` died at `EntityAlreadyExists` *before AOSS or Bedrock were reached*, so they become visible exactly once, at the worst moment: after the teardown has deleted the working-but-orphaned system and before the replacement identity exists. **The verb list above is indicative and must be regenerated from a real dry run, not copied from here.** | `bootstrap/state-backend.tf:82-111` vs `modules/aws-bedrock-rag/` | **MW** |
| **F56** | **High** | **The upstream read-only plan role is unusable by this repo, in two independent ways.** *(a)* `plan_roles.tf` trusts **only** `repo:<org>/<repo>:pull_request` via `StringEquals`, with no `extra_oidc_subjects` mechanism — so any job triggered `on: push` to `main` can never assume it. *(b)* `plan_role = true` generates the role and its **state**-read policy, but the **workload** read policy upstream is `aws_iam_policy.bounty_infra_plan_policy` — hardcoded, not `for_each`ed — so this project's plan role would hold state-read and nothing else, and every PR plan would `403` on refresh. **The dangerous part is the unblock, not the breakage:** the natural fix for (a) is to point the plan job at the apply role, which is F13 restored in the same change that closes it. | `global-bootstrap/plan_roles.tf`, `project_policies.tf` | **ST-T2**, S1-T5 |
| **F57** | **High** | **The KB execution role receives neither `path` nor `permissions_boundary`, so the boundary ST-T2 installs denies its creation.** `aws_iam_role.bedrock_kb_role` declares `name = "personal-bedrock-kb-execution-role"` and nothing else. Once the upstream `iam:PermissionsBoundary` condition and `role/bedrock-rag/*` Resource scope are live, CI's `CreateRole` for it is denied twice over — wrong path, no boundary. **The failure lands at S2-T2's *verify* step, when the escalation-capable local role has not yet been deleted and the cheapest unblock is to drop the boundary condition upstream** — silently reverting the whole construction and reopening F41. The module change must land **before** the upstream condition, and the two live in different repositories. | `modules/aws-bedrock-rag/iam.tf:21-23` | **ST**, before ST-T2 |
| **F58** | Medium | **`DenyBountyFindingsDataAccess` is `s3:`-only, and is attached to one project's plan role rather than all of them.** Two gaps in the control that exists specifically to protect asset #1. *(a)* The Deny names `s3:*` on the findings bucket; it does not name `kms:`, so it does not constrain `kms:ScheduleKeyDeletion` or `kms:PutKeyPolicy` against the key that encrypts it — see § 2.2, the asset is two resources. *(b)* `bounty_infra_plan_policy` and its attachment are not `for_each`ed, so the plan role ST-T2 creates for this project would carry **no findings Deny at all**, despite § 9.4 describing the Deny as applying to "the plan roles" plural. | `global-bootstrap/project_policies.tf` | **ST-T2**, upstream |

### 3.2 Pipeline

| ID | Sev | Finding | Where | Sprint |
| --- | --- | --- | --- | --- |
| **F51** | **High** *(created by the 2026-08-05 scope correction)* | **The project does not do the thing it was designed to do.** Its stated purpose is to be stood up and torn down on demand (BR-D20) — yet **no `tofu apply` has ever completed successfully** (every push-to-`main` run is `failure` or `cancelled`), and a full `destroy` → `apply` → verify cycle has never been demonstrated. At least four defects sit on that path: the AOSS data-access policy grants a human SSO session rather than the CI role (**F5**), the index bootstrap then fails `403` and retries for ~12 minutes (**F46**), the state is orphaned so apply collides with `EntityAlreadyExists` (**F39**), and `prevent_destroy` on the shared OIDC provider now blocks `tofu destroy` of `bootstrap/` outright until ownership moves upstream (**BR-D18**). Each was recorded separately as a security or correctness defect; together they are a **functional** one. **A clean create/destroy/create cycle is the acceptance test for S2 (BR-D20)** and the cheapest possible route to closing F39, F5 and F46 at once. | whole-system | **S2** |
| **F17** | **Critical** | **No branch-protection ruleset exists.** `gh api repos/Seuss27/bedrock-serverless-rag/rulesets` returns `[]`. `main` accepts a direct push, no check is required, and every gate in `.github/workflows/` is therefore advisory. This is the multiplier on F13 and F1. | GitHub settings | S0-T1 |
| **F13** | **High** *(lowered from Critical 2026-08-05, BR-D24)* | `tofu apply -auto-approve` runs on every push to `main` with **no `environment:`, no approval, no plan artifact**. With F17 and F1, one push is unreviewed admin-capable execution. **Why lowered — double-counting, and nothing else.** The escalation it enables is F1's (Critical) and the absent protection is F17's (Critical); strip both and what remains is "an unreviewed apply reaches AWS on merge" — a BR-D2 violation, genuinely High, but not an independent Critical. **Two arguments were explicitly rejected as rationale:** that no push-to-`main` run has ever succeeded, and that the workflow is `paths:`-filtered. Both are artifacts *this plan deletes* — `MW` is precisely what makes auto-apply start working, and the `paths:` filter comes off in the change that makes a job required. Recorded as rationale they would be false the day `MW` lands. | `.github/workflows/deploy-ai-lab.yml:85-87` | S1-T5 |
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

**Totals:** 5 Critical · 18 High · 21 Medium · 14 Low — **58 findings**. *(Counted from the
tables, 2026-08-05, after the plan review. The previously stated `4 · 17 · 19 · 15` was wrong
twice over: it summed to 55 against a stated total of 54, and the pre-review truth was
`5 · 15 · 20 · 14`. **Recount from the tables rather than adjusting this line by hand.**)*

Two are closed (**F40**'s stopgap half, **F52**). **The five Criticals are F1, F17, F41, F45,
F47** — F45 and F47 raised and F13 lowered on 2026-08-05 under the multiplier rule (BR-D24,
stated at the head of this section). Four findings were added by the cold-context plan review
(**F55**–**F58**, § 3.1d). Three were downgraded by the BR-D20 scope correction because they
threatened data that does not exist (**F39**, **F23**, **F50**), and one was created because
that correction exposed an unmet functional requirement (**F51**). Everything touching the
**shared AWS account** was untouched throughout — that blast radius is not ephemeral. Four
(**F41**, the account-wide half of **F47**, **F56**, **F58**) cannot be fixed in this repo;
they are filed upstream (§ 9.4).

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
| **BR-D16** | **The AOSS collection stays publicly reachable, and that is the default outcome — not a fallback.** *(Changed 2026-08-05 by BR-D23; was "reserved, allocated by S3-T1" pending a research task on VPC reachability.)* A VPC endpoint plus two subnets, a security group and a VPC-attached runner, to protect a vector store holding **nothing**, in a single-operator lab, is ceremony — and the original plan made it a hard dependency of a second task, propagating the cost into another sprint. The accepted risk: the collection's data plane is reachable from the internet with **SigV4 as the only control** (TB4). The compensating controls that carry it are the AOSS data-access policy (which names principals, not networks), the empty corpus (BR-D20), and the single-consumer posture (BR-D11). **Revisit the day BR-D11 is revisited** — a second consumer or the first non-public document — not before. |
| **BR-D22** | **State confidentiality comes from OpenTofu native client-side encryption. The DynamoDB lock table stays.** *(Decided 2026-08-05; amended the same day — see below.)* SSE-S3 on the state bucket protects the object at rest in S3 and nothing else; it does not protect a state file from anyone who can legitimately `s3:GetObject` it, which after ST-T2 includes **a plan role assumable from any pull request**. Native client-side encryption (`terraform { encryption { … } }`, `aws_kms` key provider, OpenTofu ≥ 1.7) does. This is the control that makes the BR-D21 secrets pilot honest — see § 9.5. **Ownership splits, and does not follow BR-D17 cleanly:** BR-D17 assigns the state *backend* upstream, but **neither mechanism here is backend-side.** Native encryption is a **client-side** block in *every root that writes state*; `global-bootstrap` cannot enable it for this repo. So: upstream owns the key-provider choice (filed as an issue, § 9.4); **this repo owns the `encryption {}` block in both roots and the `required_version` floors**, folded into S2-T4. Note `bootstrap/providers.tf`'s `terraform {}` block declares **no `required_version` at all**, and `environments/ai-lab`'s `>= 1.8.0` already covers encryption, so no floor bump is needed there. **AMENDED — `use_lockfile` is NOT adopted and the DynamoDB lock table is retained, managed as IaC.** The original draft retired the lock table in favour of S3-native locking. That was wrong: this repo's own `bedrock-lab-state-locks` retires under BR-D17/F43, but the table it then uses is the org's `global-tofu-lock`, **shared with `bounty-infra`, `tri-loop` and `resume-optimizer`**. Retiring it would force every consumer repo to raise its OpenTofu floor and rewrite its backend block in lockstep — a coordinated multi-repo migration, against shared infrastructure, for no risk reduction. `dynamodb_table` therefore **stays** in `environments/ai-lab/backend.tf`; S2-T4 repoints it at the org table rather than removing it. *(Open, non-blocking: Terraform deprecated `dynamodb_table` in 1.11 in favour of `use_lockfile`. Whether OpenTofu followed is **unverified** — check the changelog at S2-T4 rather than assuming either way. If it did, this buys a deprecation warning now and a migration later; it does not change the decision.)* |
| **BR-D23** | **The plan is scaled to the system that exists, not the one it resembles.** 158 lines of Python, an empty corpus, one operator, and a lab whose stated design is destroy-and-rebuild — against, originally, nine sprints, twelve required CI checks, five runbooks, a customer-managed KMS key, and a devcontainer carrying a permanent five-tool pin-sync obligation. **The blast-radius work (F1, F41, F45, F47, F40) is untouched and gets everything the plan gives it.** Everything downstream of S2 is cut to fit. **The structural fix matters more than the cuts:** the plan scheduled *"make the project work at all"* (F51/F39/F5) **fifth**, behind three sprints of governance and pipeline construction — while BR-D20 declares `destroy → apply → verify` the acceptance test every infrastructure sprint must pass. No sprint before S2 could pass it, and S1 in particular built an Environment gate, a saved-plan apply and seven required checks *around an apply that had never once succeeded*. The new **`MW`** sprint runs immediately after ST and fixes that. **What this is not:** it is not "five sprints instead of nine" — that headline does not survive its own task list. It is **roughly the same sprint count with about half the tasks, and far fewer permanent obligations**: no pin-sync treadmill, no customer-managed key, no second S3 bucket, four fewer required checks. See § 5 for the resulting sequence. |
| **BR-D24** | **One severity rule, stated once; and no `Blocker` tier.** *(a)* **A multiplier is rated at the severity of the worst outcome it enables** — see the head of § 3, where it now lives. The inventory previously applied this two ways (F17 Critical *as* a multiplier, F47 High *because* multipliers rank lower), which is what surfaced it. Consequences: **F45 → Critical** (its trigger is a repository-settings change with no diff, no PR and no review surface anywhere — and it is the one Critical this plan intends to *create*), **F47 → Critical** (it is what turns lab compromise into compromise of bounty-infra's findings archive), **F13 → High** (its Critical rating double-counted F1's escalation and F17's absent gate; strip both and a BR-D2 violation remains, which is High). **Two arguments for lowering F13 were considered and explicitly rejected**: that no push-to-`main` run has ever succeeded, and that the workflow is `paths:`-filtered. Both are artifacts *this plan deletes*, so recording them as rationale would make the entry false the day `MW` lands. *(b)* **No `Blocker` severity.** F51 is a defect in the deliverable, not a risk, and this scale measures risk; bolting a delivery band onto it muddles both and creates a permanent "is this Blocker or Critical?" argument. The harm the tier was meant to signal was **scheduling**, and BR-D23 already fixed it by creating `MW`. F51 stays High, and § 5 states explicitly that ordering is not by severity. |

---

## 5. Sprint sequence

*Reshaped 2026-08-05 by **BR-D23**. Sprint ids are stable — `S3` and `S4` merge but keep both
ids, and no sprint is renumbered, because renumbering would invalidate every cross-reference
already written into these plans and every `Closes:` line in the inventory.*

| Sprint | Title | Closes | Status |
| --- | --- | --- | --- |
| **S0** | Governance and repository baseline *(+ the Infisical deletion and the budget, pulled forward)* | F17, F33–F38, F53 (the deletion half), F54; **the budget closes no `F`** — it is capability work, see § 5 | **planned** |
| **ST** | **Organization transfer** — `Seuss27/` → `glunk-works/` | F44, F45, F50, F57, F58, and the ST-T1 half of F40 | planned |
| **MW** | **Make it work** — the first successful `destroy → apply → verify` cycle | **F51**, F39, F5, F46, F55 | planned |
| **S1** | Pipeline hardening *(thinned)* | F13–F16, F18–F21 | planned |
| **S2** | Identity, state reconciliation, and `bootstrap/` retirement *(remainder)* | F1–F4, F40, F42, F43, F47 (local half), F48, F56, BR-D22 | planned |
| **S3+S4** | Data-plane and RAG posture *(merged, ~half the tasks)* | F6–F12, F22–F26, F28 | planned |
| **S5** | Python cleanup *(four items, not a supply-chain programme)* | F29, F31, F32 | planned |
| **S6** | Documentation and operational readiness *(two runbooks)* | #8, BR-D13, F53 (the README half) | planned |
| **SD** | Development container | — (capability; records BR-D15) | **deferred** |

**`MW` is letter-prefixed** for the same reason `ST` is: it was inserted after the numbering
was set, and renumbering costs more than it buys. It is **not** parallel — it is a hard
sequence point, and the reason it exists is below.

**`SD` is deferred, not optional.** It is blocked on Docker, which the workstation does not
have, so it is undeliverable today regardless of merit — that is a fact, not a judgement, and
it does not need re-arguing each sprint. On the merits it also carries a permanent obligation
(BR-D15: every pin kept *equal* to CI's, forever, on every future bump) against the two pains
actually observed — CRLF, already fixed by `.gitattributes` in S0-T5, and the `-backend=false`
wrinkle, already two lines in `CLAUDE.md`. **Precondition to revisit: Docker on the
workstation.** If it is ever picked up, it must not gate S5.

Plans live at `sprints/S<N>_<slug>/sprint_plan.md`. Each carries a **Critical review**
section recording the security, logic, and execution objections raised against it during
planning and how they were resolved — that review is part of the plan, not a separate
artifact.

### Why this order

The ordering is not by severity, and that is deliberate. **The sharpest case is F51** — rated
High because this scale measures risk and a total *functional* failure is not a risk, but
scheduled **first among all non-blast-radius work** regardless of that label, because every
acceptance criterion in S3+S4 reads `tofu plan` output that is meaningless until it is fixed.
Severity ranks; this section schedules. Where they disagree, this section wins (BR-D24).

- **S0 before everything** because F17 is the multiplier: until a ruleset exists, every
  control the later sprints add is advisory. Fixing F1 (Critical) while `main` accepts a
  direct push means the fix can be reverted by anyone with push access, unreviewed. **S0 also
  absorbs two items pulled forward** (BR-D23): the *deletion* half of F53 — the commented-out
  Infisical scaffolding and the three README lines that tell a reader to provision the exact
  credential F52 says to revoke — because it is pure deletion with zero apply risk and no
  reason to sit seven sprints out; and the **budget** (F27), because the plan stated in its
  own words that an environment left running is *"the most likely real-world loss this project
  will ever produce"* and then scheduled its control ninth. An `aws_budgets_budget` with three
  thresholds is about fifteen lines. **It closes no `F` finding** — cost was never entered in
  the inventory, which is itself part of why it ranked ninth. Take only the budget and
  `docs/cost.md`; the AOSS capacity-limit half is dead (§ 5.1).
- **`MW` immediately after ST**, and this is the correction BR-D23 exists to make. BR-D20
  declares `destroy → apply → verify` the acceptance test every infrastructure sprint must
  ultimately pass — and **no sprint before S2 could pass it**, because no `tofu apply` has ever
  succeeded (F51). The original order spent S1 building an Environment gate, a saved-plan
  apply, seven required checks and a plan-summarizer *around an apply that had never once
  worked*; S1's own Risks section conceded that a green plan job "proves the *job* works, not
  that the plan is accurate." `MW` pulls forward the teardown-and-rebuild (F39/F5, ex-S2-T1),
  the AOSS data-access fix (ex-S2-T6) and the retry-loop fix (F46, ex-S4-T4) — the last of
  which is what makes the cycle *diagnosable* rather than a twelve-minute silent retry. From
  `MW` onward every sprint validates against a real cycle instead of a fiction.
  **`MW` cannot start until F55 is closed** — see the hazard list below; that is the one
  ordering constraint inside it that is easy to miss and expensive to discover.
- **ST between S0 and S1**, and this is the sequencing decision the 2026-08-05 answers
  forced. The owner name is inside **every** OIDC subject, and repository *variables* do not
  survive a transfer — so doing S1 (which sets `AWS_PLAN_ROLE_ARN`, creates the `production`
  Environment, and adds an `environment:production` subject) *before* the transfer means
  doing all of it twice. ST also has a hard internal ordering of its own: the upstream policy
  fix must land **before** the transfer, because the transfer is what makes the dormant
  over-privileged org role reachable (**F45**).
- **S1 before S2** because S2 splits one role into two, and a two-role model is only
  meaningful once the pipeline actually has separate plan and apply jobs to assume them.
  Doing S2 first would create a role nothing uses. S1 is **thinned** (BR-D23): T1, T2, T4, T5
  and T6 are load-bearing and stay; `iac-diff-guard` is **cut** — the plan itself concedes it
  is bypassable and forbids making it required, so its entire value is a comment, bought at a
  CI minute on every PR forever. The requirement moves to the PR template.
- **S2 before S3+S4** because those changes are applied *by* the deploy role. Hardening the
  data plane while the role that manages it can escalate to admin protects the wrong thing
  first.
- **S3 and S4 merge** (BR-D23). Both shrank far enough that two sprints is bookkeeping: S3
  keeps the S3 bucket public-access block and TLS-only deny, the tags, and the provider-version
  reconciliation; S4 keeps the Guardrail, `inclusion_prefixes` + prefix deny, and the
  embedding-model variable extraction. What went, and why, is in **§ 5.1**.
- **S5 and S6 last** because nothing else depends on them. S6 in particular *must* be last:
  a README rewritten before the architecture stops changing is a README that needs rewriting
  again, which is how #8 came to exist. Both are **cut hard** — S5 to four items, S6 to two
  runbooks. See § 5.1.

### Known ordering hazards

1. **⚠ `MW`'s teardown is irreversible until F55 is closed. This is the hazard that costs
   most.** `MW` deletes every orphaned workload resource and rebuilds — but the rebuild runs
   under `github-actions-deploy-role`'s **current** policy, which cannot create at least four
   things the module declares (F55). Those grants have never been exercised, because the last
   run died at `EntityAlreadyExists` before AOSS or Bedrock were reached. Execute the teardown
   first and the working-but-orphaned system is gone, the rebuild fails `AccessDenied`, and
   recovery needs an out-of-band human apply against the very `bootstrap/` root being retired.
   **"The deploy identity is provably sufficient for a from-scratch apply" is a *precondition*
   of `MW`, demonstrated by a dry run before anything is deleted — never a discovery.** Either
   adopt the corrected upstream role first, or widen the current policy first; the sprint plan
   picks one. **Regenerate the missing-verb list from the dry run, not from F55's text.**
2. **F57 precedes the upstream boundary condition, and they live in different repositories.**
   The module's KB execution role must gain `path` and `permissions_boundary` **before**
   ST-T2's `iam:PermissionsBoundary` condition goes live upstream, or CI's `CreateRole` is
   denied at S2-T2's *verify* step — the exact moment the escalation-capable local role still
   exists and the cheapest unblock is to drop the condition, reverting the whole construction.
3. **The retry-loop fix (F46) ships with `MW`, not after it.** It was S4-T4, two sprints
   later. Without it the first real cycle runs through a twelve-minute silent retry that
   reports an authorization failure as a propagation delay — turning the sprint whose whole
   purpose is diagnosis into the least diagnosable one.
4. **`MW` and S5 both touch `create_index.py`.** `MW` removes the destructive delete and the
   in-module `local-exec`; S5 adds the one contract test. Run `MW` **first** — otherwise S5
   pins behavior `MW` is about to delete, and `MW` lands looking like a regression.
5. **Every sprint that adds a gating check must append it to three places in one PR** — the
   live ruleset, `.ai/project.yml`, and `ruleset-drift.yml` (BR-D9, § 6).
6. **The upstream policy fix precedes the transfer** (F45). Transferring first opens an
   escalation path into the shared account with no IaC diff to review.
7. **State reconciliation (F39) precedes S3+S4.** That sprint uses "read the `tofu plan`
   output" as an acceptance criterion — for replacements, for `No changes.`, for tag updates —
   against a split-brain state that plans a system which is not there. **`MW` reconciles by
   teardown and rebuild, never by import (BR-D19, reversed).** Until `MW` lands, treat every
   plan as unverified.
8. **BR-D22's `encryption {}` block lands before the BR-D21 secrets canary.** § 9.5 has the
   reason: a `data.aws_ssm_parameter` value is *in state*, and after S2-T4 that state is
   readable by a role assumable from any pull request. Running the canary first would make the
   pilot demonstrate the anti-pattern two other repos are meant to copy.

### 5.1 What BR-D23 cut, and the reasons that must survive the cut

Recorded so a later session re-adds these **on their merits**, not by accident — and so the
two that were cut for a *safety* reason are never mistaken for cost trimming.

**Cut for a blast-radius reason. These do not come back when the lab gets real data.**

- **Bedrock model-invocation logging** *(was S4-T2)*.
  `aws_bedrock_model_invocation_logging_configuration` is a **per-region singleton**.
  Provisioning it from this repo takes over Bedrock logging **for the entire shared AWS
  account** — the one holding `global-bootstrap`'s state and bounty-infra's findings archive.
  That is the `CLAUDE.md` hard edge ("never delete or weaken anything shared"), not
  proportionality. **The obvious future argument — "we have real prompts now, let's log them"
  — does not unblock this**; the singleton collision is exactly as bad then. If invocation
  logging is ever wanted, it is an **`global-bootstrap` deliverable** configured once for the
  account, not a workload resource. *(The task also proposed CloudTrail S3 data events billed
  per event, and created a new sensitive asset — a prompt-and-completion log — to audit a
  system with no users and no data.)*
- **The dedicated read-only query IAM role** *(was part of S4-T5)*. The query path is an
  interactive script the operator runs under their own SSO session; a role adds an identity to
  maintain and removes nothing. The **variable extraction in the same task is kept** — the two
  independently-declared embedding-model ARNs are a genuine trap (change one, and the index
  `dimension` silently disagrees).

**Cut on proportionality. These come back when the premise changes — and the premise is
named, so it is checkable.**

| Cut | Was | Comes back when |
| --- | --- | --- |
| Customer-managed KMS key | S3-T4 | The corpus holds data worth a key policy, rotation and revocation. Today it buys CloudTrail key-use records **over data that does not exist**, on a cost-sensitive lab, and introduces an `AccessDenied` "that names neither the key nor the role" into a pipeline that has never applied. BR-D10 is what will already be in place. |
| Dedicated S3 access-log bucket | S3-T2 | The source bucket holds objects. A second bucket, its own public-access block, its own lifecycle rule — a new standing asset to log access to a bucket with **zero objects**. |
| Bucket versioning | S3-T2 | The corpus stops being disposable (BR-D20). |
| SBOM (CycloneDX) | S5 | There is a consumer or a distributable. There is neither. |
| `dependency-audit` **as a required check** | S5 | Someone is on call. **The scan still runs** — the cut is the *gate*. A new upstream CVE turning `main` red on a repo designed to sit destroyed is the wrong trade. |
| Five hatch environments | S5 | There is a package and a build backend. There is neither. |
| Python 3.11 → 3.12 migration | S5 | Never, on its own merits — it is convention conformance with zero risk reduction. |
| `ingest.md`, `reindex.md`, `incident-injection.md` runbooks | S6-T2 | The operations they document have been performed at least once. They document operations never performed on a corpus that does not exist, and the third depends on the alarm cut above. **`teardown.md` and `break-glass.md` are kept** — BR-D20 makes teardown the primary operating procedure, and break-glass is the one procedure where being wrong costs most. |
| `iac-diff-guard` | S1 | Never — see § 5's S1 note. |
| VPC-restricted collection | S3-T1 | BR-D11 is revisited. Now recorded as the **default** outcome in BR-D16, not a fallback. |

**Moved, not cut.**

- **The SSM secrets canary** *(was S3-T8)* → an issue on `glunk-works/global-bootstrap`. § 9.5
  already says the *pattern* belongs upstream; it is now explicit that the **work** does too.
  A pilot whose deliverable is "a pattern two other repos copy" has a different owner and a
  different acceptance bar than a local cleanup. **The Infisical *deletion* half stays here and
  moves earlier, to S0.**
- **F46's retry fix** *(was S4-T4)* → `MW`. See hazard 3.
- **The budget** *(was S6-T3)* → S0. See § 5. *(Its companion half — an AOSS capacity limit via
  `aws_opensearchserverless_account_settings` — is **dead**: that resource does not exist under
  any spelling, provider issue `hashicorp/terraform-provider-aws#41245`, open since 2025-02-05.
  A capacity limit is console/CLI-only. Do not write it into a task.)*

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

**And it is weaker still than that sentence implies** *(corrected 2026-08-05, **F58**)*. Two
gaps in the Deny itself, both upstream:

1. **It says "the plan role**s**" — plural — but is attached to one.** `bounty_infra_plan_policy`
   and its attachment are hardcoded, not `for_each`ed over `var.projects`. The plan role ST-T2
   creates for *this* project would therefore carry **no findings Deny at all**.
2. **It names `s3:*` and not `kms:`.** Asset #1 is two resources (§ 2.2) — the findings bucket
   and the KMS key encrypting it. An `s3:*` Deny does not constrain `kms:ScheduleKeyDeletion`
   or `kms:PutKeyPolicy` against that key, which are respectively irreversible destruction of
   the archive and a rewrite of who may decrypt it. **Fix the Deny upstream *before* any KMS
   verbs are granted to a workload policy**, not after.

**F56** — the read-only plan role is unusable by this project in two independent ways: its
trust admits only `:pull_request`, and the workload *read* policy is hardcoded to
`bounty_infra_plan_policy` rather than generated per project. Both are upstream changes. File
with F41: this project needs a `bedrock_rag_plan_policy` mirror **carrying the corrected Deny
above**, and either an `extra_oidc_subjects` equivalent on `plan_roles.tf` or an explicit
decision that no `push`-triggered job assumes a plan role.

**The `StringLike` → `StringEquals` change on the apply role's trust** *(F2, `[M2]` § 6)*.
Wildcard-free today and so functionally equivalent — but F2's whole substance is that in IAM
`StringLike`, `*` matches `:` too, so the moment anyone adds an `extra_oidc_subjects` entry
containing a `*` it globs silently. Cheap to fix while it is still a no-op.

**BR-D22's key-provider choice** — which KMS key backs OpenTofu native state encryption for
the org state bucket. Upstream owns the key; **each consuming repo owns its own `encryption {}`
block**, so this issue is the key and the documented pattern, not a change that can be applied
on this repo's behalf.

**F8's carried-forward controls** *(`[M2]` § 1)*. S3's plan was to mark F8 closed-by-supersession
once state moves into the org bucket. Verified against live `global-bootstrap/main.tf`: that
bucket has versioning and SSE-S3 — but **no `aws_s3_bucket_public_access_block`** (the only PAB
upstream is `findings_privacy`, on the *findings* bucket), **no TLS-only bucket policy**, and
the lock table has **neither `prevent_destroy` nor PITR** — which is the exact sub-finding F8
names. **F8 closes by supersession for versioning and encryption only**; the other four carry
forward as this upstream issue. Do not let a coder tick F8 whole.

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

**Which is also the pilot's weakness.** A pilot that migrates nothing exercises none of the
hard parts — creating a parameter, granting a CI role `ssm:GetParameter` + `kms:Decrypt`,
reading it at runtime through `data.aws_ssm_parameter`, and keeping the value out of `tofu
plan` output (an SSM value read into state **is in state**, and state renders in plan —
BR-D4). A pattern that has never been executed is a proposal. So the pilot must **prove the
path end-to-end with a disposable throwaway parameter, created and destroyed inside the task**
— the most BR-D20-native way to test anything here: create, verify, destroy.

> **Ownership moved 2026-08-05 (BR-D23).** The canary is now an **issue on
> `glunk-works/global-bootstrap`**, not a task in this repo. A deliverable whose acceptance bar
> is "two other repos can copy this" has a different owner than a local cleanup, and this
> section already said the *pattern* belongs upstream — it now says the *work* does. **The
> Infisical deletion half stays here and moved earlier, to S0.**

**Three constraints the pattern must carry, or it teaches the wrong thing** *(advisory `[M2]`
§ 2)*. These are the reason the canary is worth doing at all, and they are what the consuming
repos — which hold *real* secrets — will inherit:

1. **⚠ Ordering: BR-D22's native state encryption lands FIRST.** This is a hard dependency, not
   a preference. After S2-T4 the state sits in the org bucket, **versioned forever**, under
   SSE-S3 — and ST-T2's `plan_role = true` creates a role **assumable from any pull request**
   whose state-read policy grants `s3:GetObject` on exactly that prefix. Run the canary before
   encryption exists and a PR-time identity can read every historical plaintext value the
   pattern ever produced. SSE-KMS would not close this; **client-side encryption does.**
2. **Verify without printing.** "A CI run is on record resolving the canary" invites an
   `output` or an `echo` — i.e. publishing a `SecureString` into a world-readable log on a
   public repo (TB5). Mandate a **non-sensitive sentinel value**, and confirmation via
   `length()` or a hash inside `nonsensitive()`. Never the value; never a bare `tofu output`.
3. **State the rule the mechanism implies:** *never consume a secret through
   `data.aws_ssm_parameter` in a root whose state is readable by a PR-time role — fetch it at
   runtime, in the process that needs it.* Also worth one sentence: `alias/aws/ssm` is
   **account-shared**, so granting `kms:Decrypt` on it means isolation between projects' secrets
   rests entirely on the `ssm:GetParameter` resource ARN, with zero defence at the key. Correct
   today, and exactly the kind of thing an inheriting repo should be told rather than discover.

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
| 2026-08-05 | **Cold-context adversarial plan review of PR #18 — verdict SEND BACK, reached independently by all three critics** (`architect`, `security-critic`, `docs-consistency`), plus a provider-surface verification pass. Six defects were found by two critics independently. The security half was filed as **seven private draft security advisories** rather than posted to the public PR — several are working attack paths against the shared AWS account, and publishing them would be the BR-D4 violation the plan itself forbids. **Verified dead:** `aws_opensearchserverless_account_settings` does not exist under any spelling (provider issue #41245, open since 2025-02-05). **Verified dangerous:** `aws_bedrock_model_invocation_logging_configuration` is a per-region singleton. |
| 2026-08-05 | **Four findings added from the review — F55–F58** (§ 3.1d), all properties of live code rather than of the plan: the deploy identity cannot complete a from-scratch apply (**F55**, and the teardown that needs it was scheduled first); the upstream read-only plan role is unusable in two independent ways (**F56**); the KB execution role has no `path` or `permissions_boundary`, so the boundary ST-T2 installs would deny its creation (**F57**); and `DenyBountyFindingsDataAccess` is `s3:`-only and attached to one project's plan role (**F58**). Defects that existed only *in the plan* were fixed by amending the sprint plans and were deliberately **not** recorded as findings. Total **58**. |
| 2026-08-05 | **Operator decision 1 — BR-D23, the proportionality reshape.** New **`MW`** sprint immediately after ST, carrying the teardown-and-rebuild, the AOSS data-plane fix and the retry fix — because BR-D20 makes `destroy → apply → verify` the acceptance test every sprint must pass and **no sprint before S2 could pass it**. S0 gains the Infisical deletion and the budget; S3+S4 merge and lose about half their tasks; S5 cuts to four items; S6 to two runbooks; **SD is deferred on a stated Docker precondition**. Three architect amendments were attached to the operator's acceptance: **S4-T2 is cut for a blast-radius reason, not proportionality** (per-region singleton in a shared account — the argument "we have real data now" does not unblock it); **S4-T1's BR-D11 tripwire survives its demotion in writing**; and the review's **"~5 sprints instead of 9" headline is not propagated** — it did not survive its own task list. § 5.1 records every cut with the premise that would bring it back. |
| 2026-08-05 | **Operator decision 2 — BR-D24, one severity rule and no `Blocker` tier.** The inventory applied *multiplier* two contradictory ways (F17 Critical *as* a multiplier, F47 High *because* multipliers rank lower). Resolved in favour of **"a multiplier is rated at the severity of the worst outcome it enables"**, stated once at the head of § 3. **F45 → Critical** (its trigger is a settings change with no diff, no PR and no review surface, and it is the one Critical this plan intends to create), **F47 → Critical**, **F13 → High** on double-counting alone — the review's other two arguments for lowering F13 were **explicitly rejected** as artifacts this plan deletes. **Five Criticals: F1, F17, F41, F45, F47.** No `Blocker` tier: F51 is a defect in the deliverable, not a risk, and BR-D23 already fixed the scheduling harm. Totals recounted from the tables: **5 · 18 · 21 · 14 = 58** (the previously stated `4 · 17 · 19 · 15` summed to 55 against a stated total of 54). |
| 2026-08-05 | **Operator decision 3 — BR-D22, state confidentiality, amended in the same session.** Native OpenTofu **client-side** state encryption is adopted and folded into S2-T4; SSE-S3 does not protect state from a plan role assumable from any pull request, and client-side encryption is what makes the BR-D21 secrets pilot honest (§ 9.5). **Ownership does not follow BR-D17 cleanly** — the `encryption {}` block is per-root client-side configuration that `global-bootstrap` cannot set on this repo's behalf, so it splits: upstream owns the key provider, this repo owns the block and the `required_version` floors. **Amended by the operator: `use_lockfile` is NOT adopted and the DynamoDB lock table stays**, because the table this repo migrates onto is the org's `global-tofu-lock`, shared with three sibling pipelines — retiring it would force a coordinated multi-repo migration against shared infrastructure for no risk reduction. |
