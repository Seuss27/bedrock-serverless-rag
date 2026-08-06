### FILEPATH: /sprints/ST_org_transfer/sprint_plan.md

# ST — Organization transfer (`Seuss27/` → `glunk-works/`)

**Sprint Goal:** Move the repository into the `glunk-works` organization **without opening an
escalation path into the shared AWS account and without leaving CI unable to authenticate**.

**Closes:** F44, **F45** (Critical), F50, **F57**, **F58**, and the stopgap half of F40.
Executes **BR-D13**.

**Dependencies:** **S0 must be merged** — the governance baseline is cheap to re-verify after
a transfer and expensive to redo, so it lands first. **Task 0 gates every apply in this
sprint** (F50). **S1, S2 and `MW` must NOT have run yet**:
repository variables do not survive a transfer, and the owner name is inside every OIDC
subject, so doing S1's Environment/variable work first means doing it twice.

> **⚠️ Task 1 is already DONE.** `prevent_destroy` on the org-shared OIDC provider merged to
> `main` in **PR #17 (`1ad5aa7`)** and was verified against live state on 2026-08-05. It is
> retained below as the record of what was done and why — **do not re-implement it.** Read its
> acceptance criteria as already satisfied, and start this sprint at Task 0.

**Human applies required (BR-D1) — three of them, and they are the sprint's risk surface:**
Task 0's drift reconciliation and Task 3's *widen* and *narrow*, all in `bootstrap/`; plus a
human apply of **`global-bootstrap`** for Task 2. **Task 1 needs no apply** (a `lifecycle`
meta-argument produces no diff) and in any case is already merged. *(The previous version of
this header named Tasks 1 and 4 — it was wrong on both.)*

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
- Requires a **human `tofu apply` in `bootstrap/`** (BR-D1) for **Task 0**, and twice for
  **Task 3** (widen, then narrow), plus a human apply of **`global-bootstrap`** for Task 2.
  None is a CI operation. *(This line previously named Tasks 1 and 4 and was wrong: Task 1
  needs no apply and is already merged, and Task 4 is GitHub settings, not AWS.)*
- A coder agent can prepare every file and command here, but **must not perform the transfer
  itself** — it is irreversible in practice (the old URL redirects, and re-transferring back
  is a second irreversible act, not an undo).

---

## Tasks

> **Execution order is NOT the numbering** *(revised 2026-08-05 by the plan review)*:
> **T0 → ~~T1~~ (already done, PR #17) → T2a → T2b → T2 → T3 → T4 → T5**, with **T2c** as the
> gate `MW` must pass before *it* starts. T2a and T2b both feed T2 and must precede it: T2a is
> a change to **this** repo that has to land before T2's upstream condition goes live, and T2b
> is the corrected specification T2 implements. Executing T2 from its own body alone
> reproduces the escapable construction.

- **Task 0 (blocking): Reconcile `bootstrap/`'s drift before ANY apply here (F50)**
  - **Description:** `tofu apply` in `bootstrap/` is **not** currently a no-op. A live plan on
    2026-08-05 reports **`1 to change`**: it removes `iam:ListAttachedRolePolicies` from
    `state_access_policy`. That action exists in the **live** AWS policy and not in the
    committed HCL, and no commit ever added it — it was granted out-of-band.
    **Why this blocks the sprint:** Task 3 calls for two human `tofu apply`s in `bootstrap/`
    for an unrelated reason (the OIDC trust widen, then the narrow). Either apply would carry
    this revocation along, unreviewed. CI would then start failing on a
    refresh, and the trust-policy change — the thing that *did* just change — would take the
    blame. That misattribution is the expensive part, not the missing permission.
    **Resolution: commit the action.** It is needed — the AWS provider calls
    `ListAttachedRolePolicies` when refreshing an `aws_iam_role`, which CI does for
    `bedrock_kb_role` on every plan. Add `"iam:ListAttachedRolePolicies"` to the action list
    in `bootstrap/state-backend.tf` so the code matches live, then confirm the plan is clean.
    Do **not** resolve it the other way (letting the apply remove it) without first proving
    nothing needs it — the evidence says something does.
  - **Target Files:** `bootstrap/state-backend.tf`
  - **Acceptance Criteria — 1 of 2:** `AWS_PROFILE=admin-sso tofu plan` in `bootstrap/` reports
    **`No changes.`** That is the gate for every later apply in this sprint: **if plan is not
    clean, do not apply.** Re-run it immediately before each of Task 3's applies, not just once
    at the start — `bootstrap/` has no CI and no review, so drift can reappear between tasks.
  - **Acceptance Criteria — 2 of 2 (blocking, F48):** **`bootstrap/terraform.tfstate` and
    `bootstrap/terraform.tfstate.backup` are copied out-of-band — encrypted, off this
    workstation — and the copy is verified restorable, before the first apply of this sprint,
    and again immediately before Task 3's narrow step.**
    **Why this is a blocking criterion and not housekeeping.** `bootstrap/` declares no
    `backend` block (**F48**): its state is a gitignored file on one machine, and it is the only
    record of the **org-shared OIDC provider**. Task 1's `prevent_destroy` guard is a *plan-time
    guard over a state entry*, not a property of the AWS resource — **no state, no tracked
    resource, no guard.** So if an apply here is interrupted or truncates that file, the
    provider stops being tracked, the guard evaporates, and re-applying from an empty state
    tries to *create* it and fails `EntityAlreadyExists` (F48(c)). Recovery is a hand-written
    state file. Meanwhile an AWS account holds exactly one OIDC provider per URL, so there is no
    second copy and **every glunk-works pipeline** authenticates through it.
    The timing is what makes it acute: this is the sprint that *transfers the repository*, so a
    state file damaged mid-sprint must be repaired against a repo whose owner — and therefore
    whose OIDC trust subjects — are in flux, using the same local admin credentials the sprint
    is trying to retire. F48's remedy is nominally assigned to S2-T3/S2-T4; **ST runs first and
    mandates three applies against exactly this file**, so the mitigation is promoted here. One
    line, and it is the `prevent_destroy`-class value-per-line change of this sprint.

- **Task 1: ~~Stop this repo from being able to break the organization~~ — ✅ DONE, VERIFY ONLY**
  - **⚠️ DO NOT IMPLEMENT THIS. It is merged.** `prevent_destroy` on the org-shared OIDC
    provider landed in **PR #17 (`1ad5aa7`)** and was verified against live state on 2026-08-05.
    The body below used to read *"Add, and have a human apply: `lifecycle { prevent_destroy =
    true }` … **Do this first, before anything else in this sprint**"* while its own acceptance
    criterion said *"✅ VERIFIED."* A literal coder either adds a **duplicate `lifecycle` block**
    (an HCL error) or re-triggers a `bootstrap/` apply — which is exactly the *"an unrelated
    apply carries F50's revocation along"* scenario **Task 0 exists to prevent**.
  - **Why it was done, retained as the record:** this repo's `bootstrap/` and `global-bootstrap`
    share **one** AWS account. An account holds exactly one OIDC provider per URL, and this repo
    **creates** the one `global-bootstrap` reads as a `data` source — so this repo's OpenTofu
    state owns the federation endpoint every glunk-works pipeline authenticates through. Without
    the guard, a routine `tofu destroy` here takes down CI for the whole organization (F40).
    `bootstrap/oidc-setup.tf:29-36` carries the `lifecycle` block and a comment explaining why,
    referencing BR-D18 — ownership moves upstream in S2-T3; this is the stopgap until it does.
  - **Verification only (no apply, no edit):**
    ```
    tofu plan -destroy '-target=aws_iam_openid_connect_provider.github_actions'
    ```
    must fail with `Instance cannot be destroyed … lifecycle.prevent_destroy set`.
    In PowerShell, **quote the `-target=…` argument** (or use `--%`) or it splits at the `.` and
    tofu rejects it as an incomplete resource address. `bootstrap/providers.tf` sets no
    `profile`, so `$env:AWS_PROFILE = "admin-sso"` must be set in the shell first (F49).

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
       execution role needs. **Derive that list from a real dry run, not from prose** — see
       Task 2c and F55.
       The escalation is closed by a **permissions-boundary policy** plus an IAM **role-path**
       scope, but ⚠️ **not by the construction this task originally described** — that version
       was escapable three ways. The corrected requirements are in **Task 2b**, which is
       normative for this step. Apply them here.
       Also add, to the **apply** role's policy, the `DenyBountyFindingsDataAccess` statement
       that `plan_roles.tf` applies to bounty-infra's plan role — the control exists upstream
       and is currently only on the weaker role class (F47) — **extended per Task 2b(6) to
       cover `kms:` and the findings key, not `s3:` alone** (F58).
    3. **Create `bedrock_rag_plan_policy` (F56).** `plan_role = true` generates the role and
       its *state*-read policy, but the **workload** read policy upstream is
       `aws_iam_policy.bounty_infra_plan_policy` — hardcoded, **not** `for_each`ed. Without a
       mirror for this project, `github-actions-bedrock-serverless-rag-plan` holds state-read
       and nothing else: no `iam:GetRole`, no `aoss:*`, no `bedrock:Get*`, no `s3:GetBucket*`,
       and **every PR plan `403`s on refresh.** Create it as the read-only mirror of the
       workload policy, **with the corrected findings `Deny` attached to it too**.
    4. **Decide the plan role's trust, and record the answer (F56).** Live `plan_roles.tf`
       trusts **only** `repo:<org>/<repo>:pull_request` via `StringEquals`, and offers no
       `extra_oidc_subjects`. So **any `push`-triggered job can never assume it** — which is
       S1-T5's `tofu-plan-main`, the job whose summary S1 designates as "the fresh evidence the
       approver reads". Pick one, upstream, in this PR: **(a)** add an `extra_oidc_subjects`
       equivalent to `plan_roles.tf` so the plan role can also trust `ref:refs/heads/main`, or
       **(b)** drop `tofu-plan-main` from S1-T5 and make the approver's evidence the PR-time
       plan summary, recording the widened plan→apply TOCTOU that creates.
       > **⚠️ Do NOT unblock this by pointing the plan job at `vars.AWS_OIDC_ROLE_ARN`.** That
       > is an **apply-capable role, assumed on push to `main`, with no `environment:` gate** —
       > i.e. **F13 restored, in the same change that closes it**, and it satisfies S2-T2's
       > stated acceptance criterion, which only checks that `deploy.yml` contains no `||`
       > fallback. That criterion is strengthened in S2-T2 for exactly this reason.
    Open the F41 issue in the same visit, covering the other three project policies, and the
    companion upstream items in § 9.4 (`StringLike` → `StringEquals` on the apply role's trust;
    F8's carried-forward PAB / TLS-only / lock-table `prevent_destroy` + PITR; BR-D22's
    key-provider choice).
  - **Target Files:** `glunk-works/global-bootstrap`: `variables.tf`, `project_policies.tf`,
    `plan_roles.tf` (an upstream PR — not files in this repo)
  - **Acceptance Criteria:** The upstream PR is **merged and applied by a human** before Task
    3 begins. The **allowlist** criterion from Task 2b(4) passes — *not* the old
    "no `Allow` with `Resource = "*"` on an `iam:` action", which a coder satisfies with
    `role/*`. `bedrock_rag_plan_policy` exists and is attached. The plan-role trust decision
    (step 4) is recorded in the PR body with its choice and rationale. The F41 issue exists and
    is linked from `docs/hardening_roadmap.md` § 9.4. **Do not start Task 3 until this is
    applied** — record the applied timestamp in the sprint's PR body.

- **Task 2a (blocking Task 2): Give the module's roles a path and a boundary (F57)**
  - **⚠️ Ordering — this is the whole point of the task.** It must land **before** Task 2's
    upstream `iam:PermissionsBoundary` condition goes live, and the two changes are **in
    different repositories**, so nothing enforces the order automatically. State it in both PR
    bodies.
  - **Description:** `aws_iam_role.bedrock_kb_role` declares `name =
    "personal-bedrock-kb-execution-role"` and **no `path`, no `permissions_boundary`**. No task
    in ST, S2 or S3+S4 previously added either. The moment Task 2's condition and
    `role/bedrock-rag/*` Resource scope are live, CI's `CreateRole` for it is denied **twice
    over** — wrong path, and no boundary to satisfy the condition.
    **Where this lands is the dangerous part.** S2-T2's discipline is *adopt → verify → delete*.
    This fails at **verify** — the one moment when the escalation-capable local role has **not
    yet been deleted** and the pressure to "just unblock the pipeline" is highest. The cheapest
    unblock is to drop the `iam:PermissionsBoundary` condition upstream, which silently reverts
    the entire boundary construction and reopens **F41**. It also composes with F55: by then
    `MW` has already deleted the resources, so the failure arrives with no working system to
    fall back to.
    Set on `bedrock_kb_role` **and on every role the module creates from here on**:
    ```hcl
    path                 = "/bedrock-rag/"
    permissions_boundary = var.workload_permissions_boundary_arn
    ```
    Note `path` **forces replacement** — which is free under BR-D20 and is another reason to do
    it before `MW` rather than after.
  - **Target Files:** `modules/aws-bedrock-rag/iam.tf`, `variables.tf`
  - **Acceptance Criteria:** Every `aws_iam_role` in `modules/` declares both arguments —
    grep-checkable. The variable is threaded from `environments/ai-lab`. Both this PR body and
    the upstream PR body state the ordering dependency explicitly.

- **Task 2b (normative for Task 2): the boundary construction, corrected**
  - **Description:** The construction Task 2 originally described was asserted to make
    privilege escalation *"structurally impossible."* **It does not, and that phrase must not
    appear in the upstream PR.** Three independent holes, each of which a coder implementing
    the original wording would reproduce. *(The full exploit chain — how these compose into
    reading bounty-infra's findings archive through this project's vector store — is in the
    private advisory register, not in this public file. Read it before implementing.)*
    1. **`iam:UpdateAssumeRolePolicy` and `iam:UpdateRole` are in neither the Deny list nor the
       boundary condition — and cannot be.** The `iam:PermissionsBoundary` condition key is
       evaluated only for the permissions-*modifying* verbs (`CreateRole`, `PutRolePolicy`,
       `AttachRolePolicy`, `DetachRolePolicy`, `DeleteRolePolicy`, `Put*PermissionsBoundary`).
       For `UpdateAssumeRolePolicy` the **only** containment is the `Resource` element — and the
       original text scoped the path for *creation* only ("the only path the policy can **create
       into**"). S2-T5 genuinely needs this verb (it rewrites `bedrock_kb_role`'s trust policy),
       so a coder will grant it, most naturally on `*` or `role/*`. **Fix:** add
       `iam:UpdateAssumeRolePolicy`, `iam:UpdateRole`, `iam:UpdateRoleDescription`,
       `iam:TagRole`, `iam:UntagRole` to the **Resource-scoped** statement
       (`arn:aws:iam::<acct>:role/bedrock-rag/*`) and **never** to `*`.
    2. **`iam:PassRole` is scoped by `PassedToService` but never by `Resource`.** **Fix:** scope
       it to `role/bedrock-rag/*` **in addition to** the `iam:PassedToService =
       bedrock.amazonaws.com` condition. Either alone is insufficient.
    3. **`iam:CreatePolicy` is denied nowhere and scoped nowhere** — only `CreatePolicyVersion`
       was denied. Managed policies carry paths. **Fix:** scope `iam:CreatePolicy` to
       `arn:aws:iam::<acct>:policy/bedrock-rag/*`.
    4. **Restate the acceptance criterion as an allowlist.** The original —*"no `Allow` with
       `Resource = "*"` on an `iam:` action"* — is a denylist wearing an allowlist's clothes: a
       coder blocked by it writes `role/*`, which passes literally and is functionally `*`.
       **Use instead, and it is grep-checkable:** *"no `Allow` on any `iam:` action whose
       `Resource` is not literally `role/bedrock-rag/*` or `policy/bedrock-rag/*`."*
    5. **Write out the boundary policy document.** The plan named the mechanism and never
       specified the contents, so a coder will invent it. It needs at minimum
       `bedrock:InvokeModel` on the embedding model, `s3:GetObject`/`ListBucket` on the source
       bucket, and `aoss:APIAccessAll`. *(The `kms:Decrypt`/`GenerateDataKey` entry the original
       anticipated was for S3-T4's customer-managed key, **which BR-D23 cut** — do not add it.)*
       Too loose and the boundary is decorative; too tight and every apply breaks, and a
       boundary that breaks every apply gets **removed rather than corrected** — the same
       dynamic that makes an over-strict guardrail worse than none.
    6. **Extend the findings `Deny` to `kms:` (F58).** As written it is `Deny` on `s3:*` for the
       findings bucket. Asset #1 is **two resources** — the bucket and the KMS key encrypting it
       — and an `s3:` Deny does not constrain a `kms:` action. Write it as:
       ```
       Effect:   Deny
       Action:   ["s3:*", "kms:*"]
       Resource: [ <findings bucket ARN>, <findings bucket ARN>/*, <findings KMS key ARN> ]
       ```
       Do this **when the Deny is written**, so it is already correct if KMS verbs are ever
       granted later. *(BR-D23 cut S3-T4, the task that would have required them, so the
       immediate trigger is gone — the asymmetry is not.)*
  - **Also record, because it will bite otherwise:** a blanket `Deny` on
    `iam:CreatePolicyVersion` means the workload can **never update a managed policy** — every
    `aws_iam_policy` body change calls it. **All workload policies must therefore stay inline**
    (`aws_iam_role_policy`). The module does this today; S4-T5's "add an IAM role **or policy**"
    wording must not be read as licence to add a managed one. A coder hitting `AccessDenied` on
    a policy update will otherwise weaken the Deny to unblock themselves.
  - **Checked and found clean, recorded so it is not re-audited:** `iam:TagRole`/`UntagRole` as
    an ABAC pivot (no ABAC condition exists anywhere upstream, so there is nothing to pivot on);
    `iam:CreateServiceLinkedRole` (SLRs receive AWS-managed policies only); and the boundary
    policy *document* itself, which is correctly protected by the blanket `iam:*`-targeting-it
    Deny plus the `CreatePolicyVersion` Deny.
  - **Acceptance Criteria:** The upstream policy passes the allowlist grep in (4). The boundary
    policy document is committed upstream, not improvised. The phrase "structurally impossible"
    appears nowhere; an enumerated **residual risk** appears instead.

- **Task 2c (blocking `MW`, not this sprint): prove the deploy identity can rebuild (F55)**
  - **Description:** Recorded here because Task 2 is where the replacement policy is written,
    and this is the criterion that policy must meet. `MW` deletes the orphaned workload and
    rebuilds it. The rebuild needs verbs the **current** `state_access_policy` does not grant —
    `aoss:*AccessPolicy`, `iam:PassRole`, `s3:*EncryptionConfiguration`, `s3:GetBucket*` — and
    those grants have **never been exercised**, because run `26788807269` died at
    `EntityAlreadyExists` before AOSS or Bedrock were reached.
    **Make sufficiency a precondition, never a discovery.** Before `MW` deletes anything, a dry
    run must demonstrate that the identity it will run under can create everything the module
    declares. **Regenerate the verb list from that dry run** — F55's list is indicative and its
    own confidence note says the list may be incomplete.
  - **Acceptance Criteria:** A recorded dry run, linked from `MW`'s PR body, showing a
    from-scratch create path with no `AccessDenied`. `MW` does not begin without it.

- **Task 3: Widen the trust policy, then transfer (never the other order)**
  - **Description:** The transfer changes every OIDC subject this repo presents, from
    `repo:Seuss27/bedrock-serverless-rag:…` to `repo:glunk-works/bedrock-serverless-rag:…`.
    Use the widen-then-narrow discipline, in **three** separate steps with verification
    between each:
    1. **Widen** (human apply, `bootstrap/`): change `var.github_repo_path`'s consumer so the
       trust condition accepts **both** owners. Since F2 is not yet fixed at this point, the
       existing `StringLike "repo:${var.github_repo_path}:*"` already matches anything under
       the old owner — so add a second subject for the new owner rather than editing the old
       one.
       > **The HCL form is not obvious and getting it wrong is expensive.** "Add a second
       > condition entry" means **a list value on the single `…:sub` key** — *not* two
       > `StringLike` blocks inside one `Condition`, which is a duplicate-key error:
       > ```hcl
       > condition {
       >   test     = "StringLike"
       >   variable = "token.actions.githubusercontent.com:sub"
       >   values   = [
       >     "repo:Seuss27/bedrock-serverless-rag:*",
       >     "repo:glunk-works/bedrock-serverless-rag:*",
       >   ]
       > }
       > ```
       > A botched trust policy here is repairable **only** with local admin credentials,
       > against the unbacked-up state file Task 0's second criterion exists to protect.
       Verify CI still authenticates on the current owner.
    2. **Transfer** — repo Settings → Danger Zone → Transfer, target `glunk-works`. **Human
       only.**
    3. **Verify, then narrow** — once every workflow authenticates under the new owner,
       remove the old-owner entry in a second human apply.
       > **⚠️ The narrow is a blocking acceptance criterion of this sprint, not a trailing
       > step — and it must complete in the same working session as the transfer.**
       > Everything works without it, nothing gates it, and it is the last step of an
       > irreversible sprint. So by default it slips. **The reason it matters is that GitHub
       > usernames are reclaimable.** After the transfer, `Seuss27/bedrock-serverless-rag` is a
       > free name; if that account is ever renamed or deleted, whoever registers it and creates
       > a repo of that name mints tokens matching `repo:Seuss27/bedrock-serverless-rag:*` — a
       > `StringLike` glob admitting **every branch and every PR** — against a role holding
       > `iam:CreateRole` on `*` in the shared account. Not exploitable by a third party today,
       > since the operator holds both identities. But the widen leaves a **dangling-subject
       > trust policy** standing for as long as the narrow and S2-T2 take, and "as long as they
       > take" is exactly what an unstated, ungated trailing step does not bound.
    **Never** swap old for new in one apply: if any subject is wrong, CI cannot authenticate
    and cannot self-correct, and the fix needs local admin credentials.
  - **Target Files:** `bootstrap/oidc-setup.tf`
  - **Acceptance Criteria:** After step 3, a PR run and a merge-to-`main` run have both
    authenticated to AWS under `glunk-works/…` — **observed in a workflow run, not inferred
    from the policy text**. **No `repo:Seuss27/` string remains in any trust policy, verified
    with `aws iam get-role` against live AWS rather than against the HCL** — and this is
    blocking, per the narrow note above. The `github-actions-bedrock-serverless-rag` role, now
    reachable, resolves to the **corrected** policy from Task 2 — verify by reading the attached
    policy ARN, not by assuming Task 2 took effect. Task 0's state backup has been re-taken
    immediately before this task's applies.

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

---

## Critical review — amendments from the 2026-08-05 cold-context plan review

The review of PR #18 found this sprint's task list to be the most defect-dense in the roadmap,
which is unsurprising: it is the only one whose central act has no diff. Recorded here so the
amendments are read as *findings against the plan*, not as a rewrite of someone's judgement.

- **The boundary construction was escapable three ways, while being described as making
  escalation "structurally impossible."** That phrase was the defect that mattered — it stops
  the reader looking. **Task 2b** now holds the corrected specification and is normative for
  Task 2; the residual risk is enumerated instead of denied. The exploit chain that
  demonstrates it lives in the **private advisory register**, not in this public file.
- **A construction advertised as an allowlist was implemented as a denylist.** The `Deny`
  enumerated three targets (`github-actions-*` roles, the boundary policy, the OIDC provider),
  which left everything *else* in the shared account in scope — bounty-infra's roles, every
  `AWSReservedSSO_*` role, every other project's execution role. Task 2b(4) restates the
  acceptance criterion in allowlist form, which is also the only form that is grep-checkable.
- **Two module-level prerequisites were missing entirely** — the KB role's `path` and
  `permissions_boundary` (**F57**, now Task 2a) and the deploy identity's sufficiency for a
  from-scratch rebuild (**F55**, now Task 2c). Both fail at *verify*, after the point of no
  return, and both have the same cheapest-unblock failure mode: weaken the control that was
  just installed. Making them preconditions is the entire fix.
- **The plan role was assumed to work and does not** (**F56**). Its trust admits only
  `:pull_request`, and its workload read policy is hardcoded to another project. The dangerous
  part is not the breakage but the natural unblock — pointing the plan job at the apply role,
  which restores **F13** in the change that closes it, while still satisfying S2-T2's original
  acceptance criterion.
- **The state file this sprint applies against three times is unbacked-up** (**F48**, now
  ST-T0 criterion 2). F48's own mitigation existed in the roadmap and appeared nowhere in the
  sprint that most needed it — the classic shape of a control recorded but not scheduled.
- **The narrow step was ungated and its rationale unwritten** (Task 3). GitHub usernames are
  reclaimable; that single fact is what turns a tidy-up into a deadline, and it was in no
  document.
- **Header corrections.** The sprint named Tasks 1 and 4 as the human applies (wrong on both —
  it is T0 and T3 twice, plus the upstream apply), and Task 1's body instructed a coder to
  perform work already merged in PR #17. Both are the kind of error a literal executor acts on.

**Not adopted.** The review's suggestion to fold Task 2a into Task 2 was rejected: they land in
**different repositories** and the ordering between them is the whole point, so one task
spanning both invites a single PR that satisfies neither ordering.
