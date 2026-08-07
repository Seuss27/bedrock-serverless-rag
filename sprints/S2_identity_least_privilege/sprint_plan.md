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

> **⚠ Re-scoped a second time, 2026-08-05, by BR-D23.** **Task 1 (teardown and rebuild) and
> Task 6 (the AOSS data-plane principal) have MOVED to the new `MW` sprint**, which runs
> immediately after ST — because BR-D20 makes `destroy → apply → verify` the acceptance test
> every infrastructure sprint must pass, and no sprint before this one could pass it. They are
> retained below **only as pointers**; their bodies live in
> `sprints/MW_make_it_work/sprint_plan.md`. Do not execute them from here.

> **⚠ Re-scoped a third time, 2026-08-06, by ST's pre-implementation review.** **ST no longer
> *corrects* the upstream `bedrock-serverless-rag` policy — it DELETES the whole project entry**
> (`ST-T2′`), because the role was inert (F44) and deleting it closed **F45** without gating an
> irreversible transfer on a permissions-boundary design. **The consequence for this sprint is
> not cosmetic: there is no upstream role left to adopt.** Task 2 below says *"adopt
> `global-bootstrap`'s roles, then retire the local ones"* — after ST, **the role it adopts does
> not exist**, and a literal executor will either point CI at an empty ARN or "unblock" itself
> by re-adding the entry **without** a boundary, which is precisely the escalation ST removed.
> **New Task 0 below re-creates it correctly, and it is blocking.**
>
> Also arriving here from ST: **F58** (the findings `Deny` must cover `kms:`, not just `s3:`),
> the **`permissions_boundary` half of F57** (the module's roles got `path` in ST; the boundary
> argument lands here with the policy it points at), and **F56** (the plan role's trust and its
> workload read policy — which does not arise until the entry exists again, i.e. Task 0).
> **`ST` Task 2b is the NORMATIVE specification for Task 0** — it is retained verbatim in
> `sprints/ST_org_transfer/sprint_plan.md`. Read it there. Its entire purpose is to stop this
> sprint re-adding the original, escapable construction.
>
> ✅ **Re-homing CONFIRMED 2026-08-07 by ST-T5**, which is a real check and not a formality: ST's
> Definition of Done requires every re-homed finding to appear in its **destination** plan, on
> the principle that a finding moved out of a sprint and not written into where it landed is a
> finding **dropped**. All three are present below in **Task 0** — F56 at step 3, F58 at step 4,
> F57's boundary half in the "also in this sprint, not upstream" bullet.
>
> ⚠️ **One thing ST changed that is easy to read as a relief and is not.** After `ST-T2′` this
> project has **no upstream role, no plan role, and no findings `Deny`** — a *smaller surface*,
> not a *hardened* one. Nothing was secured; something was removed. Task 0 re-creates all three
> at once, which is the moment every one of these findings re-arms simultaneously.

**Sprint Goal:** This repo ends the sprint owning its **workload and nothing else**. No OIDC
provider, no CI role, no state bucket — and state confidentiality that does not depend on who
can read the bucket.

**Closes:** F1 (Critical), F2, F3, F40, F43, F48, **F56**, **F58**, the
`permissions_boundary` half of **F57**, and the local half of F47. Executes **BR-D22**. **F4**
(confused deputy) is the one original task that survives unchanged.
*(F5, F39 and F51 moved to `MW`.)*

> **Two corrections to the line above, 2026-08-06.** **F42 is no longer closed here** — ST
> deleted the offending policy rather than replacing it, so there is nothing left in this
> sprint that closes it; **F42 and F41 remain open org-wide** against the *other* project
> policies (`resume_optimizer_policy` and siblings), tracked by the upstream issue ST-T2′
> opens. And **F58 now IS closable here**, having moved from ST — the previous text said it
> was not, which was true only while ST owned the `Deny`.

**Dependencies:** **ST must be complete** — the transfer is done and CI authenticates from
`glunk-works/…`.
⚠️ **This previously also required "`global-bootstrap`'s corrected `bedrock-serverless-rag`
policy is applied". That condition can never be met**: ST deletes the entry instead of
correcting it. The corrected policy is **this sprint's Task 0 to write**, not a precondition it
inherits — reading it as a precondition means waiting for something nobody will ever do. **`MW` must be complete** — a `tofu plan` here is meaningless until state describes
the deployed system, and several criteria below read plan output. **S1 must be merged** — the
plan/apply job split is what makes two roles meaningful.

**Security Considerations:** The sprint's risk profile is inverted from the usual: the danger
is not adding a weak control, it is **deleting a working one before its replacement is
proven**. Every *identity* retirement below is therefore written as *adopt, verify, then
delete* — never *delete, then adopt*. That discipline applies to roles, trust policies and the
state backend; it does **not** apply to the workload resources, which BR-D20 makes freely
disposable. Keep the two straight: the account is shared with the organization (F47), so an
identity mistake does not fail locally, while a workload mistake costs an apply.

**Risks & Blockers:**
- **F39 makes `tofu plan` untrustworthy until `MW` completes** *(was "until Task 1
  completes" — that task moved)*. The resources exist in AWS and are absent from CI's state; a
  plan against that state describes a system that is not there. Several criteria here and in
  S3+S4 are "read the plan output" — **they are invalid until `MW` lands.**
- Human `tofu apply` needed in `bootstrap/` (BR-D1) and in `global-bootstrap`.
- **⚠️ `bootstrap/`'s state is still a single-machine local file (F48) during Tasks 3 and 4.**
  ST-T0's out-of-band backup criterion applies here too — re-take it before each apply in this
  sprint. Task 3's `tofu state rm` against the org-shared OIDC provider is the single operation
  in this roadmap where "the correct verb and the dangerous one" are the same string.
  > **📥 Carried in from ST's completion review (2026-08-07) — treat as a BLOCKING precondition
  > of Tasks 3 and 4, not a reminder.** ST's backup **was** taken, but two of its properties
  > were **attested, never proven**: that the copy is *restorable*, and that it was re-taken
  > immediately before ST-T3's narrow. **Before the first apply here, restore the copy to a
  > scratch path and confirm it parses and lists `aws_iam_openid_connect_provider`.** An
  > unverified backup is the ordinary way backups fail, and this one is the only record of the
  > **org-shared federation endpoint** — `prevent_destroy` is a plan-time guard over a *state
  > entry*, so it evaporates with the file. **Record the restore-test result in the PR body**,
  > because ST's lesson was that a blocking criterion whose only evidence is memory is
  > indistinguishable from one that was skipped. **Tracked as #37** — close it from the PR
  > that performs the restore-test, not from here.
- ⚠️ **Reversed 2026-08-05 (BR-D19/BR-D20).** This bullet used to read *"never resolve a state
  collision by deleting the live resource — the AOSS collection holds the embeddings."* It
  holds nothing; the corpus is empty. **Deleting the orphans and rebuilding is now the
  preferred remedy.** The rule that survives is narrower and absolute: **never delete anything
  shared with the organization** — the OIDC provider, `global-bootstrap`'s state bucket, or
  bounty-infra's findings archive, all of which live in the same account (F47).

---

## Tasks

- **Task 0 (blocking, arrived from ST 2026-08-06): Re-create the upstream project entry —
  WITH the boundary this time (F56, F58, F57's boundary half)**
  - **⚠️ Read `ST` Task 2b before writing a line of this.** It is retained verbatim in
    `sprints/ST_org_transfer/sprint_plan.md` and is **normative** here. It enumerates three
    independent holes in the construction that was originally proposed — `iam:UpdateAssumeRolePolicy`
    and `iam:UpdateRole` reachable outside the boundary condition, `iam:PassRole` scoped by
    service but not by `Resource`, and `iam:CreatePolicy` scoped nowhere — each of which a coder
    working from the *superseded* ST Task 2 body will faithfully reproduce. The superseded body
    is also retained there, immediately below `T2′`, clearly marked. **Do not implement the one
    marked SUPERSEDED.**
  - **Why this task exists at all:** `ST-T2′` deleted the `bedrock-serverless-rag` entry from
    `var.projects` upstream, along with `bedrock_rag_policy` and its attachment, to close **F45**
    by removing a dormant over-privileged role rather than correcting it. That was the right
    trade *for ST* — it took a permissions-boundary design off the critical path of an
    irreversible transfer. The design was **deferred, not cancelled**, and this is where it lands,
    with no irreversible act waiting on it and no pressure to weaken it to unblock a pipeline.
  - **Description:** An upstream PR against `glunk-works/global-bootstrap` re-adding the entry:
    1. **`variables.tf`** — `"bedrock-serverless-rag" = { repo_name = …, plan_role = true,
       extra_oidc_subjects = ["environment:production"] }`. (`plan_role` and the subject are what
       S1's gated apply and PR-time plan need; both keys already exist in the upstream schema.)
    2. **`project_policies.tf`** — a workload policy scoped to what the module *actually*
       declares, plus the permissions-boundary policy document, **per Task 2b(1)(2)(3)(5)**.
       Derive the verb list from **`MW`'s recorded dry run** (F55), not from prose.
    3. **`plan_roles.tf`** — `bedrock_rag_plan_policy`, the read-only mirror (**F56**), and the
       plan-role trust decision recorded with its rationale.
    4. **The findings `Deny` covering `s3:` AND `kms:`** on the bucket, its objects, and the
       KMS key (**F58**, Task 2b(6)).
  - **Then, and only then, Task 2 below becomes executable** — there is a role to adopt.
  - **Also in this sprint, not upstream:** set `permissions_boundary =
    var.workload_permissions_boundary_arn` on every `aws_iam_role` in `modules/` and thread the
    variable from `environments/ai-lab`. **`path = "/bedrock-rag/"` is already set** — it landed
    in `ST-T2a′` so that `MW` would rebuild at the correct path and the role would not be
    replaced twice. Do not re-add it.
  - **Acceptance Criteria:** Task 2b(4)'s **allowlist** grep passes — *no `Allow` on any `iam:`
    action whose `Resource` is not literally `role/bedrock-rag/*` or `policy/bedrock-rag/*`*.
    The boundary policy document is **committed upstream, not improvised**. The phrase
    "structurally impossible" appears nowhere; an enumerated **residual risk** appears instead.
    Every `aws_iam_role` in `modules/` declares both `path` and `permissions_boundary`. The
    upstream PR is merged **and human-applied** before Task 2 begins. No AWS account id appears
    in the upstream PR body — that repo is public too (BR-D4).

- **Task 1: ~~Reconcile state by teardown and rebuild~~ — MOVED to `MW-T1`**
  - **Moved 2026-08-05 (BR-D23).** This task, its F39 inventory step, its teardown, and its
    `destroy → apply → verify` acceptance criterion now live in
    `sprints/MW_make_it_work/sprint_plan.md` as **MW-T1**, running immediately after ST rather
    than fourth. **Do not execute it from here** — `MW` also carries the blocking F55 gate
    (prove the deploy identity can rebuild *before* deleting anything) that this version
    lacked, which is the whole reason it moved. S3-T6's resource-name fix folded into it.
  - **What this sprint still assumes:** that `MW` completed, so `tofu plan` in
    `environments/ai-lab` reports `No changes.` and a CI apply has succeeded at least once.
    If that is not true, stop — every plan-reading criterion below is invalid.

- **Task 2: Adopt `global-bootstrap`'s roles, then retire the local ones (F1, F2, F3, ~~F42~~)**
  - **⚠️ BLOCKED ON TASK 0 (added 2026-08-06).** The role this task adopts **does not exist
    after ST** — `ST-T2′` deleted the upstream entry. Task 0 re-creates it *with* the boundary;
    until that is merged **and applied**, there is nothing to adopt. The dangerous misreading is
    to treat the missing role as a blocker to route around: pointing CI at the local role and
    calling it "adopted", or re-adding the entry inline without Task 2b's construction. Both
    reopen **F41** in the sprint whose whole purpose is closing this class of finding.
  - **F42 is struck from this task's finding list.** It was closed here only under the old plan
    where ST *rewrote* the policy; ST now deletes it, so F42 survives org-wide against the other
    project policies and is not this task's to close. Do not mark it done.
  - *(The `adopt → verify → delete` discipline below is unchanged and is exactly right — note
    that Task 0 lengthens the window in which both roles exist, which is the window this
    discipline exists to make safe.)*
  - **Description:** ~~ST-T2 already added `plan_role = true` and
    `extra_oidc_subjects = ["environment:production"]` upstream and replaced
    `bedrock_rag_policy` with a boundary-constrained one.~~
    > **⚠️ That sentence is FALSE and was the most dangerous line in this plan** *(struck
    > 2026-08-07 by ST-T5)*. **ST added nothing upstream — it deleted.** `plan_role`, the
    > `environment:production` subject, and a boundary-constrained workload policy are all
    > **Task 0's deliverables**, not inherited state. A coder reading the struck sentence
    > proceeds straight to step 1, finds `github_actions_role_arns` has no entry for this
    > project, and "fixes" it by re-adding the upstream entry inline **without** the boundary —
    > reopening **F41** in the sprint whose entire purpose is closing that class of finding.
    > The banner at the top of this file says so; this body contradicted it, and **a task body
    > wins over a banner for anyone who scrolls straight to their task.**

    **Task 0 must be merged AND human-applied before this task begins.** Then this task
    **switches over and cleans up**, in that order:
    1. **Adopt.** Point `vars.AWS_OIDC_ROLE_ARN` at `github-actions-bedrock-serverless-rag`
       and `vars.AWS_PLAN_ROLE_ARN` at `github-actions-bedrock-serverless-rag-plan`, from
       `global-bootstrap`'s `github_actions_role_arns` / `github_actions_plan_role_arns`
       outputs. Drop S1's `|| vars.AWS_OIDC_ROLE_ARN` fallback in `deploy.yml`.
    2. **Verify.** A PR plan job green on the plan role; a merge-to-`main` apply green on the
       apply role, through the `production` Environment gate. **Both observed in real runs.**
    3. **Only then delete**, in `bootstrap/`: `aws_iam_role.github_actions_role`,
       `aws_iam_role_policy.state_access_policy` — the F1 escalation — and
       `var.role_name` / `var.github_oidc_subject_prefixes`. Human apply.
       *(That second variable was `var.github_repo_path` until **ST-T3** replaced it; a
       coder searching for the old name will not find it.)*
       > **This deletion also retires `MW`-T5's temporary widen of `state_access_policy`**
       > (F55) — the `aoss:Create/Get/UpdateAccessPolicy` (no `Delete`; unmeasured, see
       > below), `aoss:APIAccessAll`, `aoss:ListTagsForResource`, `bedrock:Get*`,
       > `budgets:ModifyBudget`/`ViewBudget`/`ListTagsForResource`, `iam:PassRole` and
       > `s3:GetBucket*`/encryption-config grants added there to prove the identity
       > sufficient for a from-scratch build (the pre-existing `aoss:Create/DeleteSecurityPolicy`
       > etc. predate `MW`-T5 and are F1's, not this widen's). No separate removal step is
       > needed — the whole resource goes away here, widen and all.

    > ### ⚠️ ENUMERATING THE PLAIN SUBJECT FORM WILL BREAK CI — read before writing any
    > `StringEquals` list
    >
    > **Discovered the hard way in ST-T3 (2026-08-06):** this repository is org-owned, and
    > GitHub presents an **ID-qualified** OIDC subject, not the plain one:
    >
    > ```
    > repo:glunk-works@<org_id>/bedrock-serverless-rag@<repo_id>:ref:refs/heads/main
    > repo:glunk-works@<org_id>/bedrock-serverless-rag@<repo_id>:pull_request
    > ```
    >
    > Measured from CloudTrail `AssumeRoleWithWebIdentity`, not inferred. The transfer broke
    > CI authentication for exactly this reason: `repo:glunk-works/bedrock-serverless-rag:*`
    > does **not** match a subject carrying `@<id>` segments.
    >
    > So an enumeration written from the plain form — the obvious way to satisfy the
    > `StringEquals` criterion below — **reproduces that outage**, and it does so in the task
    > that *also deletes the fallback role in step 3*. Order matters: verify (step 2) before
    > deleting (step 3), and never collapse them.
    >
    > **Do not trust the API field over the evidence.**
    > `gh api repos/<owner>/<repo>/actions/oidc/customization/sub` reports
    > `use_immutable_subject: false` for this repository while `sub_claim_prefix` carries the
    > ID-qualified value — and the ID-qualified value is what actually arrives. Read
    > `sub_claim_prefix`, then confirm against CloudTrail.
    >
    > This applies to the **upstream** role too: `global-bootstrap` builds subjects from
    > `github_organization` + `repo_name`, i.e. the plain form. Adopting that role (step 1)
    > without fixing its subject construction fails the same way. Check it **before** step 3.
    F2 and F3 are closed by adoption rather than by fixing — **but not on the operator this
    task previously claimed.** ⚠️ This body used to assert *"the upstream role's trust is
    already `StringEquals` over an enumerated subject list."* **It is not.** Live
    `global-bootstrap/main.tf` uses **`StringLike`** on `…:sub` for the **apply** role;
    `StringEquals` appears only on the **plan** role, where a comment says so explicitly. The
    values are wildcard-free today, so it is functionally equivalent — but **F2's entire
    substance is that in IAM `StringLike`, `*` matches `:` too**, so closing F2 on an operator
    the upstream code does not use means the first `extra_oidc_subjects` entry containing a `*`
    globs silently. The `StringLike` → `StringEquals` change is filed with the F41 upstream
    issue (§ 9.4) and is a **precondition of closing F2**, not a nice-to-have. F3's half stands:
    the plan role does exist as a separate read-only identity — subject to **F56**, which
    ~~ST-T2 must have resolved~~ **Task 0 of this sprint resolves** *(corrected 2026-08-07 by
    ST-T5: `ST-T2′` deleted the project entry, so no plan role exists for this project at all
    until Task 0 sets `plan_role = true` again — F56 is dormant, not fixed, and it re-arms in
    that same change)*.
  - **Target Files:** `bootstrap/oidc-setup.tf`, `bootstrap/state-backend.tf`,
    `.github/workflows/deploy.yml`
  - **Acceptance Criteria:** `grep -rn 'iam:CreateRole\|iam:PutRolePolicy' bootstrap/`
    returns nothing. `aws iam get-role --role-name github-actions-deploy-role` returns
    `NoSuchEntity`. A full PR→merge→approve→apply cycle has run green on the two upstream roles.
    **The adopted role's trust condition uses `StringEquals`** — read it from live AWS, not from
    the upstream HCL.
    **⚠️ STRENGTHENED (F56).** The old criterion was *"`deploy.yml` contains no `||` fallback."*
    That is **satisfied by the dangerous unblock**: pointing the plan job at
    `vars.AWS_OIDC_ROLE_ARN` removes the fallback *and* gives a push-triggered, un-gated job an
    apply-capable role — **F13 restored in the change that closes it**. Replace it with:
    **"the plan job authenticates as the *plan* role, evidenced by a run link, and the apply job
    as the apply role."** Identity is verified from the run, never inferred from the file.

- **Task 3: Hand the OIDC provider upstream (F40, BR-D18)**
  - **Description:** The stopgap `prevent_destroy` from ST-T1 stays until this lands. The
    durable fix inverts the dependency: `global-bootstrap` should **own** the provider it
    currently only reads.
    1. **Upstream PR:** change `data.aws_iam_openid_connect_provider.github` to a
       `resource`, with a committed `import` block for the existing provider ARN and
       `lifecycle { prevent_destroy = true }`. Every existing reference
       (`data.….arn` → `aws_iam_openid_connect_provider.github.arn`) updates in the same
       change. Human apply upstream. **Verify a project role can still be assumed
       afterwards** — an OIDC provider replacement, rather than an import, would break every
       pipeline in the org at once.
    2. **Then here:** `tofu state rm aws_iam_openid_connect_provider.github_actions` and
       delete the resource block. **`state rm`, not `destroy`** — the resource must survive;
       only this repo's claim on it goes away.
  - **Target Files:** `bootstrap/oidc-setup.tf`; upstream `global-bootstrap/main.tf`
  - **Acceptance Criteria:** `grep -rn 'aws_iam_openid_connect_provider' bootstrap/` returns
    nothing. `aws iam list-open-id-connect-providers` still returns **exactly one** provider
    for `token.actions.githubusercontent.com` and CI still authenticates — verified in a real
    run **after** the state removal. The upstream apply showed an **import**, not a
    create/replace: paste the plan's action line (`~`/`+`/`-` and the address only) into the
    PR body.

- **Task 4: Migrate state to the org backend, then retire the local one (F43)**
  - **Description:** `global-bootstrap` owns `glunk-works-tofu-state-00042` +
    `global-tofu-lock`, with genuine per-project isolation — each project role gets
    `s3:ListBucket` conditioned on `s3:prefix = <project>/*` and object access scoped to
    `<project>/*`. This repo's own bucket has none of that.
    1. Change `environments/ai-lab/backend.tf` to
       `bucket = "glunk-works-tofu-state-00042"`, `key = "bedrock-serverless-rag/terraform.tfstate"`,
       `dynamodb_table = "global-tofu-lock"`. The `key` prefix **must** match the
       `var.projects` map key exactly, or the role's `s3:prefix` condition denies access —
       and the failure reads as a backend/credentials error, not a naming one.
    2. `tofu init -migrate-state`, answer yes, then **`tofu plan` must report `No changes.`**
       Anything else means the migration did not carry the state `MW` just reconciled.
    3. **Adopt OpenTofu native state encryption (BR-D22)** — in the same change, because the
       state that lands in the org bucket is versioned **forever** and this is the last moment
       it is cheap. Add a `terraform { encryption { … } }` block with an `aws_kms` key provider
       to **both roots** (`environments/ai-lab` and `bootstrap/`).
       **Why this and not SSE.** SSE-S3 protects the object at rest in S3 and nothing else — it
       does not protect state from anyone who can legitimately `s3:GetObject` it, and after
       ~~ST-T2~~ **this sprint's Task 0** that set includes **a plan role assumable from any
       pull request**, whose state-read policy grants exactly that on exactly this prefix.
       *(Corrected 2026-08-07 by ST-T5 — the plan role arrives at Task 0, not in ST. **The
       ordering this creates is intra-sprint and therefore easier to get wrong, not easier to
       get right:** Task 0 mints the PR-assumable reader and Task 4 encrypts what it can read,
       in the same sprint. Do not let Task 0 land far ahead of Task 4.)* Client-side encryption closes it;
       SSE-KMS would not have. This is also what makes the BR-D21 secrets pattern honest — a
       `data.aws_ssm_parameter` value **is in state** (§ 9.5), so the encryption block must land
       **before** any SSM canary runs anywhere.
       **`required_version`:** native encryption needs OpenTofu ≥ 1.7, so
       `environments/ai-lab/providers.tf`'s existing `>= 1.8.0` already covers it — **no bump
       needed**. But **`bootstrap/providers.tf`'s `terraform {}` block declares no
       `required_version` at all**; give it one.
       **⚠️ `use_lockfile` is NOT adopted and `dynamodb_table` STAYS** (BR-D22, amended). Step 1
       repoints the lock table at the org's `global-tofu-lock`; it does **not** remove it. That
       table is shared with `bounty-infra`, `tri-loop` and `resume-optimizer`, so retiring it
       would force every consumer repo to raise its OpenTofu floor and rewrite its backend block
       in lockstep — a coordinated multi-repo migration against shared infrastructure for no
       risk reduction. *(Non-blocking check while you are here: Terraform deprecated
       `dynamodb_table` in 1.11 in favour of `use_lockfile`. Whether **OpenTofu** followed is
       unverified — read the changelog and record the answer. It does not change the decision.)*
    4. **Only then** retire `aws_s3_bucket.tofu_state` and `aws_dynamodb_table.tofu_locks` in
       `bootstrap/` — this repo's *own* bucket and lock table, not the org's. Both carry (or
       should carry) `prevent_destroy`; removing it is a deliberate, separate, human-applied
       change. **Keep the old bucket for at least one successful apply cycle on the new
       backend** before deleting anything.
  - **Target Files:** `environments/ai-lab/backend.tf`, `environments/ai-lab/providers.tf`,
    `bootstrap/state-backend.tf`, `bootstrap/providers.tf`
  - **Acceptance Criteria:** `tofu plan` reports `No changes.` from the new backend. A full
    apply cycle has succeeded against it. **The state object in the org bucket is
    client-side-encrypted — verified by `aws s3 cp`-ing it and confirming it does not parse as
    JSON**, which is the only check that distinguishes native encryption from SSE. Both roots
    declare a `required_version`. `environments/ai-lab/backend.tf` still declares
    `dynamodb_table`, now pointing at `global-tofu-lock`. The old bucket is deleted only after
    that, and the PR body states the date of the last successful apply on the old backend.
    `bootstrap/` contains no S3 or DynamoDB resource.

- **Task 5: Close the confused-deputy gap on the KB role (F4, issue #6)**
  - **Description:** *(Unchanged from the original plan — this is workload IAM, which stays
    this repo's own.)* Add an `aws:SourceArn` condition to `bedrock_kb_role`'s trust policy
    alongside `aws:SourceAccount`. The KB ARN is not knowable before the KB exists, so
    construct the pattern rather than referencing the resource:
    `"arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:knowledge-base/*"`
    under `ArnLike`. Do **not** reference `aws_bedrockagent_knowledge_base.rag_kb.arn` — that
    is a dependency cycle OpenTofu reports as an obscure graph error at plan time.
  - **Target Files:** `modules/aws-bedrock-rag/iam.tf`
  - **Acceptance Criteria:** The trust policy carries both `StringEquals aws:SourceAccount`
    and `ArnLike aws:SourceArn`. `tofu plan` shows an in-place update, no role replacement, no
    cycle error. `Closes: #6` in the PR body.

- **Task 6: ~~Make the AOSS data-plane principal explicit~~ — MOVED to `MW-T2`**
  - **Moved 2026-08-05 (BR-D23).** The `data_plane_principal_arns` variable, its validation
    block, and the `create_index.py`-must-succeed acceptance criterion now live in
    `sprints/MW_make_it_work/sprint_plan.md` as **MW-T2**. **Do not execute it from here.**
    F5 is the reason the pipeline has never worked, so it belongs in the sprint whose goal is
    making it work — not two sprints after the criteria that depend on it.
  - **What this sprint still assumes:** that `MW-T2` landed, so the CI role has AOSS data-plane
    access and `create_index.py` has succeeded at least once in CI.

---

## Definition of Done

`gates.green` passes. Every required check green. **A CI apply has succeeded against the org
backend, on the upstream roles.** *(The "first time in this repo's history" apply is now `MW`'s
Definition of Done, not this sprint's — `MW` runs first. What this sprint proves is that the
cycle still works after the identity and backend swap, which is a different and equally
necessary claim.)* The state object in the org bucket is client-side encrypted (BR-D22). `bootstrap/` contains no OIDC provider, no role,
no bucket, no table. `/way-of-working:critic-gate` has run: `security-critic` (every task is a trust
boundary or a credential scope) and `architect` (the adopt-verify-delete ordering is where a
logic error becomes an outage).

---

## Critical review

**Security**

- ~~**The re-scope removed a control this sprint was going to add — say so plainly.** The
  permissions boundary is no longer built *here*; it is built upstream in ST-T2.~~
  **↩️ REVERSED 2026-08-07 (ST-T5): the boundary came BACK to this sprint, as Task 0.** ST
  neither built it nor kept it — `ST-T2′` deleted the policy it would have constrained. So the
  concern this bullet raised is inverted: the risk is no longer *inheriting a weak upstream
  policy*, it is **writing a weak one here**, under the pressure of Task 2 being blocked behind
  it. That is precisely the dynamic ST Task 2b warned about and precisely why the boundary was
  moved to a sprint with **no irreversible act waiting on it**. The mitigation is unchanged in
  form and now applies to our own work: **Task 2's acceptance criterion checks the boundary
  policy's *shape* (Task 2b(4)'s allowlist grep), not merely that adoption happened** — and a
  boundary that breaks every apply gets **removed rather than corrected**, so getting it right
  matters more than getting it strict.
- **Adopt-verify-delete, never delete-adopt.** Every retirement here removes something CI is
  currently using. Deleting the local role before the upstream one is proven working leaves
  the pipeline with no identity, in a shared account, mid-sprint. The ordering is stated in
  each task and is the thing `architect` should check hardest.
- *`tofu state rm` in Task 3 is the correct verb and the dangerous one.* `destroy` would
  delete the provider every glunk-works pipeline depends on. The distinction is one word in a
  command and the blast radius differs by an organization.
- *An OIDC provider `import` that OpenTofu decides is a **replace** is an org-wide outage.*
  Task 3 requires pasting the plan's action character into the PR body — a `+`/`-` pair
  instead of an import is the signal to stop.
- *F47's local half closes when the local role dies (Task 2); its upstream half does not.*
  Four sibling roles still hold `iam:*` on `*` in the account that stores bounty-infra's
  findings archive. This sprint must not be read as having fixed that.

**Logic**

- **The teardown reversal is the largest single simplification in this roadmap, and it was not
  free to discover.** The original plan spent a task on `import` blocks, a decision (BR-D19)
  on never recreating, and three separate acceptance criteria in S3 built around avoiding
  resource replacement — all of it protecting embeddings and source documents that do not
  exist. One sentence from the operator ("nothing in here yet") deleted the lot. The lesson
  worth keeping: *a data-preservation constraint is worth confirming before it shapes a
  design*, because it is unusually expensive to assume and unusually cheap to check.
- **But the reversal has a hard edge, and conflating the two halves would be the failure
  mode.** "Nothing here is precious" is true of the **workload** and false of the **account**:
  the OIDC provider, `global-bootstrap`'s state, and bounty-infra's findings archive all sit
  in the same account (F47) and none is disposable. Task 1 deletes freely; Tasks 2–4 still
  move adopt-verify-delete. A coder that carries the teardown mindset into the identity tasks
  will delete a role before its replacement is proven and take CI down for the organization.
- **F39 gates this sprint AND S3+S4 — which is why it moved out of here entirely.** All three
  use "read the `tofu plan` output" as an acceptance criterion, and against a split-brain state
  those criteria check a fiction. The original plan made it *this sprint's* Task 1, which still
  left S1 building a pipeline around an apply that had never worked. BR-D23 moved it to **`MW`**,
  immediately after ST. The dependency is recorded in the roadmap's ordering hazards.
- **`No changes.` is the reconciliation criterion, not a successful apply.** An apply can
  succeed while state and reality still disagree (it simply creates the difference). Only a
  clean plan proves convergence.
- **The state `key` prefix must equal the `var.projects` map key.** `global-bootstrap` scopes
  each role with `s3:prefix = <project>/*`; a `key` of `bedrock-serverless-rag/terraform.tfstate`
  works and `ai-lab/terraform.tfstate` silently does not — and the resulting `AccessDenied`
  during `tofu init` reads as a credentials problem, which is a long way from the truth.
- **`MW-T2`'s acceptance criterion is a successful `create_index.py` run, not a valid plan.**
  *(Was Task 6 here.)* F5 has been latent in the committed IaC for months while `tofu validate`
  passed every time. The only evidence that matters is the data-plane call succeeding.
- *Retiring the local state bucket while it is the backend is a bootstrap paradox* — hence
  migrate first (Task 4 step 2), prove an apply cycle on the new backend, and only then
  remove the resource that used to hold the state describing itself.
- *F46 (the retry loop masking the 403) — **this objection was upheld and acted on**.* The
  original text read: *"not fixed here — it belongs to S4-T4 … after Task 6 the loop will simply
  stop being exercised, which is not the same as being correct."* Correct, and it was an argument
  for **moving F46**, not for accepting the gap. BR-D23 moved the retry fix into **`MW-T3`**, so
  the cause and the misleading semantics are now fixed in the same sprint — which also makes that
  sprint's own debugging loop twelve minutes shorter per iteration.

**Execution**

- *A coder agent cannot complete this sprint alone.* It prepares the HCL and the upstream PR;
  a human applies `bootstrap/` and `global-bootstrap`, deletes the orphaned workload
  resources, and confirms the observed-run criteria. Every criterion needing an apply says so.
- *The `import`-blocks-over-`tofu import` argument now applies only upstream (Task 3).* For the
  workload, BR-D20 removed the need to import at all. But the reasoning behind it still binds
  Task 3: a committed `import` block is reviewable in the PR and runs inside the gate S1 built,
  whereas a shell `tofu import` from a laptop is an unreviewed state mutation — the exact class
  of act that created F39 and F50 in the first place.
- *Keep the old state bucket for at least one successful cycle.* Deleting it the same day as
  the migration removes the only rollback path, and the failure it protects against
  (a migration that dropped a resource) is not visible until the next apply.
- *The account id will be tempting to paste* — into the F39 inventory table, the upstream PR,
  the deletion commands. It is BR-D4 restricted and both repos are public. Use `data.aws_caller_identity`
  in HCL and resource *names* in prose.
