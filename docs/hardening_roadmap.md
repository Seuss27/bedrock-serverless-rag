# Hardening roadmap — bedrock-serverless-rag

**Reference of record.** This file is the deep record: the evaluation that produced the
work, the locked decisions, the sprint sequence, and the public-repo data-handling rules.
It doubles as this repo's **threat model** (`.ai/project.yml: threat_model`), so
`security-critic` reads it as ground truth. `CLAUDE.md` routes; this file explains.

The live cursor — which sprint, which task, which model — is `.ai/next-steps.md`, not here.

- **Evaluated:** 2026-08-05, against `main` @ `429ca10`.
- **Posture at evaluation:** public repo, no branch protection, CI applies to AWS unreviewed
  with a role that can escalate to account administrator. Sprints S0–S2 exist to close that
  sentence; everything after hardens what is left.
- **Posture today** *(2026-08-07, after S0 and ST)*: the repo is **public** and lives at
  **`glunk-works/bedrock-serverless-rag`**. **Branch protection is live** — S0 installed
  `protected-integration-branches` on `main` (F17 closed), so that clause of the evaluation
  posture no longer holds. **The other two still do:** CI still applies to AWS with
  `-auto-approve` and no human gate (F13, S1-T5), under a role that still holds
  `iam:CreateRole` on `*` (F1, S2-T2). Do not read "S0 and ST are done" as "the pipeline is
  governed" — the deterministic gate exists, and the thing it gates has not been built yet.

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
  the trust policy's `sub` condition admits*. Today that condition is a `StringLike` over
  **`repo:<owner>@<org_id>/<repo>@<repo_id>:*`** — every branch, every PR, every environment
  (**F2**, still open) — and the role it admits can create IAM roles and policies on `*`
  (**F1**). ⚠️ **The `@<id>` segments are not decoration** *(corrected 2026-08-07; this read
  `repo:<owner>/<repo>:*` until then)*: an **org-owned** repo presents an **ID-qualified**
  subject, and a plain `repo:<owner>/<repo>:*` glob **does not match it**. Writing the plain
  form into a trust policy is what broke CI authentication at the transfer (BR-D13). **What is
  unchanged is the finding**: the trailing `:*` is the part that admits `:pull_request`, so
  TB1 is exactly as wide as it was.
- **TB2 — the repo → CI.** A merged (or pushed) commit becomes an `apply`. **At evaluation**
  this was a formality on both counts — no branch protection (**F17**) and no approval gate
  (**F13**). ⚠️ **Half of that is fixed and half is not, and reading it as "still a formality"
  is now wrong** *(updated 2026-08-07 — this sentence asserted "with no branch protection"
  through the whole of S0 and ST)*. **F17 is CLOSED**: `protected-integration-branches` is
  active on `main`, unbypassable, with `pr-title` required, so reaching `main` genuinely
  requires a PR. **F13 is OPEN**: the merge that follows still runs `tofu apply -auto-approve`
  with no `environment:` gate and no human approval (S1-T5). So the boundary is real at the
  *merge* and absent at the *apply* — and the second is the one that reaches AWS.
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
| **F1** | **Critical** | *(Closed in S2-T2 by **deleting** the role, not by hardening it — BR-D17. The boundary construction originally drafted here moved upstream to ST-T2 — and **came back**: `ST-T2′` deleted the policy it would have constrained, so it is built in **S2-T0**, per ST Task 2b. Corrected 2026-08-07.)* `state_access_policy` grants `iam:CreateRole`, `iam:PutRolePolicy`, `iam:AttachRolePolicy`, `iam:DeleteRolePolicy`, `iam:DeleteRole` on `Resource = "*"`. This is **privilege escalation to account administrator**: the CI role can mint a role with `AdministratorAccess` and attach a trust policy naming itself. The `Resource = "*"` even carries an in-file comment conceding it. | `bootstrap/state-backend.tf:82-111` | **S2-T2** |
| **F2** | High | OIDC trust condition is `StringLike` over `var.github_oidc_subject_prefixes`, each rendered `"${prefix}:*"`. *(Mechanism and evidence pointer updated 2026-08-06 — ST-T3 replaced `var.github_repo_path`, which no longer exists; the finding itself is unchanged and still **open**.)* The `*` admits every branch, every `pull_request`, and every environment — and in IAM `StringLike`, `*` matches `:` too, so it also admits claim shapes that do not exist yet. **Closed by adoption — but NOT on the operator this previously claimed.** *(Corrected 2026-08-05, advisory `[M2]` § 6.)* This entry used to read "the upstream role's trust is already `StringEquals` over an enumerated subject list." **It is not.** Live `global-bootstrap/main.tf` uses **`StringLike`** on `…:sub` for the **apply** role; `StringEquals` appears only on the **plan** role, where a comment says so explicitly. The values are wildcard-free today so it is functionally equivalent — but F2's entire substance is *"in IAM `StringLike`, `*` matches `:` too"*, so closing it on an operator the upstream code does not use means any future `extra_oidc_subjects` entry containing a `*` globs silently. **S2-T2 gains an acceptance criterion — "the adopted role's trust condition uses `StringEquals`" — and the `StringLike` → `StringEquals` change is filed with the F41 upstream issue (§ 9.4).** ST-T3 widened this glob temporarily during the transfer and has since narrowed it, then S2-T2 deletes the role entirely. **⚠️ Whoever closes F2 must enumerate the ID-QUALIFIED subject form** — `repo:<owner>@<org_id>/<repo>@<repo_id>:<context>` — which is what this org-owned repository actually presents, measured from CloudTrail in ST-T3. Enumerating the plain form under `StringEquals` reproduces the CI-authentication outage the transfer caused, in the task that also deletes the fallback role. The trap is written up in full in S2-T2's body, and note `global-bootstrap` builds subjects from `github_organization` + `repo_name`, i.e. the plain form. | `bootstrap/oidc-setup.tf` (the `github_oidc_subject_prefixes` variable and the `StringLike` condition) | S2-T2 |
| **F3** | High | **One role for plan and apply — and this is code execution, not a least-privilege smell.** *(Sharpened 2026-08-05, advisory `[M2]` § 4. The severity was already right; the **mechanism** was written nowhere, which is why this entry read as hygiene and got deferred.)* The PR-triggered plan job assumes the same role the apply job does, so read-only review work holds credentials that can destroy the account. **The part that was missing: a `pull_request`-triggered job runs the workflow file *from the PR branch*.** `deploy-ai-lab.yml` runs on `pull_request` (`:7-9`) and assumes `vars.AWS_OIDC_ROLE_ARN`, whose **live** trust is `StringLike` over `repo:<owner>@<org_id>/<repo>@<repo_id>:*` — which **still** admits `:pull_request`. *(Subject form corrected 2026-08-07: an org-owned repo presents an ID-qualified subject; the trailing `:*` is what makes this finding true, and it is unchanged.)* So **anyone who can push a branch edits the `run:` block and gets `iam:CreateRole` on `*`** (F1) in the account holding bounty-infra's findings archive (F47). No merge, no review, no approval. The rule is now stated in `CLAUDE.md` § *Local: GitHub Actions security*. **Closed by adoption rather than by fixing:** `global-bootstrap`'s `plan_roles.tf` already provides a separate read-only identity trusted only on `:pull_request` — ~~opted into by ST-T2~~ **opted into by S2-T0** and switched to in S2-T2. *(Corrected 2026-08-07: `ST-T2′` deleted this project's `var.projects` entry, so **no plan role exists for it today** and F3 stays fully open until S2-T0 sets `plan_role = true` again. See **F56**.)* | `bootstrap/oidc-setup.tf`, `.github/workflows/deploy-ai-lab.yml` | S2-T2 |
| **F4** | Medium | Confused-deputy: `bedrock_kb_role`'s trust policy conditions on `aws:SourceAccount` but not `aws:SourceArn`, so any Bedrock resource in the account can induce the service to assume it. Filed as **#6**. | `modules/aws-bedrock-rag/iam.tf:33-37` | S2-T4 |
| **F5** | **High** *(confirmed live 2026-08-05)* | The AOSS data-access policy names `data.aws_arn.current_identity.arn` — *whoever ran the last apply*. Locally that is a human SSO session; in CI it is the deploy role. It also resolves to an **`sts` assumed-role ARN**, not an IAM role ARN, so the granted principal can be a session that no longer exists, and alternating local/CI applies produce a perpetual diff. **This is not theoretical: run `26788807269` shows `create_index.py` failing `AuthorizationException(403, '')` six times in a row** — the policy had been applied from a human SSO session, so the CI role has no data-plane access at all. | `modules/aws-bedrock-rag/iam.tf:121` | S2 |
| **F50** | ~~High~~ **Medium** *(confirmed live 2026-08-05; downgraded by BR-D20 — the fix is a one-line commit, and a broken lab apply costs nothing)* | **✅ CLOSED 2026-08-06 by ST-T0, and the direction it closed in is the point.** The drift was *code behind live*, so committing `iam:ListAttachedRolePolicies` to `bootstrap/state-backend.tf` closed it **with no apply at all** — a live `tofu plan` then reported `No changes.` The plan had budgeted a human apply for this and did not need one, which dropped ST from four human applies to three against the unbacked-up state file F48 is about. **Generalisable: when code is behind live, committing the code is the write-free direction; letting the apply reconcile is the destructive one.** The original finding follows. **`bootstrap/` has uncommitted drift, and the next `tofu apply` there would silently revoke a permission CI needs.** `tofu plan` in `bootstrap/` reports **`1 to change`**: it removes `iam:ListAttachedRolePolicies` from `state_access_policy`. That action is present in the **live** AWS policy and absent from the committed HCL, and `git log -- bootstrap/state-backend.tf` shows no commit that ever added it — so it was granted out-of-band, almost certainly to fix a failing apply. It is **needed**: the AWS provider calls `ListAttachedRolePolicies` when refreshing an `aws_iam_role`, which CI does for `bedrock_kb_role` on every plan. **Operational trap:** `bootstrap/` is human-applied with admin credentials, gets no CI and no review, so this revocation rides along with the *next* apply for any unrelated reason — e.g. ST-T1 or ST-T3 widening the OIDC trust for the transfer. CI would then break and the trust-policy change would take the blame. **Resolution: commit the action to the HCL** (code matches live) before any `bootstrap/` apply. This is F39's class — committed IaC ≠ deployed system — in the root previously assumed to be in sync. | `bootstrap/state-backend.tf:82-111` vs live | **before ST-T1** |
| **F39** | ~~Critical~~ ~~Medium~~ **Low** *(confirmed 2026-08-05; downgraded by BR-D20; **downgraded again 2026-08-07 when it was finally MEASURED**)* | **🔄 THE FINDING BELOW IS FALSE AS WRITTEN — corrected 2026-08-07 by `MW`'s pre-implementation plan review, against live AWS.** There is **no split brain**. AWS holds **one** of this module's resources: `personal-bedrock-kb-execution-role`, at path `/`, with **zero inline and zero attached policies**. The bucket, the collection, all three AOSS policy types, the Knowledge Base, the data source and the budget are all **absent**, and `tofu state list` returns **nothing** — the state is cleanly **empty**, not stale. **Mechanism, proven rather than inferred:** the state object's S3 version history shows apply/destroy churn through 2026-06-01 ending in a **153-byte (empty) latest version at `2026-06-02T00:22:37Z`**, and CloudTrail places `DeleteCollection`/`DeleteBucket`/`DeleteSecurityPolicy` in the **same minute** under a human SSO session. **That was a completed `tofu destroy` from this backend** — so a destroy has in fact succeeded here once, which "the cycle has never worked" should not be read to deny. The role survived it **because it was never in state**, which is also why run `26788807269` hit `EntityAlreadyExists` 43 minutes *before* the destroy; its inline policy was removed by hand on 2026-06-25. **So F39 reduces to: one out-of-band role shell, removed by one `delete-role` call** (`MW`-T5 step 1), and the full measured inventory lives in `sprints/MW_make_it_work/sprint_plan.md` § *Measured live state*. **📌 The general lesson, which outlives the finding:** every assertion about what existed in AWS traced back to a run dated **2026-06-01** and was carried through the 2026-08-05 evaluation and two sprint reshapes **without ever being re-measured**. **The original text follows, unedited.** ~~**The OpenTofu state CI uses does not describe the deployed system.**~~ Run `26788807269` (the last push to `main`) fails with `EntityAlreadyExists: Role with name personal-bedrock-kb-execution-role already exists` and `waiting for S3 Bucket (…-source) create: empty result`. The resources **exist in AWS**, created out-of-band with human SSO credentials, and are **absent from the state file CI reads** — a split brain. **No CI apply has ever succeeded** (every `push`-to-`main` run is `failure` or `cancelled`). **Remedy reversed by BR-D19/BR-D20:** the corpus is empty and nothing here is precious, so this is *not* an import exercise. **Delete the orphaned resources and apply clean.** That is faster, carries no data risk, and avoids freezing the current bad resource names into `import` blocks. It stays worth doing early only because `tofu plan` output is meaningless until it is done — and S3+S4 lean on plan output as an acceptance criterion. **That argument is what moved it: BR-D23 pulled it out of S2 into `MW`, immediately after ST.** | `environments/ai-lab` state vs live AWS | **MW-T5** (delete the orphan), **MW-T6** (`No changes.`) |

### 3.1b Cross-repo coupling with `glunk-works/global-bootstrap`

`glunk-works/global-bootstrap` is the organization's centralized IaC foundation: it owns the
org state bucket + lock table, **consumes** the GitHub OIDC provider as a `data` source, and
generates one CI role per project from `var.projects` — **including an entry for this repo**.
Full analysis in § 9. These five findings come from reading it against this repo.

| ID | Sev | Finding | Where | Sprint |
| --- | --- | --- | --- | --- |
| **F40** | **High** | **OIDC provider ownership collision, with a destroy hazard.** This repo's `bootstrap/oidc-setup.tf` **creates** `aws_iam_openid_connect_provider` for `token.actions.githubusercontent.com`; global-bootstrap **reads** the same provider via `data.aws_iam_openid_connect_provider.github`. **An AWS account can hold only one provider per URL.** If both target the same account, this repo's OpenTofu state owns the federation endpoint that *every glunk-works pipeline* depends on — and unlike the state bucket, it carries **no `prevent_destroy`**. A `tofu destroy` in this repo's `bootstrap/` would break CI for the entire organization. **✅ Stopgap DONE 2026-08-05 — `prevent_destroy` merged to `main` (PR #17, `1ad5aa7`) and verified against live state: a targeted destroy plan now fails with `Instance cannot be destroyed`. The durable fix — moving ownership to `global-bootstrap` — remains open (BR-D18, S2-T3).** | `bootstrap/oidc-setup.tf:29-36` vs `global-bootstrap/main.tf:81-83` | ST-T1, S2 |
| **F41** | **Critical** *(cross-repo — not fixable here)* | **F1 exists in `global-bootstrap` too, four times over.** Every project workload policy in `project_policies.tf` grants `iam:CreateRole`, `iam:PutRolePolicy`, `iam:AttachRolePolicy`, `iam:DetachRolePolicy` and `iam:PassRole` on `Resource = "*"` — `bounty_infra_policy`, `tri_loop_policy` (which also holds `ecs:*` and `rds:*`), ~~`bedrock_rag_policy`~~, `resume_optimizer_policy`. Each is the same escalation-to-account-admin as F1, at organization scope. Fixing F1 in this repo alone leaves it standing for four pipelines. **⚠️ STILL OPEN — now three policies, not four (updated 2026-08-07 by ST-T5).** `ST-T2′` deleted `bedrock_rag_policy` (`glunk-works/global-bootstrap#5`), which removed **one instance** and changed nothing about the pattern. **Severity is unchanged: do not read this as reduced because this repo stopped being one of its instances.** ✅ **FILED as `glunk-works/global-bootstrap#6`** (2026-08-06, open) carrying the five-point corrected construction — see § 9.4. It also binds **S2-T0**, which re-adds this project's entry *with* the boundary; re-adding it without one reopens F41 as a fourth instance. | `global-bootstrap/project_policies.tf` | file upstream (§ 9.4 — `#6`, OPEN) |
| **F42** | High | **The org role's policy does not match this repo's workload — and after the transfer it becomes reachable.** `bedrock_rag_policy` grants `lambda:*`, `apigateway:*`, `bedrock:InvokeModel[WithResponseStream]` — the permission set of a Lambda + API Gateway application. This repo provisions S3 buckets, an OpenSearch Serverless collection and three policies, and a Bedrock **Knowledge Base** (`bedrock:CreateKnowledgeBase`, not `InvokeModel`). Nothing in it grants `s3:CreateBucket`, `aoss:*`, or `bedrock:CreateKnowledgeBase`. If CI assumes `github-actions-bedrock-serverless-rag`, apply cannot succeed. ~~**Must be corrected upstream BEFORE the transfer (F45).**~~ **⚠️ STILL OPEN, and the reason it is open is easy to misread. Updated 2026-08-07 by ST-T5.** The specific policy this row cites — `bedrock_rag_policy` — **no longer exists**: `ST-T2′` deleted it (`glunk-works/global-bootstrap#5`) rather than correcting it, so this finding's own evidence is gone while the finding is **not** closed. **F42 is a statement about a pattern, not about one policy:** `global-bootstrap` generates a workload policy per project and nothing checks that any of them describes the workload it is attached to. Three remain (`bounty_infra_policy`, `tri_loop_policy`, `resume_optimizer_policy`) and none has been audited against its repo. **Do not mark this done because this project stopped being an instance of it** — that is the deletion-looks-like-a-fix error, and it is the same error the F45 row warns about one line up. Tracked upstream at `glunk-works/global-bootstrap#6`; **it also binds S2-T0**, which re-creates this project's entry and must derive its verb list from `MW`'s recorded dry run rather than from prose. | ~~`global-bootstrap/project_policies.tf:144-168`~~ *(deleted)*; the pattern, in the three surviving project policies | ~~ST-T2~~ **upstream (§ 9.4)**; binds S2-T0 |
| **F43** | Medium | **Two state backends where the org pattern has one.** global-bootstrap owns `glunk-works-tofu-state-00042` + `global-tofu-lock` with genuine per-project isolation (`s3:prefix` conditions and `key = <project>/terraform.tfstate`). This repo runs its own `personal-bedrock-lab-state` + `bedrock-lab-state-locks`, outside that model — two backends, two lock tables, two sets of controls to harden. **RESOLVED: the org backend wins (BR-D17); this repo's backend is retired and its state migrated under the `bedrock-serverless-rag/` prefix.** | `bootstrap/state-backend.tf`, `environments/ai-lab/backend.tf` | S2 |
| **F44** | High | **The org scaffolding for this project is inert, because of the owner name.** `var.projects` builds the trust subject as `repo:${var.github_organization}/${repo_name}:…`, and global-bootstrap's README documents `github_organization=glunk-works` — but this repo is `Seuss27/bedrock-serverless-rag`. So `github-actions-bedrock-serverless-rag` **cannot be assumed from here at all**. The entry also sets no `plan_role = true` and no `extra_oidc_subjects`, so **S2-T3's read-only plan role and S1-T5's `environment:production` subject are both changes to `global-bootstrap`, not to this repo.** **RESOLVED 2026-08-05: the repo transfers to `glunk-works` (BR-D13), which makes the org role match — see F45 for what that silently switches on.** **✅ CLOSED 2026-08-07 by ST, by deleting the inert scaffolding rather than by activating it** — `glunk-works/global-bootstrap#5` (merged 2026-08-06T15:42Z, human-applied before the transfer) removed the `bedrock-serverless-rag` entry from `var.projects` along with `bedrock_rag_policy`, and `aws iam get-role --role-name github-actions-bedrock-serverless-rag` returns **`NoSuchEntity`** against live AWS. **⚠️ But this finding's premise was right and INCOMPLETE, and the incomplete half is what cost a CI outage.** F44 says the entry is inert *because the owner name is wrong*, implying the transfer alone would activate it. It would not have: an **org-owned** repository presents an **ID-qualified** OIDC subject — `repo:<owner>@<org_id>/<repo>@<repo_id>:<context>` — while `global-bootstrap` builds subjects from `github_organization` + `repo_name`, i.e. the **plain** form, which does not match. So the upstream role would have stayed inert *after* the transfer too, for a second, independent reason nobody had written down. Measured from CloudTrail in ST-T3 (see **F2**); it is the reason the transfer broke authentication on **this repo's own** role, and it is a live trap for **S2-T0**, which re-creates the upstream entry. | `global-bootstrap/variables.tf:43-53` | ST *(closed)*; the subject-form trap → **S2-T0/S2-T2** |

### 3.1c Consequences of the two answers given 2026-08-05

The operator confirmed **(1) one shared AWS account** and **(2) the repo transfers to
`glunk-works`**. Each answer creates a finding the other does not.

| ID | Sev | Finding | Where | Sprint |
| --- | --- | --- | --- | --- |
| **F45** | **Critical** *(raised from High 2026-08-05, BR-D24)* | **✅ CLOSED 2026-08-07 by ST — BY REMOVAL, NOT BY CORRECTION. Read the mechanism before building on this.** The dormant role was **deleted upstream**, not given a permissions boundary: `glunk-works/global-bootstrap#5` (merged 2026-08-06T15:42Z, human-applied **before** the transfer, per the sprint's one hard ordering constraint) dropped the `bedrock-serverless-rag` entry from `var.projects`, `aws_iam_policy.bedrock_rag_policy` and its attachment; `aws iam get-role --role-name github-actions-bedrock-serverless-rag` returns **`NoSuchEntity`** against live AWS, re-confirmed after the transfer. **So there is no boundary, no role path scope and no findings `Deny` for this project — there is nothing for them to be attached to.** A reader who sees "F45 closed" and assumes the construction in ST Task 2b was built will be building on a control that was never built; **S2-T0 is where it gets built**, and Task 2b is normative there. What this does *not* close: **F41 and F42 survive org-wide** — deleting one project's entry is not fixing the pattern (upstream issue `glunk-works/global-bootstrap#6`). **The generalisable lesson, recorded because it applies far beyond this row:** when a finding is *"a thing that will become dangerous"*, check whether the thing is needed **yet** before designing its control — the original plan gated an irreversible repository transfer on its own hardest task, which is the schedule that produces a boundary weakened under unblock pressure. The original finding follows. **The transfer silently activates a dormant, over-privileged, wrong-workload role.** **Why Critical:** every other Critical here has a diff a human could catch. This one's trigger is an org owner clicking *Transfer* — **no IaC change, no PR, no review surface anywhere** — and it is the one Critical this plan intends to *create*, on a sprint scheduled second. Today `github-actions-bedrock-serverless-rag` cannot be assumed from `Seuss27/…` (F44). The moment the repo becomes `glunk-works/bedrock-serverless-rag`, its trust subject `repo:glunk-works/bedrock-serverless-rag:ref:refs/heads/main` **matches** — and that role carries `lambda:*`, `apigateway:*` (F42) **and** `iam:CreateRole`/`PutRolePolicy`/`AttachRolePolicy`/`PassRole` on `Resource = "*"` (F41). So a repository-settings change, with no IaC diff anywhere, creates a **new escalation path into the shared account**. The upstream fix must land **before** the transfer, not after. | `global-bootstrap/project_policies.tf` + the transfer | **ST-T2, blocking ST-T3** |
| **F46** | Medium | **The retry loop reports an authorization failure as a propagation delay, and the most recent commit made it worse.** `create_index.py` retries any `Exception` six times; run `26788807269` shows six consecutive `AuthorizationException(403, '')` — a condition that can never resolve by waiting, because it is F5, not IAM eventual consistency. Commit `0aa56dc` raised the delay to 45 s, so CI now spends **~12 minutes** failing at it. The most recent work on this repo was tuning the wrong variable. | `environments/ai-lab/create_index.py:71-93` | **MW-T3** |
| **F48** | **High** *(found 2026-08-05 while applying the F40 stopgap; severity SURVIVES BR-D20 — see below)* | **`bootstrap/`'s OpenTofu state is a local, gitignored file on one workstation.** `bootstrap/` declares **no `backend` block** — despite `state-backend.tf` creating a state bucket *for the other root*. So `bootstrap/terraform.tfstate` (plus `.backup` and a `terraform.tfvars`) lives only in the working tree, unversioned and unbacked-up, and it is the state describing the **org-shared OIDC provider**, the CI deploy role, and the state backend itself. Three consequences: **(a)** losing that laptop makes the highest-consequence root in the org unmanaged; **(b)** `prevent_destroy` (F40's stopgap) **only works while that file exists** — no state, no tracked resource, no guard; **(c)** re-applying from an empty state would try to *create* the provider and fail `EntityAlreadyExists`, reproducing F39's split brain in the one root where it hurts most. Superseded rather than fixed by BR-D17/BR-D18: `bootstrap/` is retired and its resources move to `global-bootstrap`, whose state *is* remote and locked. Until then, **back the file up out-of-band.** **BR-D20 does not downgrade this**: the state file is disposable in respect of *this repo's* resources, but it is the only record of the **org-shared OIDC provider**, whose loss is an organization-wide outage. That single resource is what makes an otherwise-disposable file matter — and moving it upstream (BR-D18) is what makes the rest of `bootstrap/` freely destroyable, as the design intends. **⚠ The exposure window is ST, not S2** *(added 2026-08-05)*: F48's remedy is assigned to S2-T3/S2-T4, but **ST runs first and mandates three human applies against exactly this file** — ST-T0's drift reconciliation, and ST-T3's trust-policy widen and narrow — on a repository mid-transfer between owners. An interrupted apply drops the OIDC provider from state, `prevent_destroy` evaporates with it (it is a plan-time guard over a state entry, not a property of the AWS resource), and recovery per (c) is a hand-written state file, executed against a repo whose OIDC trust subjects are themselves in flux. **F48's own mitigation is therefore promoted to a blocking ST-T0 acceptance criterion** — back the file up out-of-band before the sprint's first apply, and again immediately before ST-T3's narrow. **✅ THE BACKUP WAS TAKEN — confirmed by the operator 2026-08-07, and recorded only then.** The **location is deliberately not written here** (public repo, BR-D4). ⚠️ **Two sub-properties of the criterion are operator-attested but were not independently verified at the time and are NOT recorded as proven: that the copy is *restorable*, and that it was re-taken immediately before the narrow.** An unverified backup is the ordinary failure mode of backups, so before **S2-T3/T4**'s applies — which include `tofu state rm` against the org-shared OIDC provider — **restore it to a scratch path and confirm it parses and lists the provider. Tracked as #37**, deliberately as an issue rather than only a sprint-plan bullet, for the reason in the process finding below. *(The finding itself stays OPEN: the backup is a mitigation, not the fix. The fix is BR-D18 — ownership moves upstream and `bootstrap/` stops being the only record of anything.)* **📌 Process finding, worth more than the task:** for ~24 hours this criterion was indistinguishable from one that had been **skipped** — the roadmap said "still outstanding", no PR body mentioned it, and the ST completion review had to ask a human. **A blocking criterion whose only evidence is someone's memory has already failed**, because the next reader cannot tell it from a miss. Criteria that gate an irreversible act must record their satisfaction *in the PR that relies on them*. | `bootstrap/` (no `backend` block) | **ST-T0** (backup ✅ taken, restore-test → S2), S2-T3, S2-T4 |
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
| **F55** | **High** *(severity SURVIVES the 2026-08-07 measurement — see below)* | **🔄 STILL OPEN AND STILL HIGH, but its RATIONALE changed and its verb list was INCOMPLETE — corrected 2026-08-07 by `MW`'s plan review.** *(a)* **The gap list was stale, not merely "indicative".** Four more gaps were found against the declared resources: **`budgets:*`** (the role holds no `budgets:` verb at all — `environments/ai-lab/budget.tf` landed with **S0-T8 on 2026-08-06**, *after* this finding was written, and nobody re-derived it), **`aoss:APIAccessAll`** (without which **`MW`'s data-plane task does not close F5** — AOSS needs *both* a data-access-policy principal *and* an IAM `APIAccessAll` grant), **`bedrock:Get*`** (create waiters poll it), and **the entire destroy path** — every verb list here and in the sprint plans was derived from a *create* path while the acceptance test is `destroy → apply → verify`. *(b)* **The "teardown runs first" framing is spent.** There is nothing to tear down: AWS holds one policy-less role and the state is empty (see **F39**). The finding survives at High because the identity is still not sufficient and **every gap discovered by watching CI fail costs a PR plus a human `bootstrap/` apply against the unbacked-up state file F48 and #37 are about** — cost and F48 exposure, not irreversibility. *(c)* **The live inline policy matches the committed HCL exactly** (verified 2026-08-07), so unlike **F50** there is no hidden drift and the committed file is a trustworthy starting point. The original text follows. ~~**The deploy identity is not provably sufficient for a from-scratch apply, and the teardown that needs it runs first.**~~ `state_access_policy` grants `aoss:Create/DeleteSecurityPolicy`, `aoss:CreateCollection`, `bedrock:CreateKnowledgeBase`, `bedrock:CreateDataSource` — and nothing else in those families. The module declares at least four things it cannot then create or refresh: `aws_opensearchserverless_access_policy` (needs `aoss:*AccessPolicy`), the KB's `roleArn` (needs `iam:PassRole`), `aws_s3_bucket_server_side_encryption_configuration` (needs `s3:*EncryptionConfiguration` — `s3:PutBucket*` matches neither verb), and `aws_s3_bucket` refresh (needs `s3:GetBucketVersioning`/`GetBucketLocation`/`GetBucketTagging`). **These have never been exercised** because run `26788807269` died at `EntityAlreadyExists` *before AOSS or Bedrock were reached*, so they become visible exactly once, at the worst moment: after the teardown has deleted the working-but-orphaned system and before the replacement identity exists. **The verb list above is indicative and must be regenerated from a real dry run, not copied from here.** **🔄 RE-HOMED to `MW` and RE-POINTED by ST's 2026-08-06 reshape — written into `sprints/MW_make_it_work/sprint_plan.md` as its blocking Task 0, and confirmed present there 2026-08-07 (ST-T5).** The identity in question is no longer the upstream role: `ST-T2′` deleted it, so `MW` rebuilds under **this repo's own `github-actions-deploy-role`** and sufficiency targets `aws_iam_role_policy.state_access_policy` in `bootstrap/state-backend.tf` — a file in this repository, fixable by a normal PR plus a human apply. That makes the recovery path *open*, which shrinks the trap but **not the gate**: all four gaps re-verified present 2026-08-06 (no `aoss:*AccessPolicy`, no `iam:PassRole`, no `s3:GetBucket*`, no `s3:PutEncryptionConfiguration`). | `bootstrap/state-backend.tf:82-111` vs `modules/aws-bedrock-rag/` | **MW-T5** |
| **F56** | **High** | **The upstream read-only plan role is unusable by this repo, in two independent ways.** *(a)* `plan_roles.tf` trusts **only** `repo:<org>/<repo>:pull_request` via `StringEquals`, with no `extra_oidc_subjects` mechanism — so any job triggered `on: push` to `main` can never assume it. *(b)* `plan_role = true` generates the role and its **state**-read policy, but the **workload** read policy upstream is `aws_iam_policy.bounty_infra_plan_policy` — hardcoded, not `for_each`ed — so this project's plan role would hold state-read and nothing else, and every PR plan would `403` on refresh. **The dangerous part is the unblock, not the breakage:** the natural fix for (a) is to point the plan job at the apply role, which is F13 restored in the same change that closes it. **🔄 RE-HOMED to S2 by ST's 2026-08-06 reshape — written into `sprints/S2_identity_least_privilege/sprint_plan.md` as blocking Task 0 (step 3), and confirmed present there 2026-08-07 (ST-T5).** It **does not arise while no plan role exists**: `ST-T2′` deleted the whole project entry, and `plan_role = true` is set again only by S2-T0 — so this finding is dormant, not fixed, and it re-arms in the same change that re-creates the role. ⚠️ S1 therefore keeps its `AWS_PLAN_ROLE_ARN` fallback one sprint longer than the original plan assumed. | `global-bootstrap/plan_roles.tf`, `project_policies.tf` | **S2-T0**; S1-T5 |
| **F57** | **High** | **The KB execution role receives neither `path` nor `permissions_boundary`, so the boundary ST-T2 installs denies its creation.** `aws_iam_role.bedrock_kb_role` declares `name = "personal-bedrock-kb-execution-role"` and nothing else. Once the upstream `iam:PermissionsBoundary` condition and `role/bedrock-rag/*` Resource scope are live, CI's `CreateRole` for it is denied twice over — wrong path, no boundary. **The failure lands at S2-T2's *verify* step, when the escalation-capable local role has not yet been deleted and the cheapest unblock is to drop the boundary condition upstream** — silently reverting the whole construction and reopening F41. The module change must land **before** the upstream condition, and the two live in different repositories. **🔄 SPLIT by ST's 2026-08-06 reshape — half closed, half re-homed, and the split is the finding's whole current state (recorded 2026-08-07 by ST-T5).** ✅ **`path` half CLOSED in `ST-T2a′`**: `aws_iam_role.bedrock_kb_role` — the module's only role — declares `path = "/bedrock-rag/"`, landed *before* `MW` so the rebuild creates it at the right path and the role is not replaced twice (free under BR-D20, but a knowingly wasted cycle is worth not spending). 🔄 **`permissions_boundary` half → S2-T0**, written into `sprints/S2_identity_least_privilege/sprint_plan.md` and confirmed present there. **Its absence in `modules/` today is not a defect** — the argument would have to reference a boundary policy that does not exist until S2-T0 writes it, and setting it early yields either an empty string (silently no boundary, which reads as protected — worse than none) or a broken apply. **The ordering hazard this row was written about is GONE:** `ST-T2′` deleted the upstream `iam:PermissionsBoundary` condition along with the policy, so there is no cross-repository race left; S2-T0 writes the condition and the boundary, and this repo threads the argument, with no irreversible act waiting on either. | `modules/aws-bedrock-rag/iam.tf:21-23` | `path` ✅ **ST-T2a′**; boundary → **S2-T0** |
| **F58** | Medium | **`DenyBountyFindingsDataAccess` is `s3:`-only, and is attached to one project's plan role rather than all of them.** Two gaps in the control that exists specifically to protect asset #1. *(a)* The Deny names `s3:*` on the findings bucket; it does not name `kms:`, so it does not constrain `kms:ScheduleKeyDeletion` or `kms:PutKeyPolicy` against the key that encrypts it — see § 2.2, the asset is two resources. *(b)* `bounty_infra_plan_policy` and its attachment are not `for_each`ed, so the plan role ~~ST-T2~~ **S2-T0** creates for this project would carry **no findings Deny at all**, despite § 9.4 describing the Deny as applying to "the plan roles" plural. **🔄 RE-HOMED to S2 by ST's 2026-08-06 reshape — written into `sprints/S2_identity_least_privilege/sprint_plan.md` as blocking Task 0 (step 4), whose normative spec is ST Task 2b(6), and confirmed present there 2026-08-07 (ST-T5).** Gap *(b)* is dormant for the same reason as F56 — no plan role exists for this project after `ST-T2′` — but **gap *(a)*, the `s3:`-only Deny, is live right now on `bounty_infra_plan_policy` and is not this repo's to fix**; it belongs with the upstream issue. ⚠️ **Write the `kms:` extension when the Deny is written, not when KMS verbs are first granted.** BR-D23 cut S3-T4's customer-managed key, so the immediate trigger is gone — the asymmetry between a bucket and the key encrypting it (§ 2.2, asset #1) is not. | `global-bootstrap/project_policies.tf` | **S2-T0** *(gap b)*; upstream § 9.4 *(gap a)* |

### 3.2 Pipeline

| ID | Sev | Finding | Where | Sprint |
| --- | --- | --- | --- | --- |
| **F51** | **High** *(created by the 2026-08-05 scope correction)* | **The project does not do the thing it was designed to do.** Its stated purpose is to be stood up and torn down on demand (BR-D20) — yet **no `tofu apply` has ever completed successfully** (every push-to-`main` run is `failure` or `cancelled`), and a full `destroy` → `apply` → verify cycle has never been demonstrated. At least four defects sit on that path: the AOSS data-access policy grants a human SSO session rather than the CI role (**F5**), the index bootstrap then fails `403` and retries for ~12 minutes (**F46**), the state is orphaned so apply collides with `EntityAlreadyExists` (**F39**), and `prevent_destroy` on the shared OIDC provider now blocks `tofu destroy` of `bootstrap/` outright until ownership moves upstream (**BR-D18**). Each was recorded separately as a security or correctness defect; together they are a **functional** one. **A clean create/destroy/create cycle is the acceptance test for S2 (BR-D20)** and the cheapest possible route to closing F39, F5 and F46 at once. | whole-system | **MW** |
| **F17** | **Critical** | **✅ CLOSED 2026-08-06 by S0-T1**, and re-verified under the new owner by ST-T4 (`protected-integration-branches`, four rule types, `bypass_actors: []`, `pr-title` required). *(The evidence below is the original finding and is retained as historical record — the `Seuss27/` path in it is deliberate and must not be "corrected".)* **No branch-protection ruleset exists.** `gh api repos/Seuss27/bedrock-serverless-rag/rulesets` returns `[]`. `main` accepts a direct push, no check is required, and every gate in `.github/workflows/` is therefore advisory. This is the multiplier on F13 and F1. | GitHub settings | S0-T1 |
| **F13** | **High** *(lowered from Critical 2026-08-05, BR-D24)* | `tofu apply -auto-approve` runs on every push to `main` with **no `environment:`, no approval, no plan artifact**. With F17 and F1, one push is unreviewed admin-capable execution. **Why lowered — double-counting, and nothing else.** The escalation it enables is F1's (Critical) and the absent protection is F17's (Critical); strip both and what remains is "an unreviewed apply reaches AWS on merge" — a BR-D2 violation, genuinely High, but not an independent Critical. **Two arguments were explicitly rejected as rationale:** that no push-to-`main` run has ever succeeded, and that the workflow is `paths:`-filtered. Both are artifacts *this plan deletes* — `MW` is precisely what makes auto-apply start working, and the `paths:` filter comes off in the change that makes a job required. Recorded as rationale they would be false the day `MW` lands. | `.github/workflows/deploy-ai-lab.yml:101-103` *(was `:96-98`; shifted by PR #21's Dependabot bump `597d597` — re-verified 2026-08-07)* | S1-T5 |
| **F14** | High | The apply job **re-plans** rather than applying a saved plan file, so what applies is not what was reviewed. Adding an approval without fixing this buys a signature on a different change. | same | S1-T5 |
| **F15** | High | **No action is SHA-pinned.** `aws-actions/configure-aws-credentials@v4` receives the OIDC claim on a mutable tag — moving that tag is a credential handoff. | `.github/workflows/deploy-ai-lab.yml` | S1-T1 |
| **F16** | Medium | `tofu plan -no-color` dumps the full plan into a **world-readable log on a public repo**, rendering the account id, bucket names, role ARNs, and the collection endpoint (BR-D4). | same, `:94` | **S1-T4** |
| **F18** | Medium | The workflow carries a **`paths:` filter** and **`name:` overrides on both jobs**. A required check on a path-filtered workflow deadlocks (a docs-only PR leaves it pending forever); a `name:` override renames the check run and silently un-requires the gate. Both must be gone *before* any job here is required. | same, `:6,9` (`paths:`) and `:17,56` (`name:`) | S1-T2 |
| **F19** | Medium | Scanner coverage gap: Checkov runs against `modules/` **only** — `bootstrap/`, where F1 and F2 live, is never scanned. There is no tflint, no secrets scan, no dependency audit, and no workflow-security scan. *(The SBOM was cut by BR-D23 — no consumer, no distributable — so its absence is no longer a gap.)* | same, `:41-46` | **S1-T3** |
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
| **F49** | Low *(demonstrated 2026-08-05)* | **`bootstrap/` cannot be run by following the README.** `bootstrap/providers.tf` declares only `region` — no `profile` — so the AWS provider falls through to the default credential chain and dies on IMDS unless `AWS_PROFILE` is exported first. The README's Step 2 says `aws sso login --profile admin-sso` but never says to export it, and `$env:AWS_PROFILE` does not survive a new shell. The sibling `glunk-works/global-bootstrap` gets this right (`profile = var.aws_profile`, default `admin-sso`). **The local workaround made it worse, not better — and has now been removed.** `AWS_PROFILE` was set in the untracked `.env` and sourced by `Invoke-Tofu.ps1`, a **gitignored** helper: the one thing making local development work existed on a single machine, invisible to review, to CI, and to any reproducible environment. **✅ The wrapper was deleted 2026-08-05** at the operator's direction, in favour of native `tofu` plus `TF_VAR_*`/`AWS_PROFILE` environment variables — which is what OpenTofu and the AWS SDK provide anyway, so the wrapper was never buying a capability, only hiding a setup step. `.gitignore`'s entry for it went with it, and `CLAUDE.md` § Commands now documents the native invocation. **Note what this did and did not fix.** It closed the *unshippable-file* half — nothing load-bearing is now invisible to review — and it removed a sanctioned subprocess surface that `.claude/settings.json`'s deny list did not cover (advisory `[M2]` § 3, closed by deletion rather than by a new deny rule, which is the better outcome). **It did not close the finding**: `bootstrap/providers.tf` still declares no `profile`, so `AWS_PROFILE` must still be exported and `$env:AWS_PROFILE` still does not survive a new shell. The wrapper was papering over that, so removing it makes the gap *more* visible, not smaller — which is the point. The sibling `glunk-works/global-bootstrap` gets it right (`profile = var.aws_profile`, default `admin-sso`); **this repo deliberately does not copy that, because `bootstrap/` is being retired rather than hardened (BR-D17) and a new variable there is work against a directory scheduled for deletion.** So the durable fix is documentation: the README and the break-glass runbook must state the export. Minor in normal use; **material in a break-glass**, which is exactly when nobody wants to debug a credential chain. | `bootstrap/providers.tf:10-12`, `README.md` | S6-T1, S6-T2 |
| **F12** | Low | Provider constraint split: `~> 5.0` in `environments/ai-lab`, `~> 6.0` in `bootstrap`. *(Corrected 2026-08-07: the backend's `dynamodb_table` is superseded by OpenTofu **core**'s native S3 locking, `use_lockfile` — an OpenTofu-CLI-version feature (≥1.10), not an `aws` **provider**-version one; the original wording conflated the two. This repo's own table is retired by the BR-D22 re-amendment, `environments/ai-lab/providers.tf`'s `required_version` bumped to `>= 1.10.0` alongside it — closed early, ahead of S3-T7.)* The provider constraint split itself remains open. | `providers.tf` ×2, `backend.tf` | S3-T7 |

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
| **F54** | Medium *(near-miss, 2026-08-05)* | **`.gitignore` covers `.env` but no `.env.*` variant.** `.env.local`, `.env.bak`, `.env.prod`, `.env.save` and every per-directory equivalent are all **committable** — verified with `git check-ignore`. Found the hard way: cleaning F52 created a `.env.bak-preinfisical` backup that was immediately committable and held the (by then revoked) Infisical secret. The backup was deleted, nothing was committed, and the credential was already dead — but the gap is real and the trigger is mundane, since making a `.env` backup before editing it is exactly what a careful person does. Fix: `.env` → `.env*` plus `!.env.example`, and let S1-T3's `secrets-scan` job be the backstop rather than the only line. **✅ CLOSED 2026-08-05, early.** The one-line fix landed ahead of S0 because it costs nothing and the gap was live across the whole of S0 otherwise. Verified per-path with `git check-ignore` — **once per path, not once for all of them**: that command exits 0 if *any* argument is ignored, so a single multi-path invocation cannot prove "both" and would have reported success against a rule that covered only the first. `.env`, `.env.local`, `.env.bak`, `.env.prod` and `environments/ai-lab/.env` are ignored; `.env.example` is still trackable. **`tfplan`, `plan.json` and `.venv/` were added in the same change** — S1-T4 creates the first two by those exact names and a saved plan renders every value BR-D4 forbids on a public repo, while `venv/` does **not** match `.venv/` (that directory is ignored today only because `python -m venv` writes its own `.gitignore` inside it). | `.gitignore` | **done** |
| **F52** | **High** *(found 2026-08-05)* | **A live Infisical machine-identity credential sits in plaintext on disk.** `environments/ai-lab/.env` holds `INFISICAL_CLIENT_ID`, a 64-hex-char `INFISICAL_CLIENT_SECRET`, and a workspace id. **Verified NOT disclosed**: the file is untracked, matched by `.gitignore:10`, and neither the path nor the secret value appears anywhere in `git log --all --full-history` — so it never reached the public repo. It is still a credential for a system this project is leaving (BR-D21), which makes it pure liability: **it must be REVOKED in Infisical, not merely deleted from disk.** Deleting the file removes the copy, not the credential. **✅ CLOSED 2026-08-05: the machine identity was revoked by the operator, and the three `INFISICAL_*` keys were stripped from `.env` (the other keys — bucket name, region, `AWS_PROFILE` — were preserved).** | `environments/ai-lab/.env` (untracked) | **done** |
| **F53** | Medium *(found 2026-08-05)* | **HALF CLOSED.** ✅ **The deletion half landed in S0-T7** (PR #20, 2026-08-06): the provider block, the `infisical_secrets` data source, the Cloudflare provider it fed and `var.infisical_workspace_id` are **gone, not commented out** — `grep -rni infisical` over `modules/`, `environments/`, `bootstrap/` and `.github/` returns nothing. ⚠️ **The README half is still OPEN, but it is SMALLER than this row claimed** *(corrected 2026-08-07, same day it was written — the first draft asserted the README "names Infisical a prerequisite and tells the reader to provision the exact machine identity F52 says to revoke," which was the finding's **2026-08-05** state and not its state today)*. **S0-T7 (PR #20, `9456278`) already deleted the actionable lines** — the Infisical prerequisite and the `INFISICAL_CLIENT_ID`/`_SECRET` entries in the `.env` block are **gone**; live `README.md`'s prerequisites are OpenTofu, AWS CLI v2, Python 3.x and SSO, and its `.env` block holds one variable. What remains is **three lines of stale *description*** — `README.md:5` ("dynamically injects secrets via Infisical"), `:13` ("Secrets Management: Infisical & .env") and `:26` ("AWS & Infisical provider initialization"). Still wrong, still worth fixing, but it **describes** an integration that no longer exists rather than **instructing** anyone to create a credential. Tracked as **#8**, fixed in **S6-T1**. The original finding follows. **Dead Infisical scaffolding, and a README that actively instructs the reader to use it.** The provider block, the `infisical_secrets` data source, the Cloudflare provider it fed, and `var.infisical_workspace_id` are all present but **commented out** (PR #13 disabled rather than removed them). Meanwhile `README.md` still lists Infisical as the secrets manager, names it a prerequisite, and tells the reader to create a `.env` with `INFISICAL_CLIENT_ID` / `INFISICAL_CLIENT_SECRET` — i.e. the documentation instructs a newcomer to provision exactly the credential F52 says to revoke. Commented-out code that contradicts live docs is worse than either alone. | `environments/ai-lab/providers.tf:10-38`, `variables.tf:7-10`, `README.md:5,13,26,37,44-48` | **S0-T7** (deletion), S6-T1 (README) |
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

**Closed, as of 2026-08-07** — stated as a list rather than a count, because a bare count goes
stale silently and this line already did once *(it read "Two are closed" through the whole of
S0 and ST)*. **Fully closed (6):** **F17** (S0-T1), **F44**, **F45**, **F50** (all ST),
**F52**, **F54**. **Half closed (3), and each half matters:** **F40** — stopgap `prevent_destroy`
merged and verified, ownership still here until S2-T3 (BR-D18); **F53** — Infisical deleted in
S0, the README's three stale **descriptive** lines open until S6-T1 *(not an instruction to
provision anything — S0-T7 deleted those; see the row)*; **F57** — `path` landed in
`ST-T2a′`, `permissions_boundary` at S2-T0. **Two Criticals of the original five are closed
(F17, F45); three remain — F1, F41, F47** — and **F45's closure is by removal, not by
correction, so it built no control** (read its row before assuming otherwise). F45 and F47 were
raised and F13 lowered on 2026-08-05 under the multiplier rule (BR-D24, stated at the head of
this section). Four findings were added by the cold-context plan review
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
| **BR-D13** | **✅ EXECUTED 2026-08-06/07 (UTC) — the repo now lives at `glunk-works/bedrock-serverless-rag`.** *(Resolved 2026-08-05; executed by **ST-T3**; recorded here by ST-T5.)* Performed with the mandatory **widen → transfer → narrow** discipline, all three steps in one working session as the sprint required: PR **#29** widened the trust policy to accept both owners (merged 2026-08-06T23:33Z), a human performed the transfer in the GitHub UI, and PR **#30** narrowed it back to a single subject (merged 2026-08-07T00:43Z). The narrow was blocking, not trailing, and the reason is that **GitHub usernames are reclaimable**: leaving the old-owner glob standing leaves a dangling-subject trust policy on a role holding `iam:CreateRole` on `*` in the shared account. Verified against **live AWS**, not the HCL: the trust policy is the single subject `repo:glunk-works@<org_id>/bedrock-serverless-rag@<repo_id>:*`, zero `Seuss27` occurrences, and both a `push`- and a `pull_request`-context run authenticated afterwards. **⚠️ The transfer broke CI authentication, for a reason in no plan — and it is the most transferable thing ST learned.** An **org-owned** repository presents an **ID-qualified** OIDC subject, `repo:<owner>@<org_id>/<repo>@<repo_id>:<context>`, which a plain `repo:<owner>/<repo>:*` glob does **not** match. Measured from CloudTrail `AssumeRoleWithWebIdentity`, not inferred — and **do not trust `gh api .../actions/oidc/customization/sub`'s `use_immutable_subject: false`**, which contradicts observed behaviour; read `sub_claim_prefix` and confirm against CloudTrail. This binds **S2-T2** (enumerating the plain form under `StringEquals` reproduces the outage, in the task that also deletes the fallback role) and **S2-T0** (`global-bootstrap` builds the plain form, so adopting that role inherits the trap). The original rationale follows. This repo lives at `Seuss27/`, not `glunk-works/` — and `global-bootstrap` builds its trust subjects from `github_organization=glunk-works`, so the org role generated *for this project* cannot be assumed from here (**F44**). The owner name is not cosmetic; it is inside every OIDC subject. The `pr_base: main` deviation from the conventions' `develop` is separate, deliberate, and matches both sibling repos — that half stays a S6 confirmation. |
| **BR-D17** | **RESOLVED 2026-08-05 — `global-bootstrap` owns identity and state; this repo owns its workload and nothing else.** The ownership boundary had to be stated before S2 designed a single policy. Exactly one of them owns the GitHub OIDC provider, the CI roles, and the state backend. Today both repos declare overlapping claims on all three (**F40**, **F43**, **F44**) and the account-level truth is unverified. The sibling precedent is unambiguous — bounty-infra's `CLAUDE.md` records that `global-bootstrap` owns "**every GitHub OIDC role**," and that a new workflow trigger generally needs a *new* role from there rather than a widened one locally. Adopting that here is the default; departing from it needs a written reason. Adopted because the operator confirmed the transfer (BR-D13) and one shared account, which makes the sibling precedent both coherent and cheaper than maintaining a second identity plane. **Consequence: this repo's `bootstrap/` is retired, not hardened** — its OIDC provider, deploy role, state bucket and lock table all move or are deleted. S2 is re-scoped accordingly. |
| **BR-D18** | **The GitHub OIDC provider moves to `global-bootstrap`'s ownership.** *(Rationale strengthened by BR-D20: the `prevent_destroy` guard now correctly blocks `tofu destroy` of this repo's entire `bootstrap/` root, which directly conflicts with the project's spin-up/tear-down design. Moving the provider upstream is what makes this repo **freely destroyable** — it is now an enabler of ephemerality, not just a safety fix.)* One account holds one provider per URL; today this repo *creates* it and `global-bootstrap` *reads* it as a `data` source, which inverts the dependency — the org's foundation depends on a lab repo's state (F40). End state: `global-bootstrap` declares it as a `resource` and imports the existing one; this repo drops its declaration entirely. Until that lands, `prevent_destroy` on this repo's copy is the stopgap (ST-T1). |
| **BR-D19** | ~~State is reconciled by import, never by recreate.~~ **REVERSED 2026-08-05 (BR-D20): state is reconciled by TEARDOWN AND REBUILD.** The original rule protected embeddings and source documents. There are none — the corpus is empty and the collection holds nothing. Writing `import` blocks for every drifted resource would be slower, riskier, and would freeze the current (bad) resource names into the configuration. Delete the orphaned resources, fix the IaC, and apply clean. The one exception is anything **shared with the organization** — the OIDC provider above all — which is never in scope for a teardown (BR-D18). |
| **BR-D20** | **Ephemerality is a design requirement, and the acceptance test.** This project exists to be stood up and torn down; nothing in the workload is precious and the corpus is empty. Two consequences that run in opposite directions and must both be honoured. **(1)** Breaking changes to the workload are free — prefer rebuilding correctly over migrating carefully, and never let a data-preservation caution shape a decision when there is no data. **(2)** A clean **`destroy` → `apply` → verify** cycle is therefore a *functional requirement*, not a convenience — and it is the acceptance test every infrastructure sprint must ultimately pass. Today the project fails it (**F51**). Precious-ness returns the day a real corpus is ingested; BR-D10 is what will already be in place when it does. |
| **BR-D21** | **Secrets come from AWS, not Infisical.** Aligning with the move already made under `603identity`. The concrete rule, in three tiers, because most of what this repo handles is *restricted* rather than *secret* and conflating them is how a secret store fills with non-secrets: **(1) Secrets** — anything whose disclosure is itself the harm: **AWS SSM Parameter Store `SecureString`**, `/bedrock-serverless-rag/<env>/<name>`, read at runtime via `data.aws_ssm_parameter`. Parameter Store rather than Secrets Manager **by default**: the standard tier is free where Secrets Manager bills per secret per month, and this is a cost-sensitive ephemeral lab (BR-D20). Secrets Manager only where native rotation or cross-account sharing is genuinely required — a decision to record, not a default. **(2) Restricted-but-not-secret** — account id, role ARNs, bucket names, the collection endpoint: GitHub Actions **variables** and tofu variables, never a secret store, and never a workflow log (BR-D4). **(3) Neither** — plain committed configuration. ~~**This repo currently holds no secrets at all** (`gh secret list` is empty; the only variables are `AWS_OIDC_ROLE_ARN` and `DATA_SOURCE_BUCKET_NAME`), so there is nothing to migrate — this decision sets the pattern *before* the first secret exists, which is the cheapest moment to set it.~~ **⚠️ Corrected 2026-08-07: the repo has held exactly one secret since S0-T8.** `gh secret list` returns **`BUDGET_NOTIFICATION_EMAIL`** (created 2026-08-06T12:05Z), consumed by `deploy-ai-lab.yml` as a `TF_VAR_`; it is an **email address, i.e. PII**, which is why it is a secret rather than a BR-D4 *restricted* variable. The variables half is still exactly right — only `AWS_OIDC_ROLE_ARN` and `DATA_SOURCE_BUCKET_NAME` exist. **What actually goes stale here is the pilot's framing, not the tiering rule.** "Set the pattern before the first secret exists" was true when written and expired the day S0-T8 created one — and the secret it created is a **GitHub Actions secret, not an SSM parameter**, i.e. the first real one landed *outside* the pattern this decision describes. That is not a violation (an Actions-consumed value has no SSM path that a workflow can read at job start), but it is the exception, and it should be recorded as one rather than discovered later as a contradiction. There is still nothing to *migrate*; there is now something to *reconcile*. **Confirmed 2026-08-05 as an ORG-LEVEL direction: this repo is the PILOT, and `bounty-infra` / `loop-orchestrator` follow as time permits.** That promotes S3-T8's deliverable from "clean up one repo" to "produce a pattern another repo can copy" — see § 9.5, including the reason a no-secrets pilot is a *weak* pilot and what S3-T8 does about it. |
| **BR-D14** | **No `architect-review` CI gate yet.** A fresh-session review gate is worth nothing while the deterministic checks beside it do not block a merge (F17). `review.ci_gate` stays `null`; the critic pass is `/way-of-working:critic-gate`, run locally before the PR. Reconsider once S0–S2 have landed. |
| **BR-D15** | **The devcontainer is the reproducible local green gate.** Every tool in it is version-pinned and SHA256-verified, and its pins are kept **equal** to the corresponding CI job pins — a divergence between local and CI results is a defect in this repo, not a local quirk. Recorded by SD; the Python layer is added by S5-T5. |
| **BR-D16** | **The AOSS collection stays publicly reachable, and that is the default outcome — not a fallback.** *(Changed 2026-08-05 by BR-D23; was "reserved, allocated by S3-T1" pending a research task on VPC reachability.)* A VPC endpoint plus two subnets, a security group and a VPC-attached runner, to protect a vector store holding **nothing**, in a single-operator lab, is ceremony — and the original plan made it a hard dependency of a second task, propagating the cost into another sprint. The accepted risk: the collection's data plane is reachable from the internet with **SigV4 as the only control** (TB4). The compensating controls that carry it are the AOSS data-access policy (which names principals, not networks), the empty corpus (BR-D20), and the single-consumer posture (BR-D11). **Revisit the day BR-D11 is revisited** — a second consumer or the first non-public document — not before. |
| **BR-D22** | **State confidentiality comes from OpenTofu native client-side encryption. The DynamoDB lock table stays.** *(Decided 2026-08-05; amended the same day — see below.)* SSE-S3 on the state bucket protects the object at rest in S3 and nothing else; it does not protect a state file from anyone who can legitimately `s3:GetObject` it, which after ~~ST-T2~~ **S2-T0** includes **a plan role assumable from any pull request**. *(Corrected 2026-08-07: `ST-T2′` deleted this project's upstream entry, so the PR-assumable reader now arrives in **S2-T0** — the same sprint as S2-T4, which writes the encryption block. **That makes the ordering intra-sprint and therefore easier to get wrong, not easier to get right:** do not let Task 0 land far ahead of Task 4.)* Native client-side encryption (`terraform { encryption { … } }`, `aws_kms` key provider, OpenTofu ≥ 1.7) does. This is the control that makes the BR-D21 secrets pilot honest — see § 9.5. **Ownership splits, and does not follow BR-D17 cleanly:** BR-D17 assigns the state *backend* upstream, but **neither mechanism here is backend-side.** Native encryption is a **client-side** block in *every root that writes state*; `global-bootstrap` cannot enable it for this repo. So: upstream owns the key-provider choice (filed as an issue, § 9.4); **this repo owns the `encryption {}` block in both roots and the `required_version` floors**, folded into S2-T4. Note `bootstrap/providers.tf`'s `terraform {}` block declares **no `required_version` at all**, and `environments/ai-lab`'s `>= 1.8.0` already covers encryption, so no floor bump is needed there. ~~**AMENDED — `use_lockfile` is NOT adopted and the DynamoDB lock table is retained, managed as IaC.** The original draft retired the lock table in favour of S3-native locking. That was wrong: this repo's own `bedrock-lab-state-locks` retires under BR-D17/F43, but the table it then uses is the org's `global-tofu-lock`, **shared with `bounty-infra`, `tri-loop` and `resume-optimizer`**. Retiring it would force every consumer repo to raise its OpenTofu floor and rewrite its backend block in lockstep — a coordinated multi-repo migration, against shared infrastructure, for no risk reduction. `dynamodb_table` therefore **stays** in `environments/ai-lab/backend.tf`; S2-T4 repoints it at the org table rather than removing it. *(Open, non-blocking: Terraform deprecated `dynamodb_table` in 1.11 in favour of `use_lockfile`. Whether OpenTofu followed is **unverified** — check the changelog at S2-T4 rather than assuming either way. If it did, this buys a deprecation warning now and a migration later; it does not change the decision.)*~~ **RE-AMENDED 2026-08-07 (operator decision), and the "unverified" note above is now resolved: OpenTofu did follow Terraform's lead — `use_lockfile = true` on the S3 backend has been supported since OpenTofu 1.10 (confirmed against OpenTofu's own docs, not assumed), and this repo already runs 1.11.6. OpenTofu has stated no plans to deprecate `dynamodb_table` either — this move is a deliberate cost/complexity choice, not a forced migration.** The 2026-08-05 amendment's coordination argument was correct **for the org's shared `global-tofu-lock` table**, but conflated that with **this repo's own, still-separate `bedrock-lab-state-locks` table**, which today has exactly one consumer: this repo. Retiring *this* table needs no coordination with `bounty-infra`, `tri-loop`, or `resume-optimizer` — they have never used it and never will, because BR-D17 retires it rather than migrating other projects onto it. The operator's reasoning: the cost is minor but nonzero (a `PAY_PER_REQUEST` table billed for locking calls that a lock **file** object does for free), and **today is the fewest consumers this table will ever have** — waiting until S2-T4 only adds a window where it's live and unnecessary. **Decision: `environments/ai-lab/backend.tf` moves to `use_lockfile = true` now** (`chore/ai-lab-use-lockfile`, ahead of S2), and `bootstrap/state-backend.tf` drops `aws_dynamodb_table.tofu_locks` and its IAM grants in a follow-up, human-applied PR once the cutover is confirmed live. **The org-wide table is a separate question, deliberately not decided here**: this repo does not own `global-tofu-lock` or speak for its other three consumers. This repo's *recorded position* — S2-T4 should not default to repointing at DynamoDB without first considering `use_lockfile` org-wide — is noted for whoever runs S2-T4, and raised as a question against `global-bootstrap` directly rather than assumed settled by this repo alone. |
| **BR-D23** | **The plan is scaled to the system that exists, not the one it resembles.** 158 lines of Python, an empty corpus, one operator, and a lab whose stated design is destroy-and-rebuild — against, originally, nine sprints, twelve required CI checks, five runbooks, a customer-managed KMS key, and a devcontainer carrying a permanent five-tool pin-sync obligation. **The blast-radius work (F1, F41, F45, F47, F40) is untouched and gets everything the plan gives it.** Everything downstream of S2 is cut to fit. **The structural fix matters more than the cuts:** the plan scheduled *"make the project work at all"* (F51/F39/F5) **fifth**, behind three sprints of governance and pipeline construction — while BR-D20 declares `destroy → apply → verify` the acceptance test every infrastructure sprint must pass. No sprint before S2 could pass it, and S1 in particular built an Environment gate, a saved-plan apply and seven required checks *around an apply that had never once succeeded*. The new **`MW`** sprint runs immediately after ST and fixes that. **What this is not:** it is not "five sprints instead of nine" — that headline does not survive its own task list. It is **roughly the same sprint count with about half the tasks, and far fewer permanent obligations**: no pin-sync treadmill, no customer-managed key, no second S3 bucket, four fewer required checks. See § 5 for the resulting sequence. |
| **BR-D24** | **One severity rule, stated once; and no `Blocker` tier.** *(a)* **A multiplier is rated at the severity of the worst outcome it enables** — see the head of § 3, where it now lives. The inventory previously applied this two ways (F17 Critical *as* a multiplier, F47 High *because* multipliers rank lower), which is what surfaced it. Consequences: **F45 → Critical** (its trigger is a repository-settings change with no diff, no PR and no review surface anywhere — and it is the one Critical this plan intends to *create*), **F47 → Critical** (it is what turns lab compromise into compromise of bounty-infra's findings archive), **F13 → High** (its Critical rating double-counted F1's escalation and F17's absent gate; strip both and a BR-D2 violation remains, which is High). **Two arguments for lowering F13 were considered and explicitly rejected**: that no push-to-`main` run has ever succeeded, and that the workflow is `paths:`-filtered. Both are artifacts *this plan deletes*, so recording them as rationale would make the entry false the day `MW` lands. *(b)* **No `Blocker` severity.** F51 is a defect in the deliverable, not a risk, and this scale measures risk; bolting a delivery band onto it muddles both and creates a permanent "is this Blocker or Critical?" argument. The harm the tier was meant to signal was **scheduling**, and BR-D23 already fixed it by creating `MW`. F51 stays High, and § 5 states explicitly that ordering is not by severity. |

---

## 5. Sprint sequence

*Reshaped 2026-08-05 by **BR-D23**. Sprint ids are stable — `S3` and `S4` merge but keep both
ids, and no sprint is renumbered, because renumbering would invalidate every cross-reference
already written into these plans and every `Closes:` line in the inventory.*

| Sprint | Title | Closes | Status |
| --- | --- | --- | --- |
| **S0** | Governance and repository baseline *(+ the Infisical deletion and the budget, pulled forward)* | F17, F33–F38, F53 (the deletion half), F54; **the budget closes no `F`** — it is capability work, see § 5 | **done** |
| **ST** | **Organization transfer** — `Seuss27/` → `glunk-works/` | F44, **F45 (by removal — see the 2026-08-06 log entry)**, F50, the `path` half of F57, and the ST-T1 half of F40. *(**F58** and F57's boundary half → **S2-T0**; **F55** → **MW-T0**; **F56** → **S2-T0**.)* | **done** *(2026-08-07, closed at `b9df242`)* |
| **MW** | **Make it work** — the first successful `destroy → apply → verify` cycle | **F51**, F39, F5, F46, F55 | planned |
| **S1** | Pipeline hardening *(thinned)* | F13–F16, F18–F21 | planned |
| **S2** | Identity, state reconciliation, and `bootstrap/` retirement *(remainder)* | F1–F4, F40, F43, F47 (local half), F48, F56, **F58**, the `permissions_boundary` half of **F57**, BR-D22. ⚠️ **F42 removed** — ST deletes the offending policy instead of correcting it, so F42 survives org-wide and is not closed here | planned |
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
  reason to sit seven sprints out; and the **budget** (~~F27~~ — **no finding id**; F27 is unfiltered retrieval, accepted under BR-D11. Mis-citation removed 2026-08-07, and the paragraph already says the budget closes no `F`), because the plan stated in its
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

1. **⚠ ~~`MW`'s teardown is irreversible until F55 is closed. This is the hazard that costs
   most.~~ — 🔄 THE PREMISE IS SPENT, the ORDER IT PRESCRIBES SURVIVES.** *(Corrected
   2026-08-07 by `MW`'s pre-implementation plan review, against live AWS.)* **There is no
   orphaned workload to delete.** It was destroyed on 2026-06-02; AWS holds one policy-less
   IAM role and the state is empty (**F39**). So the loss this hazard warns about — *"the
   working-but-orphaned system is now gone and the rebuild is blocked"* — **can no longer
   occur**, and repeating it teaches the next reader to discount the hazards that are real.
   **What survives, and it still prescribes proof-first:** the identity is still not
   sufficient, and every gap found the slow way — by watching CI fail — costs a PR **plus a
   human `tofu apply` in `bootstrap/`**, against the single unbacked-up local state file
   **F48** and **#37** are about. Six missing verbs is six such applies. **The argument is now
   cost and F48 exposure rather than irreversibility, and it points at the same order.**
   ⚠️ **The regenerated list must come from CloudTrail on a real apply and must cover the
   DESTROY path too** — every list written before 2026-08-07, here and in the sprint plans, was
   derived from a create path while the acceptance test is `destroy → apply → verify`. The
   original text follows, unedited and superseded above.
   `MW` deletes every orphaned workload resource and rebuilds — but the rebuild runs
   under `github-actions-deploy-role`'s **current** policy, which cannot create at least four
   things the module declares (F55). Those grants have never been exercised, because the last
   run died at `EntityAlreadyExists` before AOSS or Bedrock were reached. Execute the teardown
   first and the working-but-orphaned system is gone, the rebuild fails `AccessDenied`, and
   recovery needs an out-of-band human apply against the very `bootstrap/` root being retired.
   **"The deploy identity is provably sufficient for a from-scratch apply" is a *precondition*
   of `MW`, demonstrated by a dry run before anything is deleted — never a discovery.**
   ~~Either adopt the corrected upstream role first, or widen the current policy first; the
   sprint plan picks one.~~ **⚠️ Corrected 2026-08-07: there is only ONE option, and the struck
   one is the instinctive one.** *"Adopt the corrected upstream role first"* is **not
   available** — `ST-T2′` deleted that role (`NoSuchEntity` against live AWS) and **S2-T0
   re-creates it two sprints after `MW`**. Taking it means either waiting on a later sprint or
   re-adding the upstream entry here **without** the boundary, which reopens **F41** to unblock
   a rebuild. **So: widen `bootstrap/state-backend.tf`'s `state_access_policy` first**, on a
   role S2 then deletes — and record the widening as temporary **with S2-T2 named as its
   removal, in the same PR**, or it becomes permanent by forgetting.
   **Regenerate the missing-verb list from the dry run, not from F55's text.**
2. **~~F57 precedes the upstream boundary condition, and they live in different
   repositories.~~ — ✅ DISSOLVED 2026-08-07; a smaller ordering replaced it.** `ST-T2′`
   deleted the upstream policy **and its `iam:PermissionsBoundary` condition**, so the
   cross-repository race this hazard described no longer exists. **`S2-T0` now writes the
   boundary and the module's `permissions_boundary` argument as one change, in one sprint**,
   which is what removes the hazard rather than merely rescheduling it. What survives:
   `path = "/bedrock-rag/"` landed early in `ST-T2a′` so **`MW` rebuilds at the right path and
   the role is not replaced twice** — that is the only ordering left, and it is already
   satisfied. The original text, retained because its failure mode is the one S2-T0 must not
   recreate: *the module's KB execution role must gain `path` and `permissions_boundary`
   **before** ST-T2's `iam:PermissionsBoundary` condition goes live upstream, or CI's
   `CreateRole` is denied at S2-T2's* verify *step — the exact moment the escalation-capable
   local role still exists and the cheapest unblock is to drop the condition, reverting the
   whole construction.*
3. **The retry-loop fix (F46) ships with `MW`, not after it.** It was S4-T4, two sprints
   later. Without it the first real cycle runs through a twelve-minute silent retry that
   reports an authorization failure as a propagation delay — turning the sprint whose whole
   purpose is diagnosis into the least diagnosable one.
4. **`MW` and S5 both touch `create_index.py`.** `MW` removes the destructive delete and the
   in-module `local-exec`; S5 adds the one contract test. Run `MW` **first** — otherwise S5
   pins behavior `MW` is about to delete, and `MW` lands looking like a regression.
5. **Every sprint that adds a gating check must append it to three places in one PR** — the
   live ruleset, `.ai/project.yml`, and `ruleset-drift.yml` (BR-D9, § 6).
6. **~~The upstream policy fix precedes the transfer~~ (F45) — ✅ SATISFIED 2026-08-06, and
   the *fix* was a deletion.** Upstream PR #5 merged and was human-applied at 15:42Z; the
   transfer followed that evening. The constraint held: *transferring first opens an escalation
   path into the shared account with no IaC diff to review.* **Retained because the shape
   recurs** — `S2-T0` re-creates the very entry that was deleted, so the ordering "upstream
   merged **and applied** before the thing that makes it reachable" binds again there.
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
- **one CI role per project**, generated from `var.projects` — which ~~already contains~~
  **no longer contains** `"bedrock-serverless-rag" = { repo_name = "bedrock-serverless-rag" }`.
  *(Corrected 2026-08-07: `ST-T2′` / upstream PR #5 deleted that entry to close **F45** by
  removal. **This repo has no upstream role today**, and CI runs on its own
  `github-actions-deploy-role` in `bootstrap/`. **S2-T0** re-adds the entry with a boundary;
  until then, do not point anything at `github_actions_role_arns` for this project — the output
  holds no entry for it and the result is an empty ARN, not an error.)*
- an opt-in **read-only PR-time plan role** per project (`plan_roles.tf`, `plan_role = true`);
- the `bounty-scanner-s3-writer` chain-only role.

It **consumes** the GitHub OIDC provider — `data.aws_iam_openid_connect_provider.github` —
it does not create one.

### 9.2 The four couplings that matter here

1. **The OIDC provider (F40).** This repo *creates* what global-bootstrap *reads*. One
   provider per URL per account. Same account ⇒ this repo's state owns the org's federation
   endpoint, ~~with no `prevent_destroy`~~ — **it now carries one** (PR #17, verified against live state; corrected 2026-08-07, since `CLAUDE.md` says so in the present tense and this said the opposite). **It is a stopgap over a *state entry*, not a property of the AWS resource**, so F48's unbacked-up state file voids it. Different accounts ⇒ the org's scaffolding for this
   project is inert. **Answered 2026-08-05: the SAME account.** Stopgap `prevent_destroy` in
   ST-T1; ownership moves upstream in S2-T3 (BR-D18).
2. **The role and its policy (F42, F44) — ✅ RESOLVED 2026-08-06 by deletion; the paragraph
   below is the state at discovery and is retained as the record.** The role no longer exists
   (upstream PR #5, `NoSuchEntity` against live AWS), so this coupling is **gone until S2-T0
   re-creates it**. ⚠️ **Two facts from it survive and bind S2-T0:** the trust subject was
   built in the **plain** form, which an org-owned repo never presents (see **F44** — it would
   have stayed inert *after* the transfer too); and the policy described a workload this repo
   does not have, which is why S2-T0 must derive its verb list from `MW`'s recorded dry run
   rather than from prose. `github-actions-bedrock-serverless-rag` exists
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
   (S2-T2's read-only plan role) are both keys in global-bootstrap's `var.projects` — ~~**ST-T2
   sets both**~~ **and `S2-T0` sets both** *(corrected 2026-08-07: `ST-T2′` deleted the entry
   those keys would live on, so nothing is set upstream for this project today)*. Notably,
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
- **State reconciliation (F39) was absorbed into S2, then moved again to `MW`** (BR-D23). The
  evidence arrived with the answers: run `26788807269` shows `EntityAlreadyExists` on the KB
  role and a stalled S3 bucket create, so the resources exist in AWS and are absent from CI's
  state. **Reconcile by TEARDOWN AND REBUILD, never by import** — BR-D19 said "import" and was
  **reversed** by BR-D20 the same day. *(This line is the last of the five surviving "import"
  instructions the plan review found; the other four were in `CLAUDE.md`, this file's § 5
  hazards, the cursor, and S3's dependency block.)*
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

> ✅ **FILED 2026-08-06 — `glunk-works/global-bootstrap#6`.** Carries the five-point corrected
> construction (role path, boundary condition, `PassRole` scoped by `Resource` **and**
> `PassedToService`, the verbs the boundary condition cannot cover, and `iam:CreatePolicy`
> scoped to a policy path) plus the inline-policy consequence of denying
> `iam:CreatePolicyVersion`. Deliberately contains **no exploit chain and no account
> identifiers** — both repositories are public.
>
> **Now three policies, not four.** `glunk-works/global-bootstrap#5` removes
> `bedrock_rag_policy` and this project's `var.projects` entry outright — **ST-T2′**, closing
> **F45** by removal. `bounty_infra_policy`, `tri_loop_policy` and `resume_optimizer_policy`
> still carry the pattern, and **deleting one project's entry is not fixing it.** ⚠️ Do not
> read F41 as reduced in severity because this repo stopped being one of its instances.
>
> Filed alongside it, per F2 and BR-D22: the `StringLike` → `StringEquals` change on the apply
> role's trust, and the key-provider choice for native state encryption.

Note the asymmetry that makes this concrete: `global-bootstrap`'s `plan_roles.tf` already
carries an explicit `DenyBountyFindingsDataAccess` statement on the **plan** roles, with a
comment explaining that it makes reading third-party vulnerability data structurally
impossible "even if a later edit widens the Allow above." The **apply** roles — the ones with
`iam:*` on `*` — have no such Deny. The control exists; it is on the weaker of the two role
classes.

**And it is weaker still than that sentence implies** *(corrected 2026-08-05, **F58**)*. Two
gaps in the Deny itself, both upstream:

1. **It says "the plan role**s**" — plural — but is attached to one.** `bounty_infra_plan_policy`
   and its attachment are hardcoded, not `for_each`ed over `var.projects`. The plan role
   ~~ST-T2~~ **S2-T0** creates for *this* project would therefore carry **no findings Deny at
   all**. *(Corrected 2026-08-07: `ST-T2′` deleted this project's entry, so no plan role exists
   for it today and this gap is **dormant, not fixed** — it re-arms in the same change that
   re-creates the role. Gap 2 below is **live right now** on `bounty_infra_plan_policy` and is
   not this repo's to fix.)*
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

**F45's upstream half — ✅ DONE 2026-08-06, by DELETION.** `glunk-works/global-bootstrap#5`
("remove the dormant bedrock-serverless-rag role and policy") merged **2026-08-06T15:42Z** and
was **human-applied before the transfer**, per the one hard ordering constraint ST had. It
dropped the `bedrock-serverless-rag` entry from `var.projects`, `aws_iam_policy.bedrock_rag_policy`
and its attachment; `aws iam get-role --role-name github-actions-bedrock-serverless-rag`
returns `NoSuchEntity` against live AWS. *(This paragraph previously read "Both must be
corrected **before** the transfer … This is ST-T2 and it is a pull request against another
repo, on this sprint's critical path." The correction never happened — it was replaced by a
deletion, which is why F45's row says the boundary was **never built**.)*
**What re-opens upstream work here: `S2-T0`**, which re-adds the entry *with* the boundary
construction that ST Task 2b specifies. Until it runs, this project has **no** upstream role,
**no** plan role, and **no** findings `Deny` — a smaller attack surface, not a hardened one.

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
   SSE-S3 — and ~~ST-T2's~~ **S2-T0's** `plan_role = true` creates a role **assumable from any pull request**
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
| 2026-08-05 | **`Invoke-Tofu.ps1` deleted** at the operator's direction — the wrapper existed only to load `environments/ai-lab/.env` into the session before shelling `tofu`, which `TF_VAR_*` and `AWS_PROFILE` already do natively, so it was hiding a setup step rather than providing a capability. Its `.gitignore` entry went with it and `CLAUDE.md` § Commands now documents the native invocation. **Two things closed, one deliberately not.** Closed: the unshippable-file half of **F49** (nothing load-bearing is now invisible to review), and advisory `[M2]` § 3's uncovered subprocess surface — **by deletion rather than by a new deny rule**, which is the better outcome, so `Bash(*Invoke-Tofu*)` must NOT be added to `.claude/settings.json`. Not closed: **F49 itself**. `bootstrap/providers.tf` still declares no `profile`, and removing the wrapper makes that gap *more* visible, not smaller. Copying `global-bootstrap`'s `profile = var.aws_profile` was considered and rejected — `bootstrap/` is being retired, not hardened (BR-D17), so the durable fix is documentation (S6-T1, S6-T2). |
| 2026-08-05 | **Mechanical amendment pass — the cross-reference repair, run after the reshape so it was not done twice.** All **five surviving "reconcile by import" instructions** corrected (`CLAUDE.md`, § 5's ordering hazards, § 9.3, the cursor, S3's dependency block) — BR-D19 was reversed by BR-D20 and two of those five are files read *before anything else*. Every **stale ID range** fixed to **F1–F58 / BR-D1–BR-D24**, including `.ai/project.yml`'s `decisions.log` key, which is the one a skill reads to decide whether BR-D20–D24 exist. **Three coder-halting blockers cleared:** S3-T2's `force_destroy` criterion said `default = false` and reversed its own body (it would have re-wedged `tofu destroy`, the exact cycle F51 exists to fix); S0's token prerequisite named `admin:repo_hooks`, the *webhooks* scope, which halts the sprint at instruction one; ST-T1's body instructed a re-implementation of merged PR #17 work. **The gitleaks deadlock closed** — the licence exemption was true when written and false once ST transfers the repo, which with a required unbypassable `secrets-scan` would have made **every PR unmergeable**; this also gives the repo its **first genuine secret**, and the BR-D21 exception for Actions-consumed secrets is now recorded. **S6-T4's retained transfer checklist deleted** (S6 runs after ST; following it would attempt the transfer twice). Stale `file:line` citations **re-verified against the live files rather than copied from the review**. Findings recounted from the tables after every edit: **5 · 18 · 21 · 14 = 58**, Criticals F1/F17/F41/F45/F47. |
| 2026-08-05 | **The two agent-governing files hardened — `.claude/settings.json` and `.gitignore`.** Both were held out of the docs commits deliberately: they change what an agent may *do*, not what a document says. **Deny list:** added the destructive `tofu state` subcommands (`rm`, `mv`, `push`, `replace-provider`), `tofu import`, `tofu init -migrate-state`, and `gh api` DELETE in both spellings (`-X` and `--method`), each for **both** the `Bash` and `PowerShell` tools. `tofu state rm` is the operation S2-T3 needs and the one the plan itself calls *"the correct verb and the dangerous one … the blast radius differs by an organization"*. **Deliberately NOT blanket-denied:** `tofu state list`/`show` (read-only, and wanted for `MW`'s inventory), and `gh api` PUT/PATCH — S0-T2 and ST-T4 legitimately need them, and a deny is a hard block, so denying them would wedge the plan's own governance work. **The `PowerShell(...)` entries were VERIFIED as a real tool name, not a placebo** — `PowerShell` is a live tool alongside `Bash`, so those rules bind. **Known partial coverage, stated rather than papered over:** the deny patterns are prefix matches, so `tofu init -backend-config=… -migrate-state` (a flag before the pattern) is **not** caught; blanket-denying `tofu init` was rejected because `tofu init -backend=false` is in the green gate. **`.gitignore`:** F54 closed early (`.env*` + `!.env.example`), plus `tfplan`, `plan.json` and `.venv/`. Verified with `git check-ignore` **once per path** — that command exits 0 if *any* argument matches, so the multi-path form the plan suggested could not have proven what it claimed. |
| 2026-08-05 | **`CLAUDE.md`'s Actions rules completed (advisory `[M2]` § 4) — the last outstanding review item.** Every rule already there was correct; four were **missing**, and one of them is load-bearing: **a `pull_request`-triggered job runs the workflow file from the PR branch.** That single fact is what makes **F3** arbitrary command execution with account-admin-capable credentials rather than a least-privilege smell — `deploy-ai-lab.yml` runs on `pull_request` and assumes a role whose live trust (`StringLike repo:<owner>/<repo>:*`) admits `:pull_request`, so anyone who can push a branch edits the `run:` block and gets `iam:CreateRole` on `*`. It was written in no document, which is exactly why F3 read as hygiene and was deferred. **F3 sharpened accordingly** (severity unchanged — it was already right). Also added: `workflow_run` and `issue_comment`/chatops joined `pull_request_target` on the banned-trigger list (all three run in the **base-repo** context with the full token, the property `pull_request` deliberately lacks — and `workflow_run` is precisely what someone reaches for to post a plan summary onto a PR without an artifact); `actions/github-script`'s `script:` block is `run:`-equivalent for injection; and `${{ }}` in an `if:` is injectable when the expression embeds attacker-controlled text — position is not provenance. **S1-T6's acceptance grep was exploitable as written** and now carries a second explicit check: a `github-script` payload sits under `with:` → `script:`, so "matches only in `env:`/`with:`/`if:`/`uses:`/`concurrency:`" **passes** a step containing `${{ github.event.pull_request.body }}`. Whether `zizmor` catches that case is **not assumed** — S1-T3 must confirm against a planted test case and record which control is the real one. |
| 2026-08-06 | **S0 complete — all eight tasks (T1–T8) landed and independently verified.** Four PRs: **#20** (file work — `pr-title.yml`, `ruleset-drift.yml`, the five F37 baseline files, the label/issue-template taxonomy, the Infisical deletion, `budget.tf`), **#21** (Dependabot's own PR, live proof the `commit-message.prefix: chore` fix makes its titles pass `pr-title`), **#22** (`.ai/project.yml`'s `ruleset` block synced to live values), **#23** (cursor handoff). **F17 closed**: `protected-integration-branches` is live on `main` (current ruleset id `20506099` — it changed once already during T6's own delete/recreate test, exactly the trap this plan warned about; never trust a previously-recorded id). Verified two independent ways, not just by reading the API back: a real `git push` directly to `main` was rejected with `GH013`, and T6's `ruleset-drift.yml` was observed to go **red** when the ruleset was deliberately deleted (run `31096079937`) and **green** after recreation from the Task 1 payload (run `31096554632`) — closing T6's own stated gap ("a drift detector that has never been observed to go red has not been tested"). A `security-critic` pass ran on PR #20's diff before commit (8 findings; fixed inline except one deliberately-accepted, documented gap — `ruleset-drift.yml` cannot see a non-empty `bypass_actors` without minting a new admin-scoped credential, which is a decision for later, not a silent gap). **Verification ledger note**: `budget.tf` is hermetically verified only — `tofu validate` passes and the `BUDGET_NOTIFICATION_EMAIL` secret is now set live, but no `tofu apply` has run against it. That live-apply gap is not new scope; it is the same gap **F39** already tracks (no CI apply has ever succeeded) and closes when **MW** achieves its first successful `destroy → apply → verify` cycle. Total findings unchanged at **58**. |
| 2026-08-06 | **ST reshaped at its pre-implementation review — F45 will be closed by REMOVAL, not correction.** The sprint gated an irreversible repository transfer on its own hardest task: a full permissions-boundary construction in `glunk-works/global-bootstrap`, merged *and* human-applied, before the transfer could run. ST-T2b's own text warns such a boundary gets **weakened rather than corrected** under unblock pressure, and ST-T2a names the exact moment it happens — so the plan identified the failure mode and then built the schedule that produces it. Because the upstream role is **inert today** (**F44**: its trust subject matches nothing while this repo is `Seuss27/…`), deleting the project entry closes **F45** outright at a fraction of the risk. **ST-T2 → `T2′`**, a ~20-line deletion PR (`variables.tf` entry, `bedrock_rag_policy`, its attachment), still merged **and human-applied before the transfer**. **Generalisable:** when a finding is *"a thing that will become dangerous"*, check whether the thing is needed **yet** before designing its control. **Re-homed, not dropped** — each is written into its destination sprint's plan, which is now an ST Definition-of-Done criterion: **F55 → MW** and **re-pointed** (with no upstream role, MW runs under this repo's own `github-actions-deploy-role`, so sufficiency now targets `bootstrap/state-backend.tf`'s `state_access_policy`; all four gaps re-verified present 2026-08-06 — no `aoss:*AccessPolicy`, no `iam:PassRole`, no `s3:GetBucket*`, no `s3:PutEncryptionConfiguration`). **F56, F58, and F57's `permissions_boundary` half → S2**, via a new blocking **S2-T0** that re-creates the upstream entry *with* the boundary; **ST-T2b is retained verbatim and is normative there**, expressly to stop S2 re-adding the escapable original. **F57's `path` half landed in ST** (`ST-T2a′`) so **MW** rebuilds at `/bedrock-rag/` and the role is not replaced twice. **F41 and F42 remain OPEN org-wide** — `resume_optimizer_policy` carries the identical escalation; deleting one project's entry is not fixing the pattern, and **F42 is struck from S2-T2's finding list** to stop it being marked done. **Three downstream plans corrected where the reshape made them false:** **MW**'s blocking gate claimed the rebuild fix would be *"a permission this repo cannot grant itself"* — the inverse is now true, the policy stays local and editable, so MW's option 1 (*adopt the upstream role first*) is **struck as unavailable** and option 2 becomes the default; **S2**'s dependency required *"the corrected upstream policy is applied"*, a condition that can now never be met; and **S1**'s claim that ST *"already added `extra_oidc_subjects` and `plan_role`, and a human applied it"* is false — S1 keeps its `AWS_PLAN_ROLE_ARN` fallback one sprint longer and its gated apply authenticates only because **F2's `StringLike` glob** matches `:environment:production`, so **S2 must add that subject in the same change that narrows the trust policy**. **Errors found by checking live state rather than the plan text:** ST-T0 needed **no apply** (its drift was *code behind live*; committing `iam:ListAttachedRolePolicies` closed it in the write-free direction — verified `No changes.`), dropping the sprint from four human applies to **three**; ST-T4's headline criterion `grep -rn 'Seuss27'` **could not pass without deleting the historical record** (the string is load-bearing in five sprint plans and F17's evidence row) and is rewritten as an explicit operative-file list with the record exempted; ST-T4 also named a variable that does not exist (`AWS_PLAN_ROLE_ARN`) and told the executor to repoint the surviving two at upstream outputs that `T2′` empties — which would leave CI unable to authenticate straight after an irreversible transfer; and ST-T3's criterion *"the role resolves to the corrected policy"* inverts to *"the role is absent"*. **Resolved rather than carried:** **org-level rulesets cannot exist** — `glunk-works` is on the **Free** plan and the rulesets API returns 403-upgrade-required, so the BR-D9-from-outside deadlock is impossible *on the current plan* (the first lookup returned **404 for a missing `admin:org` scope**, which reads identically to "none exist" — the distinction between *verified absent* and *could not look* is the entire value of the check); **org base permission is `read`**, so the transfer does not hand org members write access as the Critical Review assumed; and **ST-T1's `prevent_destroy` guard verified against live state**, failing with `Instance cannot be destroyed … lifecycle.prevent_destroy set`. **Still outstanding: F48's off-workstation state backup**, which now gates only ST-T3's two applies — fewer applies is less exposure, not none. Total findings unchanged at **58**. |
| 2026-08-07 | **ST COMPLETE — the repo lives at `glunk-works/bedrock-serverless-rag`. BR-D13 executed.** *(Dates are UTC; the transfer straddles 2026-08-06→07 UTC.)* **`T2′` first, as the sprint's one hard ordering constraint required:** upstream `glunk-works/global-bootstrap#5` merged **2026-08-06T15:42Z** and was human-applied *before* the transfer, deleting the `bedrock-serverless-rag` entry from `var.projects` plus `bedrock_rag_policy` and its attachment — **F45 closed BY REMOVAL, not by correction, so no boundary, no role path scope and no findings `Deny` was built for this project.** `aws iam get-role --role-name github-actions-bedrock-serverless-rag` returns `NoSuchEntity` against live AWS, confirmed again after the transfer. **`T3` ran widen → transfer → narrow in one session** (PR **#29** `8563844` at 23:33Z; human UI transfer; PR **#30** `ae06e51` at 00:43Z) — the narrow was blocking, not trailing, because GitHub usernames are **reclaimable** and the widen leaves a dangling-subject trust policy on a role holding `iam:CreateRole` on `*` in the shared account. Verified against **live AWS, not the HCL**: one subject, `repo:glunk-works@<org_id>/bedrock-serverless-rag@<repo_id>:*`, zero `Seuss27` occurrences, and both a `push`- and a `pull_request`-context run authenticated afterwards. **⚠️ THE FINDING OF THE SPRINT — the transfer broke CI authentication for a reason in no plan.** An **org-owned** repo presents an **ID-qualified** OIDC subject, `repo:<owner>@<org_id>/<repo>@<repo_id>:<context>`, which a plain `repo:<owner>/<repo>:*` glob does **not** match. Measured from CloudTrail `AssumeRoleWithWebIdentity`; **`gh api .../actions/oidc/customization/sub` reports `use_immutable_subject: false` and is wrong** — read `sub_claim_prefix`, confirm against CloudTrail. Written into **S2-T2** and **F2**, because enumerating the plain form under `StringEquals` reproduces the outage *in the task that also deletes the fallback role*, and because `global-bootstrap` builds the plain form, so **S2-T0 inherits the trap by adoption**. **`T4` re-verified every S0 criterion live under the new owner** rather than assuming survival — ruleset healthy (four rule types, `bypass_actors: []`, `pr-title` required), merge settings already correct (no `PATCH` needed), labels present, `pr-title` workflow clean, baseline files intact, and `ruleset-drift.yml` **manually dispatched and passed** (run `31136157954`). Two operative references edited (`.ai/project.yml`'s `repo:` key, the issue-template discussions URL); `CODEOWNERS` verified still resolving (`codeowners/errors` empty) rather than assumed. **Findings closed: F44** (by deleting the inert scaffolding — *and its premise was incomplete: the entry would have stayed inert after the transfer anyway, on the ID-qualified subject*), **F45** (by removal), **F50** (with **no apply at all** — the drift was *code behind live*, so committing `iam:ListAttachedRolePolicies` closed it in the write-free direction, dropping the sprint from four human applies to three), and **F57's `path` half** (`ST-T2a′`, landed before `MW` so the role is not replaced twice). **Findings re-homed and CONFIRMED WRITTEN INTO THEIR DESTINATIONS** — the criterion exists because a finding moved out of a sprint and not written into where it landed is a finding dropped: **F55 → `MW-T0`** (re-pointed at this repo's own `state_access_policy`, all four gaps re-verified present), **F56, F58 and F57's `permissions_boundary` half → `S2-T0`**, with **ST Task 2b normative there**. **F41 and F42 remain OPEN org-wide** (`glunk-works/global-bootstrap#6`) — deleting one project's entry removed an instance, not the pattern, and **F42's own cited policy no longer exists while the finding does not close**. **F48's off-workstation state backup WAS taken** — confirmed by the operator at ST's completion review on 2026-08-07 and recorded only then, which is the sprint's one genuine process failure: for about a day the criterion was **indistinguishable from one that had been skipped**, and closing ST required asking a human rather than reading a record. **Its restore-test and the re-take-before-the-narrow are attested, not proven, and are carried into S2-T3/T4** as a blocking precondition of the applies there, **tracked as #37**. Total findings unchanged at **58**; closed count now **6 fully + 3 half** (see § 3's closed list, restated as a list because the previous bare count went stale silently). |
