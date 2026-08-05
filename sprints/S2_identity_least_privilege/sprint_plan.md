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

**Sprint Goal:** This repo ends the sprint owning its **workload and nothing else**. No OIDC
provider, no CI role, no state bucket, no lock table — and a state file that finally
describes the system that is actually deployed.

**Closes:** F1 (Critical), F2, F3, F5, F39, F40, F42, F43, **F51**, and the local half of
F47. **F4** (confused deputy) is the one original task that survives unchanged.
**F41 is not closable here** — upstream, filed in ST-T2.

**Dependencies:** **ST must be complete** — the transfer is done, CI authenticates from
`glunk-works/…`, and `global-bootstrap`'s corrected `bedrock-serverless-rag` policy is
applied. **S1 must be merged** — the plan/apply job split is what makes two roles meaningful.

**Security Considerations:** The sprint's risk profile is inverted from the usual: the danger
is not adding a weak control, it is **deleting a working one before its replacement is
proven**. Every *identity* retirement below is therefore written as *adopt, verify, then
delete* — never *delete, then adopt*. That discipline applies to roles, trust policies and the
state backend; it does **not** apply to the workload resources, which BR-D20 makes freely
disposable. Keep the two straight: the account is shared with the organization (F47), so an
identity mistake does not fail locally, while a workload mistake costs an apply.

**Risks & Blockers:**
- **F39 makes `tofu plan` untrustworthy until Task 1 completes.** The resources exist in AWS
  and are absent from CI's state; a plan against that state describes a system that is not
  there. Several S3 and S4 acceptance criteria are "read the plan output" — **they are
  invalid until Task 1 lands.**
- Human `tofu apply` needed in `bootstrap/` (BR-D1) and in `global-bootstrap`.
- ⚠️ **Reversed 2026-08-05 (BR-D19/BR-D20).** This bullet used to read *"never resolve a state
  collision by deleting the live resource — the AOSS collection holds the embeddings."* It
  holds nothing; the corpus is empty. **Deleting the orphans and rebuilding is now the
  preferred remedy.** The rule that survives is narrower and absolute: **never delete anything
  shared with the organization** — the OIDC provider, `global-bootstrap`'s state bucket, or
  bounty-infra's findings archive, all of which live in the same account (F47).

---

## Tasks

- **Task 1: Reconcile state by TEARDOWN AND REBUILD (F39, F51) — do this first**
  - **⚠️ Reversed 2026-08-05 (BR-D19/BR-D20).** This task previously said *import, never
    recreate*, to protect embeddings and source documents. **There are none** — the corpus is
    empty and the collection holds nothing. Writing `import` blocks for every orphaned
    resource would be slower, riskier, and would freeze the current bad resource names into
    the configuration. Delete the orphans, fix the IaC, apply clean. The **only** thing
    exempt from teardown is anything shared with the organization — the OIDC provider above
    all (BR-D18).
  - **This task is also the fix for F51.** A clean `destroy` → `apply` → verify cycle is the
    project's core functional requirement (BR-D20) and has never once succeeded. Doing it
    closes F39, and forces F5 and F46 to be fixed on the way, because the cycle cannot
    complete while they stand.
  - **Description:** Run `26788807269` proves the split brain: `EntityAlreadyExists: Role with
    name personal-bedrock-kb-execution-role already exists`, and a stalled
    `waiting for S3 Bucket (…-source) create`. The resources were created out-of-band with
    human SSO credentials; CI's state does not contain them; **no CI apply has ever
    succeeded.**
    1. **Inventory what actually exists.** For each resource the module declares, check AWS
       directly (`aws iam get-role`, `aws s3api head-bucket`,
       `aws opensearchserverless batch-get-collection`,
       `aws bedrock-agent list-knowledge-bases`, and the three AOSS policy APIs). Write the
       result into `docs/hardening_roadmap.md` under F39 as a table: resource → exists in
       AWS? → present in state? Do **not** record ARNs or the account id (BR-D4) — resource
       *names* only.
    2. **Delete the orphans.** For each resource that exists in AWS but not in state, remove
       it — `aws iam delete-role`, `aws s3 rb`, `aws opensearchserverless delete-collection`,
       and so on — after confirming from step 1 that it is genuinely this project's and
       genuinely empty. **Never** touch the OIDC provider or anything `global-bootstrap`
       owns.
    3. **Apply clean** and confirm every resource is created by the pipeline, not by hand.
    4. **Then prove the cycle**: `tofu destroy` → `tofu apply` → query the RAG endpoint
       end-to-end. That round trip, not a passing plan, is what closes F51.
    5. Take the opportunity the rebuild grants: this is the moment to fix the resource names
       (S3-T6) and drop `force_destroy` questions, because nothing is being preserved.
  - **Target Files:** `environments/ai-lab/` (whatever the rebuild requires),
    `docs/hardening_roadmap.md`
  - **Acceptance Criteria:** `tofu plan` in `environments/ai-lab` reports **`No changes.`**
    against the live account. **A CI apply on `main` succeeds — the first one ever.** Then the
    full cycle: `tofu destroy` → `tofu apply` → a `RetrieveAndGenerate` query returns a
    result, all green, closing **F51**. The F39 inventory table exists in the roadmap and
    contains no ARN or account id. Nothing shared with the organization was deleted — state
    the OIDC provider was untouched, explicitly, in the PR body.

- **Task 2: Adopt `global-bootstrap`'s roles, then retire the local ones (F1, F2, F3, F42)**
  - **Description:** ST-T2 already added `plan_role = true` and
    `extra_oidc_subjects = ["environment:production"]` upstream and replaced
    `bedrock_rag_policy` with a boundary-constrained one. This task **switches over and
    cleans up**, in that order:
    1. **Adopt.** Point `vars.AWS_OIDC_ROLE_ARN` at `github-actions-bedrock-serverless-rag`
       and `vars.AWS_PLAN_ROLE_ARN` at `github-actions-bedrock-serverless-rag-plan`, from
       `global-bootstrap`'s `github_actions_role_arns` / `github_actions_plan_role_arns`
       outputs. Drop S1's `|| vars.AWS_OIDC_ROLE_ARN` fallback in `deploy.yml`.
    2. **Verify.** A PR plan job green on the plan role; a merge-to-`main` apply green on the
       apply role, through the `production` Environment gate. **Both observed in real runs.**
    3. **Only then delete**, in `bootstrap/`: `aws_iam_role.github_actions_role`,
       `aws_iam_role_policy.state_access_policy` — the F1 escalation — and
       `var.role_name` / `var.github_repo_path`. Human apply.
    F2 and F3 are closed by adoption rather than by fixing: the upstream role's trust is
    already `StringEquals` over an enumerated subject list, and the plan role already exists
    as a separate, read-only identity with its own `pull_request`-only trust.
  - **Target Files:** `bootstrap/oidc-setup.tf`, `bootstrap/state-backend.tf`,
    `.github/workflows/deploy.yml`
  - **Acceptance Criteria:** `grep -rn 'iam:CreateRole\|iam:PutRolePolicy' bootstrap/`
    returns nothing. `aws iam get-role --role-name github-actions-deploy-role` returns
    `NoSuchEntity`. `deploy.yml` contains no `||` fallback. A full PR→merge→approve→apply
    cycle has run green on the two upstream roles.

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
       Anything else means the migration did not carry the state Task 1 just reconciled.
    3. **Only then** retire `aws_s3_bucket.tofu_state` and `aws_dynamodb_table.tofu_locks` in
       `bootstrap/`. Both carry (or should carry) `prevent_destroy`; removing it is a
       deliberate, separate, human-applied change. **Keep the old bucket for at least one
       successful apply cycle on the new backend** before deleting anything.
  - **Target Files:** `environments/ai-lab/backend.tf`, `bootstrap/state-backend.tf`
  - **Acceptance Criteria:** `tofu plan` reports `No changes.` from the new backend. A full
    apply cycle has succeeded against it. The old bucket is deleted only after that, and the
    PR body states the date of the last successful apply on the old backend. `bootstrap/`
    contains no S3 or DynamoDB resource.

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

- **Task 6: Make the AOSS data-plane principal explicit (F5)**
  - **Description:** *(Re-scoped: the finding is now confirmed live, not predicted.)* Run
    `26788807269` shows `create_index.py` failing `AuthorizationException(403, '')` six times
    — because `data.aws_arn.current_identity.arn` had resolved to a **human SSO session** when
    the policy was last applied, so the CI role has no data-plane access at all. This is not a
    latent risk; it is the reason the pipeline has never worked.
    Remove `data.aws_arn.current_identity` and replace it with an explicit input:
    ```hcl
    variable "data_plane_principal_arns" {
      type        = list(string)
      description = "IAM role ARNs granted data-plane access to the vector collection. Must be role ARNs (arn:aws:iam::…:role/…), never sts assumed-role ARNs."
      default     = []
      validation {
        condition     = alltrue([for a in var.data_plane_principal_arns : can(regex("^arn:aws:iam::[0-9]{12}:role/", a))])
        error_message = "Each principal must be an IAM role ARN, not an sts assumed-role ARN."
      }
    }
    ```
    `Principal` becomes
    `concat([aws_iam_role.bedrock_kb_role.arn], var.data_plane_principal_arns)`, and
    `environments/ai-lab` passes **the upstream apply role** and the human operator's SSO
    role. Both are BR-D4 restricted: source them from `.env` locally and a repository variable
    in CI, never a committed `.tfvars`.
  - **Target Files:** `modules/aws-bedrock-rag/iam.tf`,
    `modules/aws-bedrock-rag/variables.tf`, `environments/ai-lab/main.tf`,
    `environments/ai-lab/variables.tf`
  - **Acceptance Criteria:** `grep -rn 'aws_arn' modules/ environments/` returns nothing.
    **`create_index.py` completes on the first attempt in a CI run** — no retries, no 403.
    That is the criterion; a passing `tofu validate` proves nothing here. The `validation`
    block rejects an `sts`-shaped ARN (verify with a deliberate bad value). Two plans — one
    local, one CI — produce the same access-policy diff.

---

## Definition of Done

`gates.green` passes. Every required check green. **A CI apply has succeeded** — for the
first time in this repo's history — against the org backend, on the upstream roles, with
`create_index.py` succeeding without retry. `bootstrap/` contains no OIDC provider, no role,
no bucket, no table. `/critic-gate` has run: `security-critic` (every task is a trust
boundary or a credential scope) and `architect` (the adopt-verify-delete ordering is where a
logic error becomes an outage).

---

## Critical review

**Security**

- **The re-scope removed a control this sprint was going to add — say so plainly.** The
  permissions boundary is no longer built *here*; it is built upstream in ST-T2. If ST-T2
  ships a weaker policy than drafted, this sprint's adoption step inherits that weakness and
  the roadmap will record F1 as closed. Task 2's acceptance criterion therefore checks the
  *upstream* policy's shape, not merely that adoption happened.
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
- **F39 gates S3 and S4, not just this sprint.** Both use "read the `tofu plan` output" as an
  acceptance criterion — for replacements, for `No changes.`, for tag-update safety. Against a
  split-brain state those criteria are checking a fiction. Task 1 is first for that reason,
  and the dependency is recorded in the roadmap's ordering hazards rather than only here.
- **`No changes.` is the reconciliation criterion, not a successful apply.** An apply can
  succeed while state and reality still disagree (it simply creates the difference). Only a
  clean plan proves convergence.
- **The state `key` prefix must equal the `var.projects` map key.** `global-bootstrap` scopes
  each role with `s3:prefix = <project>/*`; a `key` of `bedrock-serverless-rag/terraform.tfstate`
  works and `ai-lab/terraform.tfstate` silently does not — and the resulting `AccessDenied`
  during `tofu init` reads as a credentials problem, which is a long way from the truth.
- **Task 6's acceptance criterion is a successful `create_index.py` run, not a valid plan.**
  F5 has been latent in the committed IaC for months while `tofu validate` passed every time.
  The only evidence that matters is the data-plane call succeeding.
- *Retiring the local state bucket while it is the backend is a bootstrap paradox* — hence
  migrate first (Task 4 step 2), prove an apply cycle on the new backend, and only then
  remove the resource that used to hold the state describing itself.
- *F46 (the retry loop masking the 403) is not fixed here* — it belongs to S4-T4 with the rest
  of `create_index.py`. Task 6 removes the *cause*; the misleading retry semantics remain
  until S4. Worth knowing, because after Task 6 the loop will simply stop being exercised,
  which is not the same as being correct.

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
