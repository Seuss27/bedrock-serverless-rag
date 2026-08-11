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
>    Removing `bootstrap/` in Task 5 deletes **one step** and cannot rename a required check.
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
> **Result: 6 tasks (0–5) plus one OPTIONAL Task 6, 3 upstream human applies, 3 local
> `bootstrap/` human applies, and one
> manual state migration.** That is more human-apply surface than `MW`, `S1a` and `S1b`
> combined — treat any opportunistic addition to this sprint as needing an explicit reason.
> **F61 (floating tool versions) is deliberately NOT taken here**; it is deferred to `S3+S4`.

---

**Sprint Goal:** This repo ends the sprint owning its **workload and nothing else**. No OIDC
provider, no CI role, no state bucket, **and no `bootstrap/` directory** — and state
confidentiality that does not depend on who can read the bucket.

**Closes:** F1 (Critical), F2, F3, F4, F40, F43, **F47 (local half only)**, **F48 (by removal)**,
**F56 (gaps a AND b)**, **F58 (gap b only)**, and the `permissions_boundary` half of **F57**.
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
(`S1a`-T5 removed the `paths:` filter deliberately). Three of this sprint's PRs (0a, 0b, 0c) are
against `glunk-works/global-bootstrap` and queue nothing here, so that is roughly five
prompts and only two of them should be accepted.

---

## Tasks

### Task 0 — Re-create the upstream project entry, WITH the boundary
**(F56 gaps a+b, F58 gap b, F2, BR-D27) — BLOCKING**
*(⚠️ F57's `permissions_boundary` half is **Task 1's**, not this task's — it is the module
attribute on `bedrock_kb_role`, not the upstream policy. Corrected 2026-08-09.)*

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
  1. `variables.tf` — add **two** optional keys to the `projects` object:
     `oidc_subject_prefix = optional(string, null)` (BR-D27), and
     `extra_plan_oidc_subjects = optional(list(string), [])`. **The second closes F56 gap (a)**
     and is not optional work — see the box under Task 0b. Declared here, *consumed* in Task 0b,
     so this PR stays a no-op.
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

#### Task 0b — upstream: the two trust-policy shape changes (F2, **F56 gap a**)

- **Description:** The PR that accepts in-place trust-policy diffs. Both changes below are
  behaviour-preserving for the three sibling projects and are verified the same way.
  1. **`main.tf` — `StringLike` → `StringEquals` on the apply role (F2).** F2's entire substance
     is that *in IAM `StringLike`, `*` matches `:` too* — so an `extra_oidc_subjects` entry
     containing a `*` would glob silently. Every rendered value is wildcard-free today, which makes
     this behaviour-preserving; it is **not** cosmetic, because it removes the mechanism rather
     than relying on the values staying clean.
  2. **`plan_roles.tf` — consume `extra_plan_oidc_subjects` (F56 gap a).** Today the plan role's
     subject is a **bare string**, `"repo:<org>/<repo>:pull_request"`, with no way to add another.
     Replace it with `concat(["${local.subject_prefix[each.key]}:pull_request"], [for s in
     each.value.extra_plan_oidc_subjects : "${local.subject_prefix[each.key]}:${s}"])`.
     ⚠️ **This renders a one-element list where a bare string stood, for every existing plan role
     — which IS a plan diff, and is why it lives here and not in Task 0a.** It is nonetheless
     behaviour-identical: **IAM treats a condition value as a set, so a one-element list and a
     bare string are equivalent** (`bootstrap/oidc-setup.tf` states the same thing for the same
     reason). Keep `StringEquals` — the plan role already uses it correctly.

> ### 🔴 Why F56 gap (a) is closed HERE, and not deferred
> **Found 2026-08-09 by this plan's `docs-consistency` pass.** The first draft of this sprint
> addressed only F56 gap (b) — the missing workload read policy — while still claiming
> `Closes: F56` unqualified. Gap (a) is that the plan role trusts **only** `:pull_request`, so no
> push-triggered job can ever assume it. That is not a latent nuisance: `deploy.yml`'s shipped
> `tofu-plan-main` job is **push-triggered** and carries
> `${{ secrets.AWS_PLAN_ROLE_ARN || secrets.AWS_OIDC_ROLE_ARN }}`, so **Task 4 step 1's act of
> creating that secret would silently repoint it at a role it cannot assume and break every merge
> to `main`.** Closing gap (a) here is what makes Task 4 safe. Task 0c then sets
> `extra_plan_oidc_subjects = ["ref:refs/heads/main"]` for this project.
> **This is a read-only role**, so trusting the `main` ref costs nothing that
> `:pull_request` did not already cost — the containment is the policy, not the trigger.
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
- **Target Files:** upstream `main.tf`, `plan_roles.tf`
- **Acceptance Criteria:** Plan shows **only** in-place updates to
  `aws_iam_role.github_actions_role[*]` and `aws_iam_role.github_actions_plan_role[*]`,
  **zero replacements**, nothing created or destroyed.
  Both verification halves above are recorded in the PR body. **Human apply upstream (1 of 3).**
  Rollback stated in the PR body: revert and re-apply.

---

#### Task 0c — upstream: this project's entry, the boundary, and our findings `Deny`

- **Description:** An upstream PR re-adding the entry, per **ST Task 2b**:
  1. **`variables.tf`** — `"bedrock-serverless-rag" = { repo_name = …, plan_role = true,
     extra_oidc_subjects = ["environment:production"],
     extra_plan_oidc_subjects = ["ref:refs/heads/main"], oidc_subject_prefix = <ID-qualified> }`.
     ⚠️ **`extra_plan_oidc_subjects` is what lets `deploy.yml`'s push-triggered `tofu-plan-main`
     assume the plan role at all** — without it, Task 4 step 1 breaks every merge to `main`. See
     the box under Task 0b.
     The prefix value is **not BR-D4 restricted** — a public org name, a public repo name, and two
     GitHub numeric ids readable with `gh api repos/<owner>/<repo> --jq '.id, .owner.id'`.
  1b. **The state-encryption KMS key (BR-D22) — upstream, and this is a decision, not a detail.**
     ⚠️ **Found 2026-08-09: the repo has ZERO `kms:` grants anywhere** (`state_access_policy`,
     upstream `pipeline_state_policy`, upstream `plan_state_read_policy` — none), and **no key
     exists**. BR-D22 says *"upstream owns the key-provider choice (filed as an issue, § 9.4)"* —
     but no such upstream issue is open, so that clause is aspirational, not a dependency anyone
     is discharging. **Task 2 cannot adopt an `aws_kms` key provider without one.**
     **Decision: the key is created UPSTREAM, beside the state bucket.** It follows directly from
     BR-D17 (`global-bootstrap` owns state) and from the one alternative being fatal — a key
     declared in `environments/ai-lab` would be **destroyed by `destroy-ai-lab` along with the
     state it decrypts**, which BR-D20's cycle runs routinely. Add the key here, and grant
     `kms:Decrypt`/`GenerateDataKey`/`DescribeKey` on it to **both** this project's roles (step 2
     and step 3 policies). ⚠️ **`bootstrap/`'s local role needs the same grant for the Task 2/3
     window** — that half is Task 2's, not this task's.
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

> ## BANNER — 2026-08-10: the body below is executable; its step 1 has been REWRITTEN.
>
> The task body's approach is unchanged and correct. **Step 1 of the second bullet was
> rewritten in place** — it asserted "this repo has zero `kms:` grants anywhere today", which
> PR #106 made false, and this banner previously certified the body as correct without
> noticing. Per CLAUDE.md's convention the body is rewritten to agree with the banner rather
> than left to be overridden by it. This banner adds the measured behaviour the body does not
> mention, plus the state of the half that already shipped.
>
> **THE GAP: `deploy.yml` needs a new secret, or all three of its jobs fail on the merge that
> adds the encryption block.** `tofu-plan-main`, `tofu-apply` and `destroy-ai-lab` each run a
> **real** `tofu init`, which evaluates the encryption block and therefore resolves
> `var.state_kms_key_arn`. Unset, init fails with `Unable to compute static value` /
> `encryption.key_provider.aws_kms.state depends on var.state_kms_key_arn`. Each job needs
> `TF_VAR_state_kms_key_arn` in its `env:` block, from a **`secrets.*`** value — a `vars.*` one
> is dumped into every step's log preamble (BR-D21's measured GitHub Actions exception, same
> reason the three existing `TF_VAR_`s there ride `secrets.*`). **The secret must exist before
> the PR merges.**
>
> **`ci.yml`'s `tofu-validate` is NOT affected — measured, because the opposite was plausible
> enough to be reported as a blocker and then withdrawn the same day.** `tofu validate` runs
> `tofu init -backend=false`, and **`-backend=false` does not evaluate the encryption block at
> all**: no KMS call, no credentials, and the variable need not be set. Measured on a clean
> checkout (2026-08-10):
>
> | encryption block | variable | credentials | backend | result |
> |---|---|---|---|---|
> | no | — | none | `-backend=false` | pass |
> | yes | set | none | `-backend=false` | pass |
> | yes | **unset** | none | `-backend=false` | pass |
> | yes | unset | admin SSO | real | **fails — needs the variable** |
>
> So the required check stays green, on fork PRs too, and **nothing here justifies putting AWS
> credentials into `ci.yml`** — that would put a credentialed job back on `pull_request`, which
> is F3's exploitable instance, closed by S1b-T2. Any future reasoning that arrives there has
> gone wrong.
>
> **⚠️ DO NOT MEASURE THIS LOCALLY IN AN ALREADY-INITIALIZED DIRECTORY — it reports a false
> blocker.** `environments/ai-lab/.terraform` on a workstation names the S3 backend, so
> `init -backend=false` reaches for the backend and dies on
> `No valid credential sources found` **whether or not an encryption block exists** — which
> reads exactly like "the encryption block requires credentials". `CLAUDE.md` documents this
> wrinkle and says `-reconfigure` fixes it; **it does not** (measured 2026-08-10 — the flag
> does not clear the recorded backend). Test from a clean copy, or move `.terraform` aside
> first. CI is unaffected because it checks out clean.
>
> **⚠️ WHAT IS ALREADY DONE AND IS *NOT* REVERTED — Task 2 is half-executed.**
> - The `bootstrap/` human apply **landed** (PR #106 merged as `02fd1f8`, applied under admin
>   SSO 2026-08-10). `StateEncryptionKeyAccess` and `StateMigrationBridge` are **live on the
>   local `github-actions-deploy-role`** — verified by `aws iam list-role-policies` and
>   `tofu state list`. Do **not** re-apply or revert them: Task 3's bridge half is needed
>   regardless of how the encryption half is re-scoped. The consequence to carry forward is
>   that `bootstrap/state-migration.tf`'s two recorded residuals are live for **longer than the
>   Task 2 → Task 4 window they were scoped against**.
> - `s3://personal-bedrock-lab-state/environments/ai-lab/terraform.tfstate` was **deleted**
>   (delete marker `54D0hIt0…`, versioning Enabled so the prior version survives). It held
>   **zero resources** — a 373-byte empty skeleton — so nothing was lost, and it need not be
>   restored. **This is what lets the block ship with no `fallback`:** OpenTofu refuses to read
>   plaintext state once an encryption block exists, so the usual adoption path is a `fallback`
>   to an `unencrypted` method, applied once, then stripped in a second PR. With no state
>   object at all there is nothing to read, so the first apply writes ciphertext from scratch —
>   BR-D20's "prefer rebuilding correctly over migrating carefully" applied to the one artifact
>   that is normally the exception. **The consequence to know before debugging a future init
>   failure: no configuration in this root will read a plaintext state object.** If one appears,
>   it is new — the question is where it came from, not what fallback to add.

- **⚠️ This must precede the migration, and the reason is permanent.** The org bucket has
  **versioning Enabled**. Migrating first and encrypting second — the old Task 4's step order —
  writes a **plaintext state version into the org bucket that persists forever**. Encrypting
  first means the migration's write is already ciphertext, and the old bucket's plaintext
  versions die with the bucket in Task 5.
- **⚠️ This task carries a `bootstrap/` human apply, and it grants TWO things at once — that is
  deliberate, and it is what keeps the sprint at three local applies.** *(Added 2026-08-09 by the
  `docs-consistency` pass, which found the encryption task had no key and no grant behind it.)*
  1. **`kms:Decrypt` / `GenerateDataKey` / `DescribeKey`** on the key Task 0c step 1b created
     upstream. **Without this the encryption block breaks `tofu-plan-main` on the very next
     merge** — every real `tofu init` evaluates the encryption block and calls KMS.
     ~~and this repo has **zero `kms:` grants anywhere** today~~ **✅ DONE 2026-08-10, and the
     struck clause is now false:** PR #106 (`02fd1f8`) merged and was human-applied, so
     `StateEncryptionKeyAccess` is live on `github-actions-deploy-role`. This half of the task
     is spent — do not re-apply it. *(Corrected after a `docs-consistency` pass caught this
     body still asserting the pre-#106 state underneath a banner certifying the body as
     correct — the precise rot CLAUDE.md retired "the banner wins" over.)*
     ⚠️ Note the mechanism is **write**, not read, for the immediate case: the state object was
     deleted, so the next apply has nothing to decrypt and needs `GenerateDataKey` to write
     ciphertext from scratch. Both verbs are granted; only the reasoning changes.
  2. **The read-only org-bucket bridge policy Task 3 needs** — created here rather than in Task 3
     so both grants ride one apply. It sits unused for one task, which costs nothing: it is
     read-only, scoped to this project's own prefix, and grants access to a *copy* of state the
     role already fully controls in the local bucket. Its full specification stays in **Task 3**.
- **Description:** Then add a `terraform { encryption { … } }` block with an `aws_kms` key
  provider — pointed at the **upstream** key — to **`environments/ai-lab` only**.
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
  1. **The bridge — specified here, but APPLIED IN TASK 2** (which already needs a `bootstrap/`
     apply for the KMS grant, so both ride one). A **new, separately named** `aws_iam_role_policy`
     — e.g. `state_migration_bridge`. **Not an edit inside `state_access_policy`:** a distinct
     resource makes the temporary thing visible, and its removal is a deletion rather than surgery
     on a hundred-line policy. It dies with the role in Task 4 either way.
     **⚠️ READ-ONLY.** `s3:GetObject` on `<org-bucket>/bedrock-serverless-rag/*`, and
     `s3:ListBucket` on the bucket **with the `StringLike s3:prefix` condition copied verbatim
     from `pipeline_state_policy`**. Without that condition it enumerates every project's state
     keys. No `PutObject`, no `DeleteObject`: the migration itself is a **human, local, admin-SSO**
     operation, and the first CI **write** to the org bucket happens under the upstream apply role
     in Task 4. Verification here is `tofu plan -lock=false`.
     *Record in the resource's comment why this is not a privilege increase: it grants read on a
     **copy** of state the role already has full access to in the local bucket. Net new exposure
     is zero — provided the prefix condition is present.* **Applied in Task 2 (`bootstrap/`, 1 of 3)** — no separate apply here.
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
     > **🔴 CORRECTED 2026-08-09 by this plan's own `docs-consistency` pass — the first draft of
     > this step asserted "there is no fallback and no `tofu-plan` job to drop it from," and
     > BOTH halves are false. Measured at `deploy.yml:105`:**
     > ```yaml
     > role-to-assume: ${{ secrets.AWS_PLAN_ROLE_ARN || secrets.AWS_OIDC_ROLE_ARN }}
     > ```
     > **The fallback exists, in the `tofu-plan-main` job** — which is real, shipped, and
     > triggered by **`push: branches: [main]`**, not by `pull_request`. (The first draft
     > conflated *"no PR-triggered plan job"* with *"no plan job."*) `S1`-T5 left the `||`
     > deliberately, and `deploy.yml:100-102` states the intended mechanism: *"the `||` shape
     > means S2-T2 flips this by creating the secret, with no workflow edit."*
     >
     > **⚠️ THAT MECHANISM IS A LIVE BREAK, and this step would trigger it.** `tofu-plan-main`
     > presents `…:ref:refs/heads/main`, while upstream `plan_roles.tf` trusts **only**
     > `…:pull_request` under `StringEquals` — **that is exactly F56 gap (a)**. So the instant
     > `secrets.AWS_PLAN_ROLE_ARN` exists, a push-triggered job silently repoints itself at a
     > role it cannot assume, and **every merge to `main` fails at credential configuration**,
     > with no workflow edit anywhere to point at.
     >
     > **Therefore: F56 gap (a) must be closed in Task 0a BEFORE this secret is created.** If for
     > any reason it is not, `tofu-plan-main` must be **pinned to `secrets.AWS_OIDC_ROLE_ARN` in
     > the same commit that creates the plan secret** — never left on the `||`. Pinning is the
     > lesser evil and still a **BR-D7 violation in spirit** (a plan job holding apply-capable
     > credentials); it is not F3, which is specifically about `pull_request` triggers.

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
     - **`tofu plan -lock=false`.** With `use_lockfile = true` and a read-only plan role whose
       upstream policy has `GetObject`/`ListBucket` but **no `PutObject`**, a plan that takes the
       lock fails outright. `deploy.yml:111-118` and upstream `plan_roles.tf`'s own comment both
       already do this — inherit it as the job inherits the other five rules.
     - **⚠️ IT CANNOT LIVE IN `ci.yml`, AND IT CANNOT LIVE IN `deploy.yml`.** *(Found 2026-08-09
       by this plan's `docs-consistency` pass.)* `ci.yml`'s header declares it *uncredentialed by
       construction (`S1b`-T2): no job here holds `id-token: write` or any AWS secret … anything
       that needs AWS credentials belongs in `deploy.yml`* — and `deploy.yml` has **no
       `pull_request` trigger at all**, deliberately. **So this job needs a THIRD workflow file**
       (e.g. `plan.yml`), and `ci.yml`'s header invariant must be amended **in the same PR** to
       say where credentialed PR-time work now lives. Silently adding a credentialed job to
       `ci.yml` would falsify that header, which `CLAUDE.md` also states as repo-wide truth.

  3. **Verify — the FULL BR-D20 cycle, under the new identity, while the old role still exists.**
     ⚠️ **This replaces the old criterion, which was create-only and in practice a no-op refresh.**
     With the lab already up from Task 2 and state migrated in Task 3, a merge-apply would report
     `No changes.` and prove only that the new role can *read*.

     > **⚠️ CORRECTED 2026-08-11 by `S2`-T4 PR A — the sub-order below assumed the lab was
     > already up.** It is not: `destroy-ai-lab` (dispatch `31337481993`) tore all 12 resources
     > down 2026-08-09, and no apply has succeeded since. The original order put a
     > `destroy-ai-lab` dispatch **second**, before anything had been built on the new identity
     > — against an empty lab, that step is a `No changes.` no-op and proves nothing about the
     > destroy verbs. **The body below is rewritten to match; this banner is the record of why.**

     1. A PR plan job green on the **plan** role → exercises F56 gap b's new workload-read policy.
     2. Merge → `tofu-apply` plans `12 to add` and succeeds, on the **apply** role → **exercises
        the create verbs**, against a real empty-to-populated lab rather than a no-op.
     3. Dispatch `destroy-ai-lab` on the **apply** role → **exercises the destroy verbs** —
        now against a lab that actually holds the 12 resources step 2 just created.
     4. Lab down for the rest of the sprint — no further dispatch needed; (3) already leaves it
        there.

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
  `.github/workflows/deploy.yml`, **a new `.github/workflows/plan.yml`**, `.github/workflows/ci.yml`
  *(header amendment only)*,
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
     - `.github/workflows/ci.yml` — drop `bootstrap`'s `tofu-validate` step and its `tflint`
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
       ⚠️ **Do not stop at three sections** — `CLAUDE.md` mentions `bootstrap/` **six** times,
       including inside the § *Commands* block (`# bootstrap/providers.tf sets no profile (F49)`).
       Grep the file; do not work from this list.
     - **`.github/CODEOWNERS`** — carries `/bootstrap/ @<owner>`, a rule for a path that will no
       longer exist. *(Missed by the first draft entirely; found 2026-08-09.)*
     - `environments/ai-lab/backend.tf`'s comment referencing `bootstrap/state-backend.tf` —
       rewritten by Task 3 anyway, but confirm it is gone.
- **Target Files:** `bootstrap/` (deleted), upstream `main.tf`, `.ai/project.yml`,
  `.github/workflows/ci.yml`, `.tflint.hcl`, `CLAUDE.md`
- **Acceptance Criteria:** `bootstrap/` does not exist. A **scoped** grep — excluding `.git`,
  `sprints/`, `.ai/archive/`, `docs/hardening_roadmap.md` and any `.venv` —
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
| **R1** | The **PR-assumable plan role can read `BUDGET_NOTIFICATION_EMAIL`** — via `budgets:ViewBudget` (which returns the subscriber list) **and** independently via `s3:GetObject` on the state, which stores it. **No grant scoping closes both**, and client-side encryption does not either, since the plan role must decrypt state to plan at all. | **ACCEPTED.** ⚠️ **Verify the premise:** if the notification address is the same as the git commit-author email it is already public in every commit of this public repo, the residual is near zero, **and BR-D21's claim that this repo holds exactly one secret is itself wrong and must be corrected.** History holds one personal `@gmail.com` among its author/committer addresses. |
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
