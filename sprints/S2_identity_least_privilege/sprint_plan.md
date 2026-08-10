### FILEPATH: /sprints/S2_identity_least_privilege/sprint_plan.md

# S2 — Identity, state reconciliation, and `bootstrap/` retirement

> **⚠ This sprint was re-scoped on 2026-08-05.** It was written as *"harden this repo's
> `bootstrap/`"* — a permissions boundary, a role split, an enumerated OIDC trust policy.
> The operator then confirmed **one shared AWS account** and **the transfer to
> `glunk-works`**, which resolved **BR-D17** in favour of `global-bootstrap` owning identity
> and state. So `bootstrap/` is **retired, not hardened**: hardening a role that is about to
> be deleted would have been recorded in the roadmap as a fixed finding while the live path
> stayed untouched. The boundary construction itself was not discarded — it moved upstream,
> into **ST-T2** and the F41 issue.

> **⚠ Re-scoped a second time, 2026-08-05, by BR-D23.** Task 1 (teardown and rebuild) and
> Task 6 (the AOSS data-plane principal) **moved to the `MW` sprint**, which has since run and
> completed. Do not execute them from here.

> **⚠ Re-scoped a third time, 2026-08-06, by ST's pre-implementation review.** **ST no longer
> *corrects* the upstream `bedrock-serverless-rag` policy — it DELETED the whole project entry**
> (`ST-T2′`), because the role was inert (F44) and deleting it closed **F45** without gating an
> irreversible transfer on a permissions-boundary design. **The consequence is not cosmetic:
> there is no upstream role left to adopt.** Task 0 re-creates it correctly, and it is blocking.
> **`ST` Task 2b is the NORMATIVE specification for Task 0** — retained verbatim in
> `sprints/ST_org_transfer/sprint_plan.md`. Read it there. Its entire purpose is to stop this
> sprint re-adding the original, escapable construction. Arriving here from ST: **F58**, the
> **`permissions_boundary` half of F57**, and **F56**.

> **📥 ARRIVED FROM `S1` 2026-08-08:** `S1`-T4, the PR-triggered `tofu-plan` job, is now this
> sprint's to build. Its body is retained verbatim as the normative spec in
> `sprints/S1_pipeline_hardening/sprint_plan.md` Task 4. It moved because `S1b`-T2 left this
> repo with **zero credentialed `pull_request` jobs**, and T4 as written would have put an
> **apply-capable** role back on that trigger — no plan role exists until this sprint.

---

> ## 🔄 RE-SCOPED A FOURTH TIME — 2026-08-09, by this sprint's own planning pass
>
> **Unlike the four banners above, the task bodies below were REWRITTEN to agree with this
> one.** The file previously carried the hazard it warned about — *"a task body wins over a
> banner for anyone who scrolls straight to their task"* — across four accreted re-scopes. The
> banners above are retained as **historical record**; the tasks below are the executable plan.
> Superseded acceptance criteria are called out **at the criterion**, not only here.
>
> ### What was measured (not read off prose) on 2026-08-09
>
> Every claim below was checked against live GitHub, live AWS, or the upstream repository.
>
> 1. **🔴 The ID-qualified OIDC subject is REPO-SPECIFIC, not a property of org ownership.**
>    `bedrock-serverless-rag` presents `repo:<org>@<org_id>/<repo>@<repo_id>`; **`bounty-infra`,
>    which is equally org-owned, presents the PLAIN form**; there is no org-level sub-claim
>    template (404). **BR-D13's and F44's generalisation — "an org-owned repo presents an
>    ID-qualified subject" — is therefore FALSE as stated**, and is corrected in the roadmap.
>    The consequence is structural, not a reminder: `global-bootstrap`'s `main.tf` and
>    `plan_roles.tf` both build the **plain** form, and `plan_roles.tf` has **no subject-override
>    mechanism at all**. **Task 0 as previously written would have minted two roles this repo
>    cannot assume.** Resolved by **BR-D27** (a per-project `oidc_subject_prefix`).
> 2. **🔴 `state_access_policy`'s main statement is `Resource = "*"`**, with an in-file comment
>    conceding it (`bootstrap/state-backend.tf`, *"This should be locked down outside of lab
>    use"*). The instruction *"derive the verb list from `MW`'s recorded dry run"* — repeated in
>    F42, F55 and this plan — **is a trap if followed mechanically**: it would hand the
>    *replacement* role `s3:DeleteBucket` on `*` (reaching the **org state bucket**, i.e. every
>    project's state), `bedrock:DeleteKnowledgeBase` on `*`, and `aoss:Create/UpdateAccessPolicy`
>    on `*` — which that same file already documents as *"this role could rewrite ANY
>    collection's data-access policy to name itself."* **The permissions boundary does not catch
>    any of it: `iam:PermissionsBoundary` constrains `iam:` verbs only.** The rule, stated once
>    and binding Task 0c: **derive the verbs, re-derive every `Resource`.**
> 3. **🔴 The upstream and local roles have DISJOINT state-bucket access.** `state_access_policy`
>    scopes S3 to this repo's own bucket; upstream `pipeline_state_policy` scopes to the org
>    bucket only. **No role can read both.** So identity switchover and backend migration cannot
>    be done independently in either order — recorded as a new ordering hazard in the roadmap and
>    resolved by Task 3's read-only bridge.
> 4. **Task 4's old body and criteria were stale in three ways and one would have caused a
>    regression.** BR-D22's re-amendment already shipped: `environments/ai-lab/backend.tf` runs
>    `use_lockfile = true` with **no `dynamodb_table`**, `required_version` is `>= 1.10.0` (not
>    `>= 1.8.0`), and `bootstrap/state-backend.tf` no longer declares a lock table. The old
>    criterion *"`backend.tf` still declares `dynamodb_table`, now pointing at `global-tofu-lock`"*
>    is **VOID — satisfying it would re-add what BR-D22 deliberately removed.** Confirmed live:
>    upstream `pipeline_state_policy` grants `s3:GetObject`/`PutObject`/`DeleteObject` on
>    `<project>/*`, which **already covers the `.tflock` object**, so `use_lockfile` works against
>    the org bucket with no upstream change and no `global-tofu-lock` coupling at all.
> 5. **🔴 Task 4's old step order leaked state permanently.** *Migrate → then encrypt*, against a
>    **versioned** org bucket, writes a plaintext state version that persists **forever**. Split
>    and reordered: **encrypt first (Task 2), migrate second (Task 3).**
> 6. **The blocking #37 restore-test is DONE**, closed 2026-08-07 with recorded evidence (parses,
>    lists `aws_iam_openid_connect_provider.github_actions`, timestamp cross-checked against
>    PR #48). The Risks section's *"restore the copy before the first apply here"* precondition is
>    **satisfied**; what remains is re-taking it before Task 5's `state rm`.
> 7. **The lab is genuinely torn down** — zero AOSS collections, zero Knowledge Bases, state
>    object 373 bytes. Which means **`No changes.` against it is vacuous** and cannot serve as
>    Task 3's reconciliation criterion; the lab must be UP before the migration.
> 8. **`ci.yml` already defuses the matrix trap** — `tofu-validate` covers `bootstrap/` as
>    sequential steps in one job, not a matrix, precisely so the check-run name stays bare.
>    Removing `bootstrap/` in Task 5 deletes two steps and cannot rename a required check.
>
> ### Decisions taken by this pass
>
> | # | Decision | Where recorded |
> | --- | --- | --- |
> | 1 | Per-project `oidc_subject_prefix` upstream, plain form as the computed default | **BR-D27** |
> | 2 | Task 0 splits three ways: shared schema → operator → this project's entry | Task 0 below |
> | 3 | The cutover uses a **read-only** temporary bridge on the dying local role | Task 3 below |
> | 4 | `bootstrap/` is **deleted entirely**, directory and wiring, not merely emptied | Task 5 below |
> | 5 | The schema half proves `No changes.` and needs **no apply of its own** | Task 0a below |
> | 6 | The plan role's read of the budget subscriber list is an **accepted residual** | **R1** below |
>
> ### Structural changes to the task list
>
> - **Task 0 → 0a / 0b / 0c** (three PRs, **two** upstream applies).
> - **Old Task 4 → new Tasks 2 and 3**, and both now run **BEFORE** old Task 2 (see measured
>   fact 3). Old Task 4 step 4 (retire the local bucket) folds into new Task 5.
> - **Old Task 5 (F4) merges into new Task 1** — same file, same role, same rebuild to verify.
> - **Old Task 3 merges into new Task 5** — both end at *"`bootstrap/` manages nothing"*, both
>   need one apply, and Task 5 cannot proceed without Task 3 anyway.
> - **Old Tasks 1 and 6 stay MOVED to `MW`** (complete). Not repeated below.
>
> **Result: 6 tasks, 3 upstream human applies, 3 local `bootstrap/` human applies, and one
> manual state migration.** That is more human-apply surface than `MW`, `S1a` and `S1b`
> combined — treat any opportunistic addition to this sprint as needing an explicit reason.
> **F61 (floating tool versions) is deliberately NOT taken here**; it is deferred to `S3+S4`.

---

**Sprint Goal:** This repo ends the sprint owning its **workload and nothing else**. No OIDC
provider, no CI role, no state bucket, **and no `bootstrap/` directory** — and state
confidentiality that does not depend on who can read the bucket.

**Closes:** F1 (Critical), F2, F3, F4, F40, F43, F47 (local half), **F48 (by removal)**, **F56**,
**F58** (gap b), the `permissions_boundary` half of **F57**, and the local half of F47.
Executes **BR-D22**, **BR-D18**, **BR-D27**.
*(F5, F39, F51 closed in `MW`. **F42 is NOT closed here** — ST deleted the offending policy
rather than correcting it, so F42 survives org-wide against the three other project policies:
`glunk-works/global-bootstrap#6`. **F58 gap (a)** — the `s3:`-only Deny on
`bounty_infra_plan_policy` — is **not this repo's to fix** and stays on that same issue.)*

**Dependencies:** **ST, `MW`, `S1a` and `S1b` are all complete.** ⚠️ The old dependency
*"`global-bootstrap`'s corrected `bedrock-serverless-rag` policy is applied"* **can never be
met and must not be waited on** — ST deleted the entry; writing the corrected one is **Task 0b
of this sprint**.

**Security Considerations:** The sprint's risk profile is inverted from the usual: the danger is
not adding a weak control, it is **deleting a working one before its replacement is proven**.
Every identity retirement below is written as **adopt, verify, then delete** — never the other
order. **⚠️ And this pass found that discipline was being applied to the *identity* but not to
the *capability*:** the old Task 2 verified only that the new role could run an apply, which —
with the lab already up and state migrated — is a **no-op refresh** proving nothing about the
create path and nothing at all about the destroy path. The destroy path has been exercised
**exactly once** in this repo's history and `state_access_policy`'s own comment says *"anything
further down the destroy graph remains just as unmeasured."* Under the old role each missing
verb cost a local PR and a local apply; **under the new role each one costs an upstream PR and a
human upstream apply.** Task 4's verify is therefore the **full BR-D20 cycle**, run under the new
identity **while the old role still exists as a fallback**.

**Risks & Blockers:**
- **The account is shared with the organization (F47).** An identity mistake does not fail
  locally. A workload mistake costs an apply (BR-D20). Keep the two straight.
- **Task 0b changes the trust policy of three sibling projects.** It is the largest blast radius
  in this sprint — not, as first assumed, the safest task. See Task 0b's verification protocol.
- **⚠️ `bootstrap/`'s state is a single-machine local file (F48) until Task 5 deletes it.**
  #37's restore-test is **done and recorded**; what remains is **re-taking the backup immediately
  before Task 5's `tofu state rm`**, which is the one operation in this roadmap where the correct
  verb and the dangerous one are the same string.
- **AOSS bills its OCU floor continuously** (BR-D26), well above `budget_limit_usd`'s `"20"`. The
  lab schedule below is deliberate, not incidental.
- **Never delete anything shared with the organization** — the OIDC provider above all,
  `global-bootstrap`'s state bucket, or bounty-infra's findings archive (F47, BR-D18).

### Lab schedule — deliberate, not incidental

| Phase | Lab | Why |
| --- | --- | --- |
| Tasks 0a–0c | **down** | Upstream-only work |
| Task 1 | **down** | ⚠️ **Required** — the boundary is set at `CreateRole` time, which avoids the missing `iam:PutRolePermissionsBoundary` verb entirely |
| Task 2 → approve this merge's rebuild | comes **up** | Encryption must be proven, and Task 3 needs a non-empty state |
| Task 3, Task 4 | **up** | `No changes.` only means something against 12 tracked resources; Task 4's verify needs real destroy + real create |
| after Task 4's verify | **down** | Tear down immediately |
| Task 5 | **down** | |

**Decline the rebuild approval on every other merge.** Every push to `main` queues one
(`S1a`-T5 removed the `paths:` filter deliberately); with ~8 PRs in this sprint, that is ~8
prompts and only two of them should be accepted.

---

## Tasks

### Task 0 — Re-create the upstream project entry, WITH the boundary
**(F56, F58 gap b, F57 boundary half, F2, BR-D27) — BLOCKING**

> **⚠️ Read `ST` Task 2b before writing a line of this.** It is retained verbatim in
> `sprints/ST_org_transfer/sprint_plan.md` and is **normative**. It enumerates three independent
> holes in the construction originally proposed — `iam:UpdateAssumeRolePolicy`/`iam:UpdateRole`
> reachable outside the boundary condition, `iam:PassRole` scoped by service but not by
> `Resource`, and `iam:CreatePolicy` scoped nowhere. The **superseded** body is retained
> immediately below `T2′`, clearly marked. **Do not implement the one marked SUPERSEDED.**

**Why this task exists:** `ST-T2′` deleted the `bedrock-serverless-rag` entry from `var.projects`
upstream to close **F45** by removing a dormant over-privileged role rather than correcting it.
That was the right trade *for ST* — it took a permissions-boundary design off the critical path
of an irreversible transfer. The design was **deferred, not cancelled**, and this is where it
lands, with no irreversible act waiting on it and no pressure to weaken it to unblock a pipeline.

---

#### Task 0a — upstream: the subject-prefix schema (PROVES `No changes.`, needs NO apply)

- **Description:** Add the mechanism BR-D27 specifies, **keeping `StringLike` untouched**, so the
  rendered subject strings are byte-identical and the change is a provable no-op.
  1. `variables.tf` — add `oidc_subject_prefix = optional(string, null)` to the `projects` object.
  2. `main.tf` — add `locals.subject_prefix`, defaulting to the existing computed plain form
     (`coalesce(v.oidc_subject_prefix, "repo:${var.github_organization}/${v.repo_name}")`), and
     thread it through the apply role's subject construction.
  3. `plan_roles.tf` — thread the same local through the plan role's `StringEquals` subject.
  4. **Validations, mirroring `bootstrap/oidc-setup.tf`'s** — must start with `repo:`, and must
     contain neither `*` nor `?`. ⚠️ The wildcard validation is **load-bearing in this PR
     specifically**: this is the one window in which the variable exists while the operator is
     still `StringLike`, where `*` matches `:` too.
- **Target Files:** upstream `variables.tf`, `main.tf`, `plan_roles.tf`
- **Acceptance Criteria:** `tofu plan` upstream reports **`No changes.`** — that clean plan **is**
  the safety proof and must be **recorded in the PR body** (change counts only, BR-D4), because a
  criterion whose only evidence is memory has already failed (F48's process finding).
  **No apply is required or performed**; the change rides along with Task 0b's apply. `tofu fmt
  -check` and `tofu validate` pass upstream — this repo's green gate does not cover that repo.

---

#### Task 0b — upstream: `StringLike` → `StringEquals` on the apply role (F2), ALONE

- **Description:** One change, one file, one variable. F2's entire substance is that *in IAM
  `StringLike`, `*` matches `:` too* — so an `extra_oidc_subjects` entry containing a `*` would
  glob silently. Every rendered value is wildcard-free today, which makes this behaviour-
  preserving; it is **not** cosmetic, because it removes the mechanism rather than relying on the
  values staying clean.
- **⚠️ This is the largest blast radius in the sprint.** It rewrites the `assume_role_policy` of
  `bounty-infra`, `tri-loop-dev` and `resume-optimizer`. It was originally packaged with Task 0a
  and mis-described as *"provably safe because it plans `No changes.`"* — **it does not; it plans
  in-place updates to three sibling roles.**
- **Verification protocol — both halves are required:**
  1. **Static, pre-apply:** confirm from the rendered plan JSON that **no subject value contains
     `*` or `?`**, and that the subject value arrays are **byte-identical** before and after. That
     is what makes `StringLike ≡ StringEquals` a proof rather than a belief.
  2. **Active, post-apply:** do **not** wait passively for siblings to push. Dispatch a cheap
     workflow in each sibling repo, or confirm a fresh `AssumeRoleWithWebIdentity` per project in
     CloudTrail. ⚠️ Only two of the four repos' `sub_claim_prefix` values could be read on
     2026-08-09 — `tri-loop-dev` and `resume-optimizer` return **404** (most likely "never
     configured", i.e. the plain form, but that is **inference**). Passive waiting would make the
     rollback window *"whenever they next push."*
- **Target Files:** upstream `main.tf`
- **Acceptance Criteria:** Plan shows **only** in-place updates to
  `aws_iam_role.github_actions_role[*]`, **zero replacements**, nothing created or destroyed.
  Both verification halves above are recorded in the PR body. **Human apply upstream (1 of 3).**
  Rollback stated in the PR body: revert and re-apply.

---

#### Task 0c — upstream: this project's entry, the boundary, and our findings `Deny`

- **Description:** An upstream PR re-adding the entry, per **ST Task 2b**:
  1. **`variables.tf`** — `"bedrock-serverless-rag" = { repo_name = …, plan_role = true,
     extra_oidc_subjects = ["environment:production"], oidc_subject_prefix = <ID-qualified> }`.
     The prefix value is **not BR-D4 restricted** — a public org name, a public repo name, and two
     GitHub numeric ids readable with `gh api repos/<owner>/<repo> --jq '.id, .owner.id'`.
  2. **`project_policies.tf`** — the workload policy and the permissions-boundary policy document,
     per **Task 2b(1)(2)(3)(5)**.
  3. **`plan_roles.tf`** — a `for_each`ed workload **read** policy (**F56 gap b**: today
     `bounty_infra_plan_policy` is hardcoded, so a new plan role would hold state-read and nothing
     else and every PR plan would `403` on refresh).
  4. **Our findings `Deny`** — a **new, standalone** policy covering **`s3:` AND `kms:`** on the
     findings bucket, its objects, and the KMS key (**F58 gap b**, Task 2b(6)). Use the existing
     `findings_kms_key_arn` output; do not hardcode a key ARN.

- **⚠️ Four constraints, each of which a literal executor gets wrong:**

  - **DERIVE THE VERBS, RE-DERIVE EVERY `Resource`.** `MW`'s recorded harvest lives in
    `bootstrap/state-backend.tf`, whose main statement ends `Resource = "*"` with a comment
    conceding it. Copying it mechanically gives the replacement role `s3:DeleteBucket` on `*`
    (reaching the **org state bucket**), `bedrock:DeleteKnowledgeBase` on `*`, and
    `aoss:Create/UpdateAccessPolicy` on `*` — **and the boundary catches none of them, because
    `iam:PermissionsBoundary` constrains `iam:` verbs only.** The three statements in that file
    that **are** already properly scoped — `budgets:` (to the one budget ARN), `iam:PassRole`
    (to `role/bedrock-rag/*` plus `PassedToService`), and `aoss:APIAccessAll` (to
    `collection/*` in this account) — are the model. Everything in the flat statement needs a
    resource re-derived from what `modules/aws-bedrock-rag/` actually declares.
  - **Grant `iam:PutRolePermissionsBoundary`**, under the boundary condition. Nothing grants it
    today, so any future apply that attaches a boundary to an **existing** role fails. Task 1
    sidesteps this by running with the lab down, but the verb is still owed.
  - **DO NOT TOUCH `bounty_infra_plan_policy`.** An earlier draft of this plan proposed
    extracting its inline `Deny` and `for_each`ing it. That puts a sibling's live CI in the blast
    radius for no benefit, and **F58's own row says gap (a) is not this repo's to fix.** Create
    our own policy; leave theirs alone; leave gap (a) on `glunk-works/global-bootstrap#6`.
  - **Attach our `Deny` to BOTH our roles, and replicate it inside the boundary document.** Our
    apply role has no legitimate reason to reach the findings bucket — F47's explicit gap is that
    *apply* roles have no equivalent Deny, and here it is free. Putting it in the boundary too
    means any role our CI creates inherits it as a ceiling regardless of its own policy. *(This is
    safe here precisely because it would **not** be safe on bounty-infra's apply role, which
    legitimately writes findings.)*

- **Target Files:** upstream `variables.tf`, `project_policies.tf`, `plan_roles.tf`
- **Acceptance Criteria:** Task 2b(4)'s **allowlist** grep passes — *no `Allow` on any `iam:`
  action whose `Resource` is not literally `role/bedrock-rag/*` or `policy/bedrock-rag/*`*. The
  boundary policy document is **committed upstream, not improvised**. **The phrase "structurally
  impossible" appears nowhere** — the enumerated **residual register** at the foot of this plan
  appears instead. Plan shows **only new resources**, every one `bedrock-rag`-scoped. **No AWS
  account id anywhere in the PR body or the committed HCL** — use `data.aws_caller_identity`
  (BR-D4; that repo is public too). **Human apply upstream (2 of 3).**

> **Then, and only then, Task 4 becomes executable** — there is a role to adopt.

---

### Task 1 — Module IAM: the permissions boundary and the confused-deputy fix
**(F57 boundary half, F4 / issue #6)**

- **⚠️ Run this with the lab TORN DOWN.** With the role absent, the boundary is set at
  `CreateRole` time — which `iam:CreateRole` under the boundary condition already covers. With the
  role present, attaching a boundary is an in-place `iam:PutRolePermissionsBoundary` call **that
  no policy grants today**, and the apply fails. This is free ordering, not a workaround.
- **Description:**
  1. Set `permissions_boundary` on every `aws_iam_role` in `modules/aws-bedrock-rag/` and thread
     the variable from `environments/ai-lab`. **Build the ARN from
     `data.aws_caller_identity.current.account_id`** — never a committed literal, never a
     variable default carrying an account id (BR-D4). **`path = "/bedrock-rag/"` is already set**
     (`ST-T2a′`) — do not re-add it.
  2. Add `aws:SourceArn` to `bedrock_kb_role`'s trust policy alongside `aws:SourceAccount`. The KB
     ARN is not knowable before the KB exists, so **construct the pattern** under `ArnLike`:
     `"arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:knowledge-base/*"`.
     Do **not** reference `aws_bedrockagent_knowledge_base.rag_kb.arn` — that is a dependency
     cycle OpenTofu reports as an obscure graph error at plan time.
  3. **Opportunistic, and cheap:** add `required_version` and `required_providers` to
     `modules/aws-bedrock-rag/`. `.tflint.hcl` disables `terraform_required_version` and
     `terraform_required_providers` for three reasons, two of which are this module's missing
     blocks; the file itself records that this *"needs its own tracked finding and closing task
     before re-enabling — not yet recorded."* Task 5 removes the third reason.
- **Target Files:** `modules/aws-bedrock-rag/iam.tf`, `modules/aws-bedrock-rag/variables.tf`,
  `environments/ai-lab/main.tf`, `environments/ai-lab/variables.tf`
- **Acceptance Criteria:** Every `aws_iam_role` in `modules/` declares both `path` and
  `permissions_boundary`. The trust policy carries **both** `StringEquals aws:SourceAccount` and
  `ArnLike aws:SourceArn`. **`tofu plan` shows no cycle error.** `Closes: #6` in the PR body.
  **⚠️ SUPERSEDED CRITERION:** the old Task 5 required *"`tofu plan` shows an **in-place update**,
  no role replacement."* **That is unsatisfiable while the lab is torn down** — an empty state
  plans `12 to add`, never an update. Replaced by: no cycle error at plan time, and the role
  builds successfully with both conditions present on the next apply (Task 2's rebuild).

---

### Task 2 — Adopt native state encryption, IN PLACE, before anything moves
**(BR-D22)**

- **⚠️ This must precede the migration, and the reason is permanent.** The org bucket has
  **versioning Enabled**. Migrating first and encrypting second — the old Task 4's step order —
  writes a **plaintext state version into the org bucket that persists forever**. Encrypting
  first means the migration's write is already ciphertext, and the old bucket's plaintext
  versions die with the bucket in Task 5.
- **Description:** Add a `terraform { encryption { … } }` block with an `aws_kms` key provider to
  **`environments/ai-lab` only**.
  **⚠️ AMENDS BR-D22, which says "both roots."** `bootstrap/` is **deleted** in Task 5, not
  encrypted — there is no value in encrypting a root that ceases to exist in the same sprint, and
  the `required_version` floor BR-D22 asks for there becomes void with it.
  **`required_version`:** `environments/ai-lab/providers.tf` already declares `>= 1.10.0`
  (BR-D22's re-amendment), which covers native encryption's `>= 1.7` floor. **No bump needed** —
  ⚠️ BR-D22's text still says `>= 1.8.0`; that is stale, corrected in the roadmap.
  **Why this and not SSE.** SSE-S3 protects the object at rest in S3 and nothing else; it does not
  protect state from anyone who can legitimately `s3:GetObject` it — and after Task 0c that set
  includes **a plan role assumable from any pull request**.
- **Target Files:** `environments/ai-lab/providers.tf` (or a dedicated `encryption.tf`)
- **Acceptance Criteria:** The state object **does not parse as JSON** — verified by `aws s3 cp`
  and a parse attempt, which is the only check that distinguishes native encryption from SSE.
  **Approve this merge's `tofu-apply`** — this is one of only two rebuilds this sprint accepts,
  and it is what makes Task 3's `No changes.` mean anything.

---

### Task 3 — Bridge, then migrate to the org backend
**(F43, part 1)**

> **⚠️ NEW ORDERING HAZARD, measured 2026-08-09 — this task did not previously exist in this
> position.** `state_access_policy` scopes S3 to **this repo's own bucket**; upstream
> `pipeline_state_policy` scopes to **the org bucket only**. **No role can read both.** So adopting
> the upstream roles while `backend.tf` names the local bucket fails `AccessDenied`, and migrating
> the backend while CI runs on the local role fails `AccessDenied` the other way. **The old Task
> 2's criterion — "a full PR→merge→approve→apply cycle green on the two upstream roles" — was
> unsatisfiable in the old Task 2's position.**

- **Description:**
  1. **The bridge.** Add a **new, separately named** `aws_iam_role_policy` — e.g.
     `state_migration_bridge` — to `bootstrap/`. **Not an edit inside `state_access_policy`:** a
     distinct resource makes the temporary thing visible, and its removal is a deletion rather
     than surgery on a hundred-line policy. It dies with the role in Task 4 either way.
     **⚠️ READ-ONLY.** `s3:GetObject` on `<org-bucket>/bedrock-serverless-rag/*`, and
     `s3:ListBucket` on the bucket **with the `StringLike s3:prefix` condition copied verbatim
     from `pipeline_state_policy`**. Without that condition it enumerates every project's state
     keys. No `PutObject`, no `DeleteObject`: the migration itself is a **human, local, admin-SSO**
     operation, and the first CI **write** to the org bucket happens under the upstream apply role
     in Task 4. Verification here is `tofu plan -lock=false`.
     *Record in the resource's comment why this is not a privilege increase: it grants read on a
     **copy** of state the role already has full access to in the local bucket. Net new exposure
     is zero — provided the prefix condition is present.* **Human apply (`bootstrap/`, 1 of 3).**
  2. **Migrate.** Human, admin SSO: `tofu init -migrate-state`. Repoint
     `environments/ai-lab/backend.tf` to `bucket = "glunk-works-tofu-state-00042"`,
     `key = "bedrock-serverless-rag/terraform.tfstate"`. **The `key` prefix MUST equal the
     `var.projects` map key exactly**, or the role's `s3:prefix` condition denies access — and the
     failure reads as a backend/credentials error, not a naming one.
  3. **`use_lockfile = true` STAYS. Do not add `dynamodb_table`.**
     **⚠️ SUPERSEDED CRITERION — this is the one that would cause a regression.** The old Task 4
     said *"`dynamodb_table` STAYS"* and required *"`backend.tf` still declares `dynamodb_table`,
     now pointing at `global-tofu-lock`."* **Both are VOID.** BR-D22's re-amendment already shipped
     `use_lockfile = true` with no lock table, and `bootstrap/state-backend.tf`'s
     `aws_dynamodb_table.tofu_locks` is already gone. Confirmed live: upstream
     `pipeline_state_policy` grants `s3:GetObject`/`PutObject`/`DeleteObject` on `<project>/*`,
     which **already covers `<key>.tflock`** — so `use_lockfile` works against the org bucket with
     no upstream change and no coupling to `global-tofu-lock` at all.
- **Target Files:** `bootstrap/state-backend.tf`, `environments/ai-lab/backend.tf`
- **Acceptance Criteria:** `tofu plan` reports **`No changes.`** against the new backend **with
  all 12 resources tracked** — ⚠️ **the lab must be UP for this criterion to mean anything**; the
  same plan against an empty state would also pass if the migration had dropped everything.
  Verified **in CI, on the LOCAL role, against the ORG bucket** — exactly one variable changed
  from the last green run. The PR body records the state object's key prefix (not the account id).

---

### Task 4 — Adopt the upstream roles, prove the FULL cycle, then retire the local ones
**(F1, F2, F3, F47 local half; folds in `S1`-T4)**

- **⚠️ BLOCKED ON TASK 0c** being merged **and human-applied**. The role this task adopts does not
  exist until then. The dangerous misreading is to treat the missing role as a blocker to route
  around — pointing CI at the local role and calling it "adopted", or re-adding the upstream entry
  inline without the boundary. Both reopen **F41** in the sprint whose purpose is closing it.
- **⚠️ No other PR may be open across this cutover.** `strict_required_status_checks_policy` is
  `true`, and a PR opened before Task 3's repoint would plan against the old bucket under the new
  role and fail in a way that reads as a credentials problem.

- **Description, in this order and never collapsed:**

  1. **Adopt.** Point `secrets.AWS_OIDC_ROLE_ARN` at `github-actions-bedrock-serverless-rag` and
     add `secrets.AWS_PLAN_ROLE_ARN` for `…-plan`, read from `global-bootstrap`'s
     `github_actions_role_arns` / `github_actions_plan_role_arns` outputs. **Create the new secret
     before the workflow references it**, and **delete the superseded value** rather than leaving
     it standing (a restricted value readable from two places is a wider leak surface than one).
     *(⚠️ Older text here says `vars.AWS_OIDC_ROLE_ARN` / `vars.AWS_PLAN_ROLE_ARN`. That is **dead
     syntax** — `MW`-T6's BR-D21 correction moved every one of this repo's values to `secrets.*`.)*
     *(⚠️ Older text also says "drop `S1`'s `|| vars.AWS_OIDC_ROLE_ARN` fallback." **There is no
     fallback and no `tofu-plan` job to drop it from** — this step **creates** the job.)*

  2. **Build the PR `tofu-plan` job** (normative spec: `S1`-T4's retained body). It inherits every
     rule already binding this repo, and each has bitten before:
     - **Points at the PLAN role from its first commit** — never transiently at
       `secrets.AWS_OIDC_ROLE_ARN`. That would be **F3 reopened in the task that closes it.**
     - SHA-pin `aws-actions/configure-aws-credentials` and `actions/checkout`;
       `persist-credentials: false`.
     - `permissions:` exactly `id-token: write` + `contents: read`, nothing else.
     - **No `name:` override** — this becomes a required check, and a `name:` renames the check
       run and silently un-requires the gate.
     - **Plan output summarized to change counts + resource addresses**, into
       `$GITHUB_STEP_SUMMARY` (BR-D4). Never `-no-color` dumped, **never uploaded as an
       artifact**, never posted as a PR comment — posting back would need `workflow_run` or
       `pull_request_target`, both forbidden, and that remains S1's accepted residual.
     - A guard step asserting the role ARN is non-empty before configuring credentials.

  3. **Verify — the FULL BR-D20 cycle, under the new identity, while the old role still exists.**
     ⚠️ **This replaces the old criterion, which was create-only and in practice a no-op refresh.**
     With the lab already up from Task 2 and state migrated in Task 3, a merge-apply would report
     `No changes.` and prove only that the new role can *read*.
     1. A PR plan job green on the **plan** role → exercises F56 gap b's new workload-read policy.
     2. Dispatch `destroy-ai-lab` on the **apply** role → **exercises the destroy verbs.**
     3. Merge → `tofu-apply` plans `12 to add` and succeeds → **exercises the create verbs.**
     4. Dispatch `destroy-ai-lab` again → lab down for the rest of the sprint.

     Each `AccessDenied` in (2) or (3) is fixed upstream **with a working fallback still in
     place**. Budget for one or two iterations: the destroy path has been exercised exactly once
     in this repo's history, and `state_access_policy`'s own comment says everything further down
     the destroy graph is unmeasured. **Identity is read from the run, never inferred from the
     file** (F56's strengthened criterion).

  4. **Only then delete**, in `bootstrap/`: `aws_iam_role.github_actions_role`,
     `aws_iam_role_policy.state_access_policy` — the **F1** escalation — the Task 3 bridge, and
     `var.role_name` / `var.github_oidc_subject_prefixes`. **Human apply (`bootstrap/`, 2 of 3).**
     *(That second variable was `var.github_repo_path` until `ST-T3`; a coder searching for the old
     name will not find it.)* This deletion also retires `MW`-T5's temporary widen of
     `state_access_policy` (F55) — the whole resource goes away, widen and all.

  5. **Only then require `tofu-plan`** as the seventh check. **BR-D9 makes this three artifacts in
     one change:** the **live ruleset** (`gh api -X PUT …/rulesets/<id>` — **read it first and
     edit it; a partial `PUT` silently drops the rules it omits**, and resolve `<id>` live, never
     from a comment), **`ruleset.required_checks` in `.ai/project.yml`**, and the check list in
     **`.github/workflows/ruleset-drift.yml`**. Order within the step: **create → observe green on
     a real PR → only then require.** Requiring a check before its job has ever reported is the S0
     deadlock; `S1b`-T7 is the worked example of getting it right.
     **⚠️ Bump `.ai/project.yml`'s header date in this PR** — that file's own header says a stale
     date *"makes every skill that reads it report a confident answer about a repo that no longer
     exists,"* and it has gone stale silently before.
     **⚠️ Record R5 (below) at the same time:** a required, credentialed `pull_request` check can
     never pass on a fork PR, so no fork PR can ever merge. That is the same class as the
     path-filter deadlock `CLAUDE.md` already warns about, arriving by a different route.

> ### ⚠️ ENUMERATING THE PLAIN SUBJECT FORM WILL BREAK CI
> **Discovered the hard way in `ST-T3`, and re-measured 2026-08-09.** This repository presents an
> **ID-qualified** subject — `repo:<owner>@<org_id>/<repo>@<repo_id>:<context>` — measured from
> CloudTrail `AssumeRoleWithWebIdentity`, not inferred. A plain `repo:<owner>/<repo>` glob does
> **not** match it; that is what broke CI authentication at the transfer.
> **⚠️ And the rule is narrower than previously written: this is a property of THIS REPOSITORY,
> not of org ownership.** `bounty-infra` is equally org-owned and presents the **plain** form;
> there is no org-level sub-claim template. **`global-bootstrap` builds the plain form for every
> project**, which is why **BR-D27** exists and why Tasks 0a/0c thread a per-project override.
> **Do not trust the API field over the evidence:**
> `gh api repos/<owner>/<repo>/actions/oidc/customization/sub` reports
> `use_immutable_subject: false` for this repository while `sub_claim_prefix` carries the
> ID-qualified value — and the ID-qualified value is what arrives. Read `sub_claim_prefix`, then
> confirm against CloudTrail.

- **Target Files:** `bootstrap/oidc-setup.tf`, `bootstrap/state-backend.tf`,
  `.github/workflows/deploy.yml`, `.github/workflows/ci.yml`,
  `.github/workflows/ruleset-drift.yml`, `.ai/project.yml`, **the live ruleset**
- **Acceptance Criteria:** `grep -rn 'iam:CreateRole\|iam:PutRolePolicy' bootstrap/` returns
  nothing. `aws iam get-role --role-name github-actions-deploy-role` returns `NoSuchEntity`. **The
  four-step cycle in (3) has run green, with run links** — the plan job authenticating as the
  **plan** role and the apply job as the **apply** role, each evidenced by the run, never inferred
  from the file. **The adopted role's trust condition uses `StringEquals`** — read from live AWS,
  not from the upstream HCL. The three required-check lists are **equal as sets**.
  **⚠️ SUPERSEDED CRITERION:** the original *"`deploy.yml` contains no `||` fallback"* is
  satisfiable by the dangerous unblock — pointing the plan job at the apply role removes the
  fallback *and* hands a PR-triggered job apply-capable credentials.

---

### Task 5 — Hand the OIDC provider upstream, then delete `bootstrap/` entirely
**(F40, F43 remainder, F48 by removal, BR-D18)**

*(Merges the old Task 3 with the old Task 4 step 4 and the new deletion work. They merge because
all three end at the same state, all three need one apply, and the old Task 3 could not slip
independently — deleting the directory requires the provider to be out of its state first.)*

- **Description, and the order is load-bearing:**
  1. **Upstream PR:** change `data.aws_iam_openid_connect_provider.github` to a `resource`, with a
     committed `import` block and `lifecycle { prevent_destroy = true }`. Every existing reference
     (`data.….arn` → `aws_iam_openid_connect_provider.github.arn`) updates in the same change.
     **⚠️ BR-D4: the import `id` is a provider ARN and therefore carries the account id, in
     COMMITTED CODE, in a public repository.** Build it from
     `data.aws_caller_identity.current.account_id` — and **verify that OpenTofu accepts an
     expression in `import.id`** rather than assuming it; if it does not, the fallback is a
     variable supplied at apply time, **never a committed literal**.
     **Human apply upstream (3 of 3). Verify a project role can still be assumed afterwards** — an
     OIDC provider *replacement* rather than an import would break every pipeline in the org at
     once. **Paste the plan's action line (`~`/`+`/`-` and the address only) into the PR body**; a
     `+`/`-` pair instead of an import is the signal to stop.
  2. **Re-take the `bootstrap/` state backup out-of-band**, immediately before step 3. #37's
     restore-test passed on 2026-08-07 against a copy taken before `ST-T3`'s narrow; this is a
     different, later state. **Record that it was taken in the PR body** — F48's process finding is
     that a blocking criterion whose only evidence is memory has already failed.
  3. **Here:** `tofu state rm aws_iam_openid_connect_provider.github_actions` and delete the
     resource block. **`state rm`, not `destroy`** — the resource must survive; only this repo's
     claim on it goes away. This is the single operation in this roadmap where the correct verb and
     the dangerous one are the same string.
  4. **Retire the local state bucket:** remove `aws_s3_bucket.tofu_state` and its versioning and
     SSE configuration. *(No lock table — `aws_dynamodb_table.tofu_locks` is already gone under
     BR-D22's re-amendment.)* `prevent_destroy` removal is a deliberate, separate edit in this same
     change. **Human apply (`bootstrap/`, 3 of 3).** **Keep the old bucket until at least one
     successful apply cycle has run on the new backend** (Task 4 step 3 supplies it), and **state
     the date of that cycle in the PR body**. ⚠️ **This is the sprint's one genuinely irreversible
     act** — the bucket holds versioned state history that cannot be recovered.
  5. **Confirm `tofu -chdir=bootstrap state list` is EMPTY**, then delete the directory and every
     reference to it:
     - `rm -r bootstrap/` — including the local `terraform.tfstate` and `terraform.tfvars`.
       **This is what closes F48**, by removal rather than by mitigation.
     - `.ai/project.yml` — drop the `bootstrap` entry from `gates.green` and from `code_paths`,
       **and bump the header date**.
     - `.github/workflows/ci.yml` — drop `bootstrap`'s two `tofu-validate` steps and its `tflint`
       and `checkov` references. ✅ **Verified 2026-08-09 that this cannot rename a required check:**
       `tofu-validate` is one job with sequential steps, **not a matrix**, precisely because
       `S1b`-T7 anticipated that trap.
     - `.tflint.hcl` — **re-enable `terraform_required_version` and `terraform_required_providers`.**
       They are disabled for three reasons; Task 1 removes two and this removes the third, and the
       file records that re-enabling *"needs its own tracked finding and closing task."*
     - `CLAUDE.md` — the `bootstrap/` bullet in *What this is*, the provider-version-split note in
       *Local: OpenTofu* (⚠️ **that split dissolves entirely — with `bootstrap/` gone only
       `~> 5.0` remains, so `S3`-T7's reconciliation has nothing left to reconcile on that axis**),
       and the `bootstrap/`-facing half of the *Pointers* entry for `global-bootstrap`.
- **Target Files:** `bootstrap/` (deleted), upstream `main.tf`, `.ai/project.yml`,
  `.github/workflows/ci.yml`, `.tflint.hcl`, `CLAUDE.md`
- **Acceptance Criteria:** `bootstrap/` does not exist. `grep -rn 'bootstrap/' --exclude-dir=.git .`
  returns only historical references in `sprints/` and the roadmap's finding inventory, which are
  **exempt by name** as historical record. `aws iam list-open-id-connect-providers` still returns
  **exactly one** provider for `token.actions.githubusercontent.com`, and CI still authenticates —
  verified in a real run **after** the state removal. The two tflint rules are enabled and the
  green gate passes with them on.

---

### Task 6 *(OPTIONAL, cheap)* — a scheduled `sub_claim_prefix` drift check

- **Description:** The trust policy now tracks a **GitHub-controlled** value that has already
  changed once without notice (**R2**), and today the only detector is *"CI mysteriously fails."*
  Add ~10 lines to the existing `.github/workflows/ruleset-drift.yml`: read
  `gh api repos/<owner>/<repo>/actions/oidc/customization/sub` and fail if `sub_claim_prefix` does
  not match the recorded expectation.
- **Take it only if Tasks 0–5 land without consuming their apply budget.** It is real value, but
  this sprint is already the largest human-apply surface in the roadmap.

---

## Definition of Done

`gates.green` passes — **with the two re-enabled tflint rules**. Every required check green,
including the newly-required `tofu-plan`. **The full BR-D20 cycle — destroy → apply → verify — has
run on the upstream roles against the org backend**, with run links *(distinct from `MW`'s DoD,
which proved the cycle at all; this proves it still works after the identity and backend swap)*.
The state object in the org bucket is **client-side encrypted** (BR-D22). **`bootstrap/` does not
exist**, and neither do its entries in `gates.green`, `code_paths`, `ci.yml` or `.tflint.hcl`.
`.ai/project.yml`'s header date is current. The **residual register below is filled in and
accurate** — an enumerated residual, never "structurally impossible."
`/way-of-working:critic-gate` has run: **`security-critic`** (every task is a trust boundary or a
credential scope) and **`architect`** (the adopt-verify-delete ordering is where a logic error
becomes an outage), plus **`docs-consistency`** on Task 5, which rewrites three `CLAUDE.md`
sections.

---

## Residual risk register

**ST Task 2b bans the phrase "structurally impossible."** This is what replaces it. Fill in R1's
verification and keep this table accurate as the sprint runs.

| | Residual | Status |
| --- | --- | --- |
| **R1** | The **PR-assumable plan role can read `BUDGET_NOTIFICATION_EMAIL`** — via `budgets:ViewBudget` (which returns the subscriber list) **and** independently via `s3:GetObject` on the state, which stores it. **No grant scoping closes both**, and client-side encryption does not either, since the plan role must decrypt state to plan at all. | **ACCEPTED.** ⚠️ **Verify the premise:** if the notification address is the same as the git commit-author email it is already public in every commit of this public repo, the residual is near zero, **and BR-D21's claim that this repo holds exactly one secret is itself wrong and must be corrected.** History holds 3 distinct addresses, one a personal `@gmail.com`. |
| **R2** | The trust policy tracks a **GitHub-controlled subject shape** that has already changed once without notice, and whose own API field (`use_immutable_subject`) contradicts observed behaviour. | Fail-closed, and strictly preferable to a squattable name-based glob. Detection today is CI failure; **Task 6** would make it a scheduled alarm. |
| **R3** | `aoss:Create/UpdateAccessPolicy` on `*` would let the workload role **rewrite any collection's data-access policy to name itself** — documented in `state_access_policy`'s own comment. | **MUST be scoped in Task 0c.** This is why "derive the verbs, re-derive the resources" is a hard requirement and not a style note. |
| **R4** | The **destroy path has been measured exactly once**; everything further down the destroy graph is unmeasured. Under the new role each gap costs an **upstream** PR and a human apply. | Mitigated by Task 4 step 3's full cycle, run **while the old role still exists as a fallback**. |
| **R5** | A **fork PR can never pass the required `tofu-plan` check**, because a credentialed job gets no OIDC token on a fork — so no fork PR can ever merge. Same class as the path-filter deadlock in `CLAUDE.md`, by a different route. | **ACCEPTED.** Revisit trigger: the first external contributor. |
| **R6** | `bootstrap/`'s state is a single unbacked-up file on one workstation (**F48**) until Task 5 deletes it — and it is the only record of the org-shared OIDC provider. | Backup **re-taken and recorded** immediately before Task 5's `state rm`. Closed by removal at Task 5. |
| **R7** | The permissions boundary constrains **`iam:` verbs only**. S3, AOSS and Bedrock scope comes from the workload policy itself, with no structural backstop. | This is precisely why **R3** is a *must* and not a *should*. Recorded so nobody reads "boundary installed" as "escalation closed." |

---

## Critical review

**Security**

- **The boundary is written HERE, under the pressure of Task 4 being blocked behind it.** ST moved
  it into a sprint with **no irreversible act waiting on it** for exactly this reason. The
  mitigation is that Task 0c's acceptance checks the boundary's **shape** (Task 2b(4)'s allowlist
  grep), not merely that adoption happened — and that a boundary which breaks every apply gets
  **removed rather than corrected**, so getting it right matters more than getting it strict.
- **Adopt-verify-delete, never delete-adopt — and it must cover CAPABILITY, not just identity.**
  This was the single defect the 2026-08-09 pass found in its own first draft: verifying that the
  new role can run an apply, when that apply is a no-op refresh, proves nothing. See Task 4 step 3.
- **Task 0b, not Task 0a, is the blast radius.** The split was originally justified by a `No
  changes.` proof that the operator change makes impossible. Task 0a now genuinely earns it;
  Task 0b earns a different and weaker proof — byte-identical subject arrays plus an **active**
  post-apply check on each sibling.
- **`tofu state rm` in Task 5 is the correct verb and the dangerous one.** `destroy` would delete
  the provider every glunk-works pipeline depends on. One word; the blast radius differs by an
  organization.
- **An OIDC provider `import` that OpenTofu decides is a *replace* is an org-wide outage.** Hence
  pasting the plan's action character into the PR body.
- **F47's local half closes when the local role dies (Task 4); its upstream half does not.** Three
  sibling policies still hold IAM write on `*` in the account that stores bounty-infra's findings
  archive (`glunk-works/global-bootstrap#6`). This sprint must not be read as having fixed that.
- **Attaching our findings `Deny` to our apply role is free here and would NOT be free upstream.**
  bounty-infra's apply role legitimately writes findings. The asymmetry is the reason we create our
  own policy rather than generalising theirs.

**Logic**

- **`No changes.` is the reconciliation criterion — and it is vacuous against an empty state.** An
  apply can succeed while state and reality disagree; only a clean plan proves convergence. But a
  clean plan over **zero tracked resources** proves nothing at all, which is why the lab schedule
  puts the rebuild before the migration.
- **The state `key` prefix must equal the `var.projects` map key.** `bedrock-serverless-rag/…`
  works; `ai-lab/…` silently does not, and the resulting `AccessDenied` during `tofu init` reads as
  a credentials problem, which is a long way from the truth.
- **Encrypt before you migrate.** The org bucket is versioned; the ordering error is permanent and
  silent. This is the second time this sprint's plan has had a step order that produced the exact
  harm the step existed to prevent — the first was the boundary's own escapable construction.
- **Retiring the local state bucket while it is the backend is a bootstrap paradox** — hence
  migrate (Task 3), prove a cycle on the new backend (Task 4), and only then remove the resource
  that used to hold the state describing itself (Task 5).
- **"Derive the verb list from `MW`'s dry run" is correct about verbs and dangerous about
  resources.** The instruction appears in three places in the deep record and none of them says
  which half to copy.

**Execution**

- *A coder agent cannot complete this sprint alone.* It prepares the HCL and the upstream PRs; a
  human applies `bootstrap/` and `global-bootstrap`, runs the state migration, approves or declines
  each rebuild, and confirms the observed-run criteria. Every criterion needing an apply says so.
- *Six human applies and one manual migration is a lot.* If the sprint is running long, **Task 6 is
  the only thing here that can be dropped without leaving a control half-built.**
- *The account id will be tempting to paste* — into the upstream PRs, the import block, the
  boundary ARN, the deletion commands. It is BR-D4 restricted and **both repos are public**. Use
  `data.aws_caller_identity` in HCL and resource *names* in prose.
- *`gh variable list`'s bare form prints values.* This repo's restricted values now live in
  `secrets.*` (BR-D21's GitHub correction), and `gh secret list` never prints values — but the two
  commands look symmetrical and only one is safe.
