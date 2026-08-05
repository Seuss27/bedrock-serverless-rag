### FILEPATH: /sprints/S3_data_plane_posture/sprint_plan.md

# S3 — Data-plane and IaC posture

**Sprint Goal:** Close the storage and network gaps around the document corpus and the
vector store, and make the IaC describe its own names instead of repeating them as string
literals.

**Closes:** F6, F7, F8, F9, F10, F11, F12.

**Dependencies:** **S2 must be merged — and S2-T1 in particular.** Every acceptance
criterion below is a statement about `tofu plan` output ("shows an update, not a
replacement", "`No changes.`", "tag additions and no replacements"). Until S2-T1 reconciles
state by import, **the plan describes a system that is not deployed** (F39: the resources
exist in AWS and are absent from CI's state; no CI apply has ever succeeded). Running S3
before that reconciliation means checking those criteria against a fiction.

Beyond that: every resource here is created by the CI role, so hardening the data plane
while that role can escalate to admin protects the wrong thing first. And the upstream
workload policy (ST-T2) must already permit the new resource types below — KMS, S3 logging,
CloudWatch — or the apply fails on a permission this repo cannot grant itself. Check that
first; widening it is a pull request against `global-bootstrap` and a human apply there.

**Security Considerations:** ⚠️ **Rewritten 2026-08-05 (BR-D20).** This section previously
warned that two changes here — the CMK switch (Task 4) and any collection rename (Task 6) —
would **destroy data**, and built elaborate pre-flights around that. **The corpus is empty
and the collection holds nothing**, so replacement costs a few minutes of apply time and
nothing else. Those cautions are withdrawn: **let it replace.** Prefer the correct end state
over a preserved one.
What genuinely remains: every resource here is created by a CI role that can still escalate
to account administrator in an account shared with the whole organization (F1/F47) — so the
*permission* work in S2 protects something real even though the *data* work here does not.

**Risks & Blockers:**
- Task 1 depends on an **externally verifiable fact** — whether Amazon Bedrock Knowledge
  Bases can reach a VPC-restricted OpenSearch Serverless collection. Verify it against
  current AWS documentation before designing; do not assume either answer.
- OpenSearch Serverless bills by OCU-hour. A collection replacement means paying to re-embed
  the whole corpus. Confirm the corpus is re-ingestible (the S3 originals still exist) before
  any task that can trigger a replacement.

---

## Tasks

- **Task 1: Remove public reach from the vector data plane (F6)**
  - **Description:** The network policy currently sets `AllowFromPublic = true` for **both**
    the `collection` and the `dashboard` resource types. Two separable changes:
    1. **Unconditional:** split the policy into two rule entries and set the **dashboard**
       entry to non-public. Nothing in this system uses the OpenSearch Dashboards UI; a
       public dashboard endpoint over the corpus is reach with no consumer.
    2. **Conditional on verification:** determine from current AWS documentation whether a
       Bedrock Knowledge Base can use a collection whose network policy restricts the
       `collection` resource type to a VPC endpoint. **If yes**, add
       `aws_opensearchserverless_vpc_endpoint` (VPC, two private subnets, a security group
       allowing only 443 from itself) and restrict the collection entry to it; the
       `create_index.py` path then needs a VPC-attached runner or a documented bastion, and
       that becomes an S4 dependency. **If no**, keep the collection entry public and record
       it as a new decision **BR-D16** in the roadmap, naming the compensating controls that
       carry the risk instead: SigV4-only access, the tightened data-access policy from
       S2-T6, the CMK from Task 4, and the logging from S4-T2. Cite the documentation you
       read, with the date.
    Either way, write the outcome down. An accepted risk that is recorded is a posture; an
    accepted risk that is silent is a finding.
  - **Target Files:** `modules/aws-bedrock-rag/opensearch.tf`,
    `docs/hardening_roadmap.md`, possibly new `modules/aws-bedrock-rag/network.tf`
  - **Acceptance Criteria:** The `dashboard` rule entry has `AllowFromPublic = false` (or the
    dashboard entry is removed entirely). The roadmap contains either the VPC-endpoint design
    or BR-D16 with a dated documentation citation. `tofu plan` shows an **update** to the
    network policy, **not** a replacement of `aws_opensearchserverless_collection.vector_store`
    — if a replacement appears, stop and report.

- **Task 2: Harden the S3 source bucket (F7)**
  - **Description:** Add to `modules/aws-bedrock-rag/iam.tf` (or a new `s3.tf` — the bucket
    does not belong in a file named `iam.tf`):
    - `aws_s3_bucket_public_access_block` with all four flags `true`. This is the single
      highest-value control in the sprint: it makes accidental exposure structurally
      impossible rather than merely absent.
    - `aws_s3_bucket_versioning` — `Enabled`. Source documents are the only unreproducible
      asset here; the embeddings are derived.
    - `aws_s3_bucket_policy` with a `Deny` on `s3:*` where
      `Bool {"aws:SecureTransport": "false"}`, and a second `Deny` on `s3:PutObject` where
      `StringNotEquals {"s3:x-amz-server-side-encryption": ...}` matching Task 4's choice.
    - `aws_s3_bucket_logging` to a separate, dedicated log bucket (itself with a public
      access block, versioning, and a lifecycle rule) — never logging into itself.
    - `aws_s3_bucket_lifecycle_configuration` with `abort_incomplete_multipart_upload` after
      7 days.
    - **`force_destroy` stays `true` — reversed 2026-08-05 (BR-D20).** The original plan
      flipped it to `false` to stop a `tofu destroy` deleting the corpus. There is no corpus,
      and this project exists to be torn down: `force_destroy = false` on a bucket with
      objects in it makes `tofu destroy` **fail**, which works directly against the design
      goal and against F51. Make it a **variable defaulting to `true`**, with a comment that
      it flips to `false` on the day a real corpus is ingested — the same day BR-D10 stops
      being forward-looking.
  - **Target Files:** `modules/aws-bedrock-rag/s3.tf` (new),
    `modules/aws-bedrock-rag/iam.tf`, `modules/aws-bedrock-rag/variables.tf`
  - **Acceptance Criteria:** Checkov's S3 checks pass on `modules/` with no suppression.
    `aws s3api get-public-access-block --bucket <name>` returns all four `true` after apply.
    A `curl` of any object URL over plain HTTP is denied. `grep 'force_destroy' modules/`
    shows a `var.` reference, and the variable's default is `false`.

- **Task 3: ~~Harden the state backend (F8)~~ — SUPERSEDED by S2-T4**
  - **⚠️ Do not execute this task.** BR-D17 resolved in favour of `global-bootstrap` owning
    the state backend, so **S2-T4 migrates this repo's state to
    `glunk-works-tofu-state-00042` under the `bedrock-serverless-rag/` prefix and retires
    `personal-bedrock-lab-state` and `bedrock-lab-state-locks` entirely.** Hardening a bucket
    that is being deleted is wasted work — and worse, it would be recorded as F8 closed.
    F8's substance is inherited rather than abandoned: the org bucket already has versioning
    and encryption, and it adds the genuine per-project prefix isolation this repo's backend
    never had. **If S2-T4 has landed, mark F8 closed-by-supersession and skip to Task 4.**
    The text below is retained only for the case where the migration is abandoned and this
    repo keeps its own backend.
  - **Description (retained, not scheduled):** In `bootstrap/`: add `aws_s3_bucket_public_access_block` and a
    TLS-only `aws_s3_bucket_policy` to the state bucket; add
    `lifecycle { prevent_destroy = true }` to `aws_dynamodb_table.tofu_locks` (the bucket has
    one, the table does not — so a `tofu destroy` in `bootstrap/` today removes state locking
    while leaving state intact, which is the worst of both); enable
    `point_in_time_recovery` on the table; add a lifecycle rule expiring non-current state
    versions after 90 days so versioning does not accumulate an unbounded, ARN-rich history.
    **Human apply, per BR-D1.**
  - **Target Files:** `bootstrap/state-backend.tf`
  - **Acceptance Criteria:** `tofu plan` in `bootstrap/` shows only additions and in-place
    updates — **no replacement of `aws_s3_bucket.tofu_state` and no replacement of the lock
    table**. Checkov passes on `bootstrap/`. A human has applied and confirmed the pipeline
    still reads and writes state.

- **Task 4: Customer-managed keys (F9)**
  - **Description:** Replace AWS-owned encryption with a CMK for the corpus and the vector
    store: an `aws_kms_key` (rotation enabled, a key policy granting the account root
    admin, the Bedrock KB role `Decrypt`/`GenerateDataKey` via
    `kms:ViaService = s3.<region>.amazonaws.com`, and the AOSS service principal what it
    needs), then set the S3 bucket's SSE to `aws:kms` with `bucket_key_enabled = true` and
    the AOSS encryption policy to `KmsARN` instead of `AWSOwnedKey = true`.
    **Pre-flight withdrawn 2026-08-05 (BR-D20).** This task used to require checking whether
    the encryption-policy change forces a collection replacement, and to forbid applying if
    it did. The collection is empty — a replacement costs an apply, not data. **Let it
    replace.** Do still *read* the plan and state in the PR body whether a replacement
    occurred, because that is a fact worth knowing about the resource's behaviour before the
    day it holds something.
  - **Target Files:** new `modules/aws-bedrock-rag/kms.tf`,
    `modules/aws-bedrock-rag/opensearch.tf`, `modules/aws-bedrock-rag/s3.tf`,
    `modules/aws-bedrock-rag/iam.tf` (KB role needs `kms:Decrypt` +
    `kms:GenerateDataKey` on the key)
  - **Acceptance Criteria:** The `tofu plan` output for this task is pasted into the PR body
    as a **summary** (addresses and actions only, BR-D4) showing every action taken, with an
    explicit line stating whether a collection replacement appeared. The KB role's policy
    gains the two KMS actions in the **same** change that switches the bucket to `aws:kms` —
    otherwise ingestion breaks with an opaque `AccessDenied` on the next sync.

- **Task 5: Tag every resource (F10)**
  - **Description:** Add `default_tags` to the `provider "aws"` block in **both**
    `environments/ai-lab/providers.tf` and `bootstrap/providers.tf`:
    `owner`, `managing-repo` (`Seuss27/bedrock-serverless-rag`), `environment`
    (`ai-lab` / `global`), `cost-center` (`personal-lab`), `managed-by` (`opentofu`). The
    conventions require owner + managing-repo so drift is attributable to a repo; the cost
    tag matters because OpenSearch Serverless bills OCU-hours whether or not anyone queries.
  - **Target Files:** `environments/ai-lab/providers.tf`, `bootstrap/providers.tf`
  - **Acceptance Criteria:** `tofu plan` shows tag additions and **no replacements**. Verify
    specifically that `aws_opensearchserverless_collection` and
    `aws_iam_openid_connect_provider` show in-place updates — if either would be replaced,
    exclude it from `default_tags` with a comment rather than accepting the replacement.

- **Task 6: Parameterize names — without replacing anything (F11)**
  - **Description:** Introduce variables for the four hardcoded names (`collection_name`,
    `index_name`, `knowledge_base_name`, `kb_role_name`) and, critically, replace the
    **string literals** `"collection/bedrock-rag-store"` inside both security policies with
    `"collection/${var.collection_name}"` — today the collection resource and the two
    policies that authorize it declare the same name independently, so a rename
    desynchronizes them and the failure surfaces as an unauthorized data plane, not a plan
    error.
    ⚠️ **Reversed 2026-08-05 (BR-D20).** This task used to demand that every variable default
    be the *exact current literal*, making it a pure refactor whose success criterion was
    `No changes.` — because a rename would replace the collection and lose the embeddings.
    Nothing is stored, so that constraint was protecting nothing while **freezing today's
    inconsistent names into the configuration permanently**. Instead: **pick good names now**,
    on the naming convention in `docs/hardening_roadmap.md` § 7 (`snake_case` for resource
    addresses, a documented `<project>-<env>-<component>` shape for AWS names), and accept the
    replacement. This is the cheapest hour this repo will ever have to fix its nomenclature —
    and doing it during S2-T1's rebuild costs nothing at all.
    Also add a `validation` block on `collection_name` enforcing the AOSS constraint
    (3–32 chars, lower-case alphanumeric and hyphen, must start with a letter) so a bad
    value fails at plan time rather than mid-apply.
  - **Target Files:** `modules/aws-bedrock-rag/variables.tf`,
    `modules/aws-bedrock-rag/opensearch.tf`, `modules/aws-bedrock-rag/bedrock.tf`,
    `modules/aws-bedrock-rag/iam.tf`
  - **Acceptance Criteria:** No hardcoded name literal remains outside a `variables.tf`
    default. Every name follows § 7's convention. `tofu destroy` → `tofu apply` succeeds
    end-to-end afterwards and a query returns a result — replacement is expected and fine;
    a *broken cycle* is not (F51, BR-D20).

- **Task 7: Align provider versions and the backend locking mechanism (F12)**
  - **Description:** `environments/ai-lab` pins `~> 5.0` while `bootstrap` pins `~> 6.0`.
    Move both to `~> 6.0` and regenerate both `.terraform.lock.hcl` files
    (`tofu init -upgrade`). Provider 6 changes the S3 backend's locking: `dynamodb_table` is
    superseded by `use_lockfile = true`. **Do not switch locking in this task** — migrate the
    version first, confirm a plan and an apply both work with `dynamodb_table` still set, and
    file the lockfile migration as its own issue. Two mechanisms changing at once on the
    state backend is how a repo loses the ability to plan.
    Read the AWS provider v6 upgrade guide and check for breaking changes affecting
    `aws_s3_bucket_*`, `aws_opensearchserverless_*`, and `aws_bedrockagent_*` before
    committing.
  - **Target Files:** `environments/ai-lab/providers.tf`,
    `environments/ai-lab/.terraform.lock.hcl`, `bootstrap/.terraform.lock.hcl`
  - **Acceptance Criteria:** Both roots declare `~> 6.0`. Both lock files are committed and
    contain v6 hashes for `linux_amd64` **and** `windows_amd64` (CI is Linux, the workstation
    is Windows — a lock file missing the runner's platform fails `init` with a checksum
    error). `tofu validate` exits 0 in both roots. `tofu plan` in `environments/ai-lab`
    reports no unexpected diff attributable to the provider bump.

- **Task 8: Remove Infisical, and pilot the org's AWS-native secret pattern (F53, BR-D21)**
  - **⚠️ Independent of the rest of S3 — pull it forward freely.** It touches only
    commented-out code and docs, so it carries no apply risk and blocks nothing.
  - **⚠️ This is a PILOT, not a cleanup (roadmap § 9.5).** `bounty-infra` and
    `loop-orchestrator` follow as time permits, so the deliverable is a **pattern another repo
    can copy**, not a tidy `providers.tf`. Two consequences shape the steps below: the pattern
    must be **executed, not just written** (step 3), and the pattern doc belongs **upstream**,
    not only in this README (step 5).
  - **Prerequisite, and it is not a code change: F52.** `environments/ai-lab/.env` holds a
    live Infisical machine-identity client secret. It was verified **never committed** and is
    correctly gitignored, so there is no disclosure — but the project is leaving Infisical, so
    the credential must be **revoked in the Infisical console first**, then the file cleaned.
    Deleting the file removes a copy, not the credential. Do the revocation before this task,
    not after.
  - **Description:**
    1. **Delete** — do not re-comment — the dead Infisical scaffolding: the `infisical`
       block in `required_providers`, the `provider "infisical"` block, the
       `data "infisical_secrets" "cloudflare_secrets"` block, the `provider "cloudflare"`
       block it fed, and `variable "infisical_workspace_id"`. PR #13 commented these out
       rather than removing them; commented-out code that contradicts the live README is
       worse than either alone (F53). If the Cloudflare integration is genuinely wanted
       later, `git log` is the record — a commented block is not a design document.
    2. **Establish the pattern before the first secret exists** (BR-D21), which is the
       cheapest moment to set it. Add a short § *Secrets* to `README.md` stating the three
       tiers: **secrets** → AWS SSM Parameter Store `SecureString` at
       `/bedrock-serverless-rag/<env>/<name>`, read via `data.aws_ssm_parameter`;
       **restricted-but-not-secret** (account id, role ARNs, bucket names, the collection
       endpoint) → GitHub Actions *variables* and tofu variables, never a secret store and
       never a workflow log (BR-D4); **neither** → plain committed config. Note why Parameter
       Store rather than Secrets Manager: the standard tier is free, Secrets Manager bills per
       secret per month, and this is a cost-sensitive ephemeral lab (BR-D20). Secrets Manager
       is a per-case decision requiring rotation or cross-account sharing, recorded when made.
    3. **Prove the path end-to-end with a disposable parameter, then destroy it.** This is
       the pilot's real work and it resolves a genuine tension: this repo holds **no secrets**
       (`gh secret list` is empty; the only variables are `AWS_OIDC_ROLE_ARN` and
       `DATA_SOURCE_BUCKET_NAME`), so leaving a standing SSM parameter would be exactly the
       empty-scaffolding this task removes — but a pattern that has never been executed is a
       proposal, and the repos that follow have real secrets and deserve better.
       So: create `/bedrock-serverless-rag/ai-lab/_pilot-canary` as a `SecureString`, grant the
       CI role `ssm:GetParameter` + `kms:Decrypt` scoped to that path, read it with
       `data.aws_ssm_parameter`, confirm a CI run resolves it — **and then delete the
       parameter, the grant, and the data source in the same PR.** Create, verify, destroy is
       the most BR-D20-native way to test anything here.
       **Record two things while doing it**, because they are what the next repo will trip on:
       (a) an SSM value read via `data.aws_ssm_parameter` **lands in state**, and state renders
       in `tofu plan` output — so a secret consumed this way is BR-D4-restricted from that
       moment on, and plan output must stay summarized; (b) the exact IAM statement needed,
       including `kms:Decrypt` on the `alias/aws/ssm` key, which is the omission that produces
       an `AccessDenied` naming neither SSM nor the key.
    4. Update `README.md`'s prerequisites, tech-stack line, and Step 1 — all of which still
       instruct the reader to create the credential F52 says to revoke. Full README rewrite
       stays S6-T1; this is the minimum to stop the docs being actively harmful.
    5. **Hand the pattern upstream.** Open a PR (or an issue with the content, if the shape is
       still open) on **`glunk-works/global-bootstrap`** — it already owns the account-level
       primitives an SSM pattern needs, so it should own the parameter-path convention and the
       per-project read grants. Include the three tiers, the two gotchas from step 3, and the
       finding that matters most to the repos that follow: **most of what they keep in
       Infisical is not secret.** `bounty-infra` holds `TF_STATE_BUCKET` and
       `AWS_OIDC_ROLE_ARN` there — restricted under BR-D4, but neither is a credential, so both
       become GitHub Actions *variables* rather than SSM parameters. Its genuinely secret
       values are few (`VULTR_API_KEY`, `GITLEAKS_LICENSE`). Framing their migration as a
       **re-tiering rather than a lift-and-shift** is the difference between a two-hour job and
       a two-day one.
  - **Target Files:** `environments/ai-lab/providers.tf`, `environments/ai-lab/variables.tf`,
    `README.md`
  - **Acceptance Criteria:** `grep -ri infisical . --exclude-dir=.git` returns hits **only**
    in `docs/hardening_roadmap.md` and `sprints/` (the historical record). `tofu validate`
    exits 0 in `environments/ai-lab`. `README.md` names AWS SSM Parameter Store as the secret
    store and no longer lists Infisical as a prerequisite. The Infisical machine identity has
    been **revoked** — confirmed by the operator, not assumed — and
    `environments/ai-lab/.env` no longer contains an `INFISICAL_*` key.
    **Pilot-specific:** a CI run is on record resolving the canary parameter (link it in the PR
    body), **and** `aws ssm get-parameter --name /bedrock-serverless-rag/ai-lab/_pilot-canary`
    returns `ParameterNotFound` afterwards — proving the mechanism worked *and* left nothing
    behind. The upstream PR or issue on `glunk-works/global-bootstrap` exists and is linked
    from `docs/hardening_roadmap.md` § 9.5.

---

## Definition of Done

`gates.green` passes. Every required check green. Checkov passes across the whole repo with
zero unjustified suppressions. Every `tofu plan` produced by this sprint has been read for
**replacements** and the finding stated explicitly in the PR body. `/critic-gate` has run —
propose `architect` (the replacement hazards are the whole risk here) and `security-critic`
(key policies and bucket policies are trust boundaries).

---

## Critical review

**Security**

- *A public-access block is not a bucket policy and neither is a substitute for the other.*
  The PAB blocks ACLs and public policies structurally; the bucket policy denies non-TLS
  transport and unencrypted uploads. Task 2 requires both because they fail differently.
- *A CMK adds a second way to lose the data.* A key policy that omits the Bedrock KB role
  produces `AccessDenied` on the next ingestion sync with a message that names neither the
  key nor the role; a scheduled key deletion destroys the corpus irrecoverably. Task 4
  therefore requires the KB role's KMS grants to land in the **same** change as the bucket's
  SSE switch, and the key must have rotation on and no deletion schedule.
- *Task 1 may conclude that public reach is unavoidable.* If Bedrock cannot reach a
  VPC-restricted collection, the honest outcome is a recorded decision (BR-D16) with named
  compensating controls — not a quietly unchanged file. The task is written so that "we
  checked and the answer is no" is a valid, documented completion, and "we didn't check" is
  not.
- *The log bucket is a new asset.* It must not log into itself (infinite recursion of
  objects) and must carry the same PAB. Stated inline.

**Logic**

- **Three tasks in this sprint can silently trigger a resource replacement**, and the same
  fact — `tofu plan` showing `must be replaced` — is the detection for all three: the
  encryption-policy change (Task 4), a name drift (Task 6), and a tag applied to a resource
  that does not support tag updates (Task 5). Each task's acceptance criterion is written as
  a statement about the *plan output* rather than the file content, because the file can look
  right and the plan still be destructive.
- **Task 6's success condition is `No changes.`** That inversion is deliberate: a
  parameterization refactor that produces a diff has changed a value, and the values in
  question are the ones that force collection replacement. A coder that "fixes" a small diff
  by accepting it is doing the exact damage the task exists to avoid.
- **Task 7 deliberately does not do the thing it appears to be setting up.** Bumping the
  provider *and* switching `dynamodb_table` → `use_lockfile` in one change means that if the
  result cannot plan, you cannot tell which half broke it — on the state backend, which is
  the one component whose failure blocks the fix. Split, with the second half filed as an
  issue.
- *Task 3 hardens `bootstrap/`, which is human-applied, inside a sprint whose other tasks are
  CI-applied.* That split is real and must be sequenced: `bootstrap/` applies first (a human,
  local), then the module changes go through the pipeline. A PR that lands both at once will
  have one half applied and the other pending until a human runs the other.
- *The ordering hazard with S4 stands:* S4-T4 rewrites `create_index.py` and
  `automation.tf`. Nothing in S3 touches either file, so S3 and S4 do not conflict — but if
  Task 1 concludes "VPC endpoint," `create_index.py` can no longer reach the collection from
  a public runner, and that becomes a hard dependency for S4-T4. Task 1 must say so in its
  written outcome.

**Execution**

- *Checkov will pass on this sprint's own PR only if the whole sprint lands together.* A
  partial PR that adds versioning but not the public-access block leaves the check red and
  invites a suppression. Land Task 2 as one unit.
- *Lock-file platform coverage is a recurring silent failure.* A lock file regenerated on
  Windows without `windows_amd64`+`linux_amd64` hashes fails `tofu init` on the runner with a
  checksum error that reads like corruption. Task 7 makes both platforms an explicit
  criterion; regenerate with
  `tofu providers lock -platform=linux_amd64 -platform=windows_amd64`.
- *`default_tags` interacts badly with resources that manage their own tags.* If a plan shows
  a perpetual diff on any resource's tags after Task 5, the fix is an explicit `tags` block
  on that resource, not removing `default_tags`.
