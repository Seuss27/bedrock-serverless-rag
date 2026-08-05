### FILEPATH: /sprints/ST_org_transfer/sprint_plan.md

# ST — Organization transfer (`Seuss27/` → `glunk-works/`)

**Sprint Goal:** Move the repository into the `glunk-works` organization **without opening an
escalation path into the shared AWS account and without leaving CI unable to authenticate**.

**Closes:** F44, F45, and the stopgap half of F40. Executes **BR-D13**.

**Dependencies:** **S0 must be merged** — the governance baseline is cheap to re-verify after
a transfer and expensive to redo, so it lands first. **Task 0 gates every apply in this
sprint** (F50). **S1 and S2 must NOT have run yet**:
repository variables do not survive a transfer, and the owner name is inside every OIDC
subject, so doing S1's Environment/variable work first means doing it twice.

**Security Considerations:** This sprint's central risk is not the transfer failing — it is
the transfer **succeeding**, quietly, with a side effect nobody reviewed.

> ### ⚠️ F45 — the transfer switches on a dormant, over-privileged role
>
> `glunk-works/global-bootstrap` already generates `github-actions-bedrock-serverless-rag`
> from `var.projects`. Its trust subject is
> `repo:glunk-works/bedrock-serverless-rag:ref:refs/heads/main`. **Today that matches
> nothing**, because this repo is `Seuss27/…`. The instant the transfer completes, it
> matches — and that role carries `lambda:*`, `apigateway:*` (**F42**) plus
> `iam:CreateRole` / `iam:PutRolePolicy` / `iam:AttachRolePolicy` / `iam:PassRole` on
> `Resource = "*"` (**F41**), in an account that also holds **bounty-infra's KMS-encrypted
> findings archive** (**F47**).
>
> So a repository-settings change, with **no IaC diff anywhere**, creates a new path to
> account administrator. **Task 2 must land upstream before Task 3 runs.** Not after, not in
> parallel.

**Risks & Blockers:**
- Requires **org owner** permission on `glunk-works` and admin on the source repo. A transfer
  into an organization you do not own silently fails at the confirmation step.
- Requires a **human `tofu apply` in `bootstrap/`** (BR-D1) for Task 1 and Task 4, and a
  human apply of **`global-bootstrap`** for Task 2. Neither is a CI operation.
- A coder agent can prepare every file and command here, but **must not perform the transfer
  itself** — it is irreversible in practice (the old URL redirects, and re-transferring back
  is a second irreversible act, not an undo).

---

## Tasks

- **Task 0 (blocking): Reconcile `bootstrap/`'s drift before ANY apply here (F50)**
  - **Description:** `tofu apply` in `bootstrap/` is **not** currently a no-op. A live plan on
    2026-08-05 reports **`1 to change`**: it removes `iam:ListAttachedRolePolicies` from
    `state_access_policy`. That action exists in the **live** AWS policy and not in the
    committed HCL, and no commit ever added it — it was granted out-of-band.
    **Why this blocks the sprint:** Tasks 1 and 3 both call for a human `tofu apply` in
    `bootstrap/` for unrelated reasons (a lifecycle guard, an OIDC trust widening). Either
    apply would carry this revocation along, unreviewed. CI would then start failing on a
    refresh, and the trust-policy change — the thing that *did* just change — would take the
    blame. That misattribution is the expensive part, not the missing permission.
    **Resolution: commit the action.** It is needed — the AWS provider calls
    `ListAttachedRolePolicies` when refreshing an `aws_iam_role`, which CI does for
    `bedrock_kb_role` on every plan. Add `"iam:ListAttachedRolePolicies"` to the action list
    in `bootstrap/state-backend.tf` so the code matches live, then confirm the plan is clean.
    Do **not** resolve it the other way (letting the apply remove it) without first proving
    nothing needs it — the evidence says something does.
  - **Target Files:** `bootstrap/state-backend.tf`
  - **Acceptance Criteria:** `AWS_PROFILE=admin-sso tofu plan` in `bootstrap/` reports
    **`No changes.`** That is the gate for every later apply in this sprint: **if plan is not
    clean, do not apply.** Re-run it immediately before each of Task 1's and Task 3's applies,
    not just once at the start — `bootstrap/` has no CI and no review, so drift can reappear
    between tasks.

- **Task 1: Stop this repo from being able to break the organization (F40 stopgap)**
  - **⚠️ Task 0 must show `No changes.` first.** This task needs no apply of its own (a
    `lifecycle` block produces no diff), but if you do apply for any reason, F50 rides along.
  - **Description:** Confirmed 2026-08-05: this repo's `bootstrap/` and `global-bootstrap`
    share **one** AWS account. An account holds exactly one OIDC provider per URL, and this
    repo **creates** the one `global-bootstrap` reads as a `data` source — so this repo's
    OpenTofu state owns the federation endpoint every glunk-works pipeline authenticates
    through, with no protection against deletion.
    Add, and have a human apply:
    ```hcl
    resource "aws_iam_openid_connect_provider" "github_actions" {
      # ...
      lifecycle {
        prevent_destroy = true
      }
    }
    ```
    Add a comment above it stating **why**: this resource is shared org-wide, `global-bootstrap`
    consumes it via `data.aws_iam_openid_connect_provider.github`, and destroying it breaks CI
    for every glunk-works repository. Reference BR-D18 — ownership moves upstream in S2; this
    is the stopgap until it does.
    **Do this first, before anything else in this sprint.** It is one line against a standing
    organization-wide outage risk and it depends on nothing.
  - **Target Files:** `bootstrap/oidc-setup.tf`
  - **Acceptance Criteria:** `tofu plan` in `bootstrap/` reports `No changes.` — a `lifecycle`
    meta-argument produces no diff, so this is both the "nothing else changed" check and the
    F50 gate. A deliberate destroy is **refused**:
    `tofu plan -destroy '-target=aws_iam_openid_connect_provider.github_actions'` must fail
    with `Instance cannot be destroyed … lifecycle.prevent_destroy set`. **Verify it, do not
    assume it. ✅ VERIFIED 2026-08-05 against live state (PR #17).** No apply is required.
    Note for a PowerShell operator: quote the `-target=…` argument (or use `--%`), or
    PowerShell splits it at the `.` and tofu rejects it as an incomplete resource address.
    `bootstrap/providers.tf` also sets no `profile`, so `$env:AWS_PROFILE = "admin-sso"` must
    be set in the shell first (F49).

- **Task 2: Fix the upstream project entry BEFORE the transfer (F45, F42)**
  - **Description:** A pull request against **`glunk-works/global-bootstrap`**. Two changes,
    and the second is the one that must not be skipped:
    1. **`variables.tf`** — update the `bedrock-serverless-rag` entry in `var.projects`:
       ```hcl
       "bedrock-serverless-rag" = {
         repo_name = "bedrock-serverless-rag"
         plan_role = true                              # S1/S2 need a read-only PR-time role
         extra_oidc_subjects = ["environment:production"]  # S1-T5's gated apply job
       }
       ```
       Both keys already exist in the schema and are documented there; this is using the
       mechanism, not extending it.
    2. **`project_policies.tf`** — replace `bedrock_rag_policy` entirely. The current grant
       (`lambda:*`, `apigateway:*`, `bedrock:InvokeModel`) describes a serverless API and
       **not this workload** (F42), and it carries the F41 escalation
       (`iam:CreateRole`/`PutRolePolicy`/`AttachRolePolicy`/`PassRole` on `Resource = "*"`).
       The replacement must cover what the module actually declares — S3 bucket lifecycle,
       `aoss:*` including the **access-policy** verbs, `bedrock:CreateKnowledgeBase` /
       `CreateDataSource` and their delete/get counterparts, and the IAM verbs the KB
       execution role needs — with the escalation closed by the same construction proposed
       for F41 upstream: a **permissions-boundary policy**, an IAM **role-path** scope
       (`arn:aws:iam::<acct>:role/bedrock-rag/*`), an `iam:PermissionsBoundary` **condition**
       on the mutating IAM verbs, `iam:PassRole` conditioned on
       `iam:PassedToService = bedrock.amazonaws.com`, and an explicit **`Deny`** on
       `iam:CreatePolicyVersion` / `SetDefaultPolicyVersion` / `PutRolePermissionsBoundary` /
       `DeleteRolePermissionsBoundary` and on any `iam:*` targeting the boundary policy, the
       `github-actions-*` roles, or the OIDC provider.
       Also add, to the **apply** role's policy, the `DenyBountyFindingsDataAccess` statement
       that `plan_roles.tf` already applies to the plan roles — the control exists upstream
       and is currently only on the weaker role class (F47).
    Open the F41 issue in the same visit, covering the other three project policies.
  - **Target Files:** `glunk-works/global-bootstrap`: `variables.tf`, `project_policies.tf`
    (an upstream PR — not files in this repo)
  - **Acceptance Criteria:** The upstream PR is **merged and applied by a human** before Task
    3 begins. `aws iam get-policy-version` for `glunk-works-bedrock-rag-workload` shows no
    `Allow` with `Resource = "*"` on an `iam:` action. `aws iam list-roles --path-prefix /bedrock-rag/`
    is the only path the policy can create into. The F41 issue exists and is linked from
    `docs/hardening_roadmap.md` § 9.4. **Do not start Task 3 until this is applied** — record
    the applied timestamp in the sprint's PR body.

- **Task 3: Widen the trust policy, then transfer (never the other order)**
  - **Description:** The transfer changes every OIDC subject this repo presents, from
    `repo:Seuss27/bedrock-serverless-rag:…` to `repo:glunk-works/bedrock-serverless-rag:…`.
    Use the widen-then-narrow discipline, in **three** separate steps with verification
    between each:
    1. **Widen** (human apply, `bootstrap/`): change `var.github_repo_path`'s consumer so the
       trust condition accepts **both** owners. Since F2 is not yet fixed at this point, the
       existing `StringLike "repo:${var.github_repo_path}:*"` already matches anything under
       the old owner — so add a second condition entry for the new owner rather than editing
       the old one. Verify CI still authenticates on the current owner.
    2. **Transfer** — repo Settings → Danger Zone → Transfer, target `glunk-works`. **Human
       only.**
    3. **Verify, then narrow** — once every workflow authenticates under the new owner,
       remove the old-owner entry in a second human apply.
    **Never** swap old for new in one apply: if any subject is wrong, CI cannot authenticate
    and cannot self-correct, and the fix needs local admin credentials.
  - **Target Files:** `bootstrap/oidc-setup.tf`
  - **Acceptance Criteria:** After step 3, a PR run and a merge-to-`main` run have both
    authenticated to AWS under `glunk-works/…` — **observed in a workflow run, not inferred
    from the policy text**. No `repo:Seuss27/` string remains in any trust policy. The
    `github-actions-bedrock-serverless-rag` role, now reachable, resolves to the **corrected**
    policy from Task 2 — verify by reading the attached policy ARN, not by assuming Task 2
    took effect.

- **Task 4: Re-establish everything the transfer did not carry**
  - **Description:** A transfer moves the repository record, its issues, pull requests,
    releases and stars. It does **not** reliably carry the settings this roadmap depends on.
    Treat every item below as **absent until observed present**, and re-create what is
    missing:
    - **Repository variables** (`AWS_OIDC_ROLE_ARN`, `AWS_PLAN_ROLE_ARN`,
      `DATA_SOURCE_BUCKET_NAME`) and **secrets** — assume gone; re-set them, pointing at the
      role ARNs `global-bootstrap` now outputs (`github_actions_role_arns` and
      `github_actions_plan_role_arns`).
    - **The ruleset** from S0-T1 — re-verify with
      `gh api repos/glunk-works/bedrock-serverless-rag/rules/branches/main`; re-create from
      the S0 payload if absent, and update `.ai/project.yml` either way.
    - **Merge settings** from S0-T2 (`squash_merge_commit_title=PR_TITLE`,
      `delete_branch_on_merge`) — re-apply the `gh api -X PATCH`.
    - **Labels** from S0-T3 — org repos may inherit a different default set.
    - **Environments** — none exist yet (`total_count: 0` as of 2026-08-05), so nothing to
      restore; S1-T5 creates `production` **after** this sprint, under the new owner.
    - **Org-level rulesets and policies** may now *additionally* apply. Check
      `gh api orgs/glunk-works/rulesets` and reconcile: an org rule requiring a check this
      repo does not produce would deadlock every PR, exactly as in BR-D9.
    Then update every place the old path is written down: `.ai/project.yml`'s `repo:` key,
    `docs/hardening_roadmap.md` (the `gh api` examples), `README.md`, the issue-template
    `config.yml` discussions URL, and any badge.
  - **Target Files:** `.ai/project.yml`, `docs/hardening_roadmap.md`, `README.md`,
    `.github/ISSUE_TEMPLATE/config.yml`, `CLAUDE.md`
  - **Acceptance Criteria:** `grep -rn 'Seuss27' . --exclude-dir=.git` returns **nothing**
    (the CODEOWNERS entry becomes the org handle or the user's org membership). Every S0
    acceptance criterion re-verified green under the new owner — re-run them, do not assume
    they survived. `gh api orgs/glunk-works/rulesets` has been read and any interaction with
    the repo ruleset is recorded in the PR body.

- **Task 5: Record the outcome**
  - **Description:** Update `docs/hardening_roadmap.md`: mark **BR-D13 executed** with the
    transfer date, note in **F44/F45** what was verified, and add a status-log row. Update
    `.ai/project.yml`'s `repo:` comment — the long note explaining why the value is
    `Seuss27/…` becomes wrong the moment this sprint lands, and a stale explanation of a
    decision is worse than none.
  - **Target Files:** `docs/hardening_roadmap.md`, `.ai/project.yml`
  - **Acceptance Criteria:** No document claims the repo is at `Seuss27/`. `.ai/project.yml`'s
    `repo:` is `glunk-works/bedrock-serverless-rag` and its comment describes the *current*
    state. `docs-consistency` finds no contradiction across `load_bearing_docs`.

---

## Definition of Done

`gates.green` passes. Every S0 required check is green **under the new owner**. CI has
authenticated to AWS from `glunk-works/…` in a real run. The upstream `global-bootstrap` PR
is merged **and applied**. `/critic-gate` has run — propose `security-critic` (F45 is the
entire reason this sprint has an ordering constraint) and `docs-consistency` (Task 4 rewrites
the repo path across every load-bearing document).

---

## Critical review

**Security**

- **The dangerous step is the one with no diff.** Every other sprint's risk is reviewable as
  code; this one's headline risk (F45) is a settings change whose consequence lives in
  *another repository's* IaC. That is why Task 2 is a blocking prerequisite with a recorded
  applied-timestamp rather than a "do this too" bullet — an ordering that exists only as
  prose in a plan is an ordering that gets reversed under time pressure.
- *Task 1 looks trivial and is the highest value-per-line change in the whole roadmap.* One
  `prevent_destroy` closes a path where a routine `tofu destroy` in a personal lab repo takes
  down CI for every glunk-works repository. It depends on nothing and should not wait for the
  rest of the sprint.
- *`prevent_destroy` does not protect against `tofu state rm` followed by a console delete*,
  and it is not a substitute for BR-D18. It is explicitly labelled a stopgap in both the code
  comment and the decision, so that S2 does not later find a "protected" resource and
  conclude the problem was solved.
- *The transfer widens who can reach the shared account*, beyond F45: org members with write
  access to the transferred repo can push branches, and once S1's gated apply exists, merge
  to `main`. That is the intended posture for an org repo, but it is a real change from a
  single-owner personal repo and should be a conscious one — check `glunk-works`' base
  member permissions before transferring, not after.
- *Task 3's widen step deliberately leaves the F2 glob in place for the duration.* That is a
  known, temporary weakening — the glob already admits every subject under the old owner, so
  the widen adds only the new owner's. Narrowing to enumerated subjects is S2's job and must
  not be attempted mid-transfer, when a mistake cannot be diagnosed from CI.

**Logic**

- **Repository variables not surviving a transfer is the reason ST precedes S1**, not a
  detail of Task 4. S1 sets `AWS_PLAN_ROLE_ARN`, creates the `production` Environment, and
  introduces the `environment:production` OIDC subject. Every one of those is owner-scoped or
  transfer-fragile. Running S1 first means doing it twice and, worse, debugging the second
  time against a half-migrated identity.
- **Task 4 says "treat as absent until observed present" rather than listing what survives.**
  GitHub's transfer behavior differs by setting and changes over time; a plan that asserts
  "rulesets survive" will eventually be wrong in the one case where being wrong deadlocks the
  repo. Verifying is cheap; the assumption is not.
- **Org-level rulesets are a new failure mode that did not exist before the transfer.** A
  `glunk-works` org rule requiring a status check this repo does not produce would leave every
  PR permanently pending — the BR-D9 deadlock arriving from outside the repo, where nothing in
  this repo's own configuration explains it. Task 4 requires reading them.
- *Is S0 really worth doing before the transfer?* Yes — but only because its work is cheap to
  re-verify and its absence is expensive: without a ruleset, the transfer window is exactly
  when an unreviewed push to `main` is most likely. The alternative (transfer first, govern
  after) leaves the repo unprotected during its least stable period.
- *The `github-actions-deploy-role` this repo owns is untouched by this sprint*, so CI keeps
  working through the transfer on the old role. Retiring it is S2's job, deliberately — one
  irreversible change at a time.

**Execution**

- *A coder agent cannot complete this sprint*, and the division is sharper here than in S2:
  the agent prepares files, writes the upstream PR, and drafts every command; a human runs the
  three `tofu apply`s and performs the transfer. Task 3's step 2 is a UI action with no CLI
  equivalent worth trusting.
- *The transfer is not revertible.* Transferring back is a second irreversible act with its
  own broken-subject window, not an undo. Everything checkable should be checked before step
  2, which is why Task 3 verifies authentication on the *old* owner after the widen.
- *`grep -rn 'Seuss27'` as an acceptance criterion will also hit `CODEOWNERS` and the
  discussions URL* — that is the point. Those are the references that rot silently, because
  nothing fails when they are wrong.
- *Do not paste the AWS account id into the upstream PR* (BR-D4). The upstream repo is public
  too, and the policy work in Task 2 is exactly where an account id gets copied into a
  description by accident.
