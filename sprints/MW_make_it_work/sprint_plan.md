### FILEPATH: /sprints/MW_make_it_work/sprint_plan.md

# MW — Make it work

> **New sprint, created 2026-08-05 by BR-D23.** It is not new *work*: it pulls three existing
> tasks forward — **S2-T1** (teardown and rebuild), **S2-T6** (the AOSS data-plane principal)
> and **S4-T4's retry fix** — out of sprints scheduled fourth and sixth. Nothing here was
> invented; what changed is *when*.

**Sprint Goal:** Complete a full `destroy` → `apply` → verify cycle. Once. Successfully.
**From this sprint onward, every later sprint validates against a real system instead of a
plan of a fiction.**

**Closes:** **F51**, F39, F5, F46, **F55**.

> ### 📥 F55 is re-homed HERE, and re-pointed — recorded 2026-08-06, confirmed 2026-08-07 by ST-T5
>
> **F55 arrived from ST** with the 2026-08-06 reshape and lives in this sprint as the blocking
> **Task 0**. It was not merely moved, it was **re-pointed**: with `ST-T2′` deleting the
> upstream role, the identity whose sufficiency is in question is **this repo's own
> `github-actions-deploy-role`**, so F55 now targets `aws_iam_role_policy.state_access_policy`
> in **`bootstrap/state-backend.tf`** — a file in this repository. All four gaps re-verified
> present against that policy on 2026-08-06: no `aoss:*AccessPolicy`, no `iam:PassRole`, no
> `s3:GetBucket*`, no `s3:PutEncryptionConfiguration`.

**Dependencies:** **✅ ST is COMPLETE** (2026-08-07) — the transfer is done and CI authenticates
from `glunk-works/…` in real runs.

> **⚠️ Two dependencies this line used to carry are GONE, and both would stall the sprint if
> read literally** *(corrected 2026-08-07 by ST-T5)*:
>
> - ~~"and the corrected upstream policy is applied"~~ — **there is no corrected upstream
>   policy and there will not be one until S2-T0.** `ST-T2′` closed **F45** by *deleting* the
>   `bedrock-serverless-rag` entry, not by correcting it. Waiting on this condition means
>   waiting for something nobody will ever do; treating it as satisfied means adopting a role
>   that returns `NoSuchEntity`. **Neither. It does not apply.** See Task 0's struck option 1.
> - ~~"**ST-T2c** must have passed"~~ — **ST-T2c *is* this sprint's Task 0.** It moved here in
>   the same reshape, so this dependency pointed at a task that no longer exists in ST. The
>   gate it names is real and is enforced below; it is simply internal to this sprint now.

S1 has **not** run, and that is deliberate.

---

## Why this sprint exists

BR-D20 states that a clean `destroy` → `apply` → verify cycle is *"the acceptance test every
infrastructure sprint must ultimately pass."* **No sprint before this one could pass it**, and
no `tofu apply` has ever completed successfully in this project's history — every push-to-`main`
run is `failure` or `cancelled` (**F51**).

The original plan scheduled this work **fifth**, behind S0, ST, S1 and most of S2. That meant
S1 spent a full sprint building an Environment gate, a saved-plan apply, seven required checks
and a plan-summarizer **around an apply that had never once worked** — and S1's own Risks
section conceded the problem in its own words: *"a plan job that goes green here proves the
**job** works, not that the plan is accurate."* Meanwhile S3+S4 use "read the `tofu plan`
output" as an acceptance criterion, against a split-brain state that plans a system which is
not there.

Four defects sit on the cycle's path and they are cheapest to fix together, because each is
only observable once the one before it is gone:

| # | Defect | Why it blocks the cycle |
| --- | --- | --- |
| **F55** | The deploy identity cannot create what the module declares | The rebuild fails `AccessDenied` — *after* the teardown |
| **F39** | State does not describe the deployed system | Apply collides with `EntityAlreadyExists` |
| **F5** | The AOSS data-access policy names a human SSO session, not the CI role | `create_index.py` gets `403` forever |
| **F46** | The retry loop reports that `403` as a propagation delay | The failure takes ~12 minutes and names the wrong cause |

Each was filed separately as a security or correctness defect. **Together they are a functional
one.**

---

## ⚠️ The blocking gate — read this before deleting anything

> **The teardown is irreversible until F55 is closed. This is the single most expensive
> mistake available in this roadmap.**
>
> This sprint deletes every orphaned workload resource and rebuilds. The rebuild runs under
> the deploy identity's **current** policy, which grants `aoss:Create/DeleteSecurityPolicy`,
> `aoss:CreateCollection`, `bedrock:CreateKnowledgeBase`, `bedrock:CreateDataSource` — and
> **nothing else in those families**. The module declares at least four things it therefore
> cannot create or refresh (**F55**): `aws_opensearchserverless_access_policy`, the KB's
> `roleArn` (needs `iam:PassRole`), `aws_s3_bucket_server_side_encryption_configuration`
> (needs `s3:*EncryptionConfiguration` — `s3:PutBucket*` matches neither verb), and
> `aws_s3_bucket` refresh (needs `s3:GetBucketVersioning`/`GetBucketLocation`/`GetBucketTagging`).
>
> **These grants have never been exercised.** Run `26788807269` died at `EntityAlreadyExists`
> and a stalled bucket create — *before AOSS or Bedrock were ever reached*. So they become
> visible exactly once, at the worst possible moment.
>
> **The failure a literal executor hits:** inventory and delete the collection, the Knowledge
> Base, the bucket and the KB role; run the pipeline; get `AccessDeniedException` on
> `CreateAccessPolicy`. The working — if orphaned — system is now gone, and the rebuild is
> blocked on a missing permission. F51 goes from *"never demonstrated"* to *"actively broken"*,
> and recovery needs an out-of-band human apply against the `bootstrap/` root being retired.
>
> **🔄 Corrected 2026-08-06 — the trap named here is smaller than written, and the reason is
> load-bearing.** This paragraph used to say the rebuild would be blocked on a permission
> **"this repo cannot grant itself, once ST-T2 moved the policy upstream."** ST no longer moves
> the policy upstream: **`ST-T2′` deletes the upstream entry outright** (closing F45 by removal),
> so after ST the deploy identity is still **this repo's own `github-actions-deploy-role`**, and
> its policy is still `aws_iam_role_policy.state_access_policy` in **`bootstrap/state-backend.tf`
> — a file in this repository, editable by a normal PR plus a human apply.** The recovery path
> is therefore *open*, not closed. That makes **option 2 below the default rather than the
> fallback**, and it removes the coupling to S2's switchover that option 1 carries.
>
> **What does NOT change: the gate.** Sufficiency is still a precondition, and the four gaps
> are still real — re-verified against `state_access_policy` on 2026-08-06: no
> `aoss:*AccessPolicy` verbs, no `iam:PassRole`, no `s3:GetBucket*`, no
> `s3:PutEncryptionConfiguration`. Deleting a working system before proving the rebuild works
> is the expensive mistake whether or not the fix is reachable afterwards.
>
> **Gate: Task 0 must pass before Task 1 deletes anything.** Sufficiency is a *precondition*,
> never a discovery.

---

## Tasks

- **Task 0 (blocking, F55): Prove the deploy identity can rebuild from scratch**
  - **Description:** Demonstrate — before any deletion — that the identity the rebuild will run
    under can create everything the module declares. Two ways were offered; **after ST's
    2026-08-06 reshape only option 2 is viable** — option 1 is struck below with its reasoning
    retained, because "adopt the upstream role first" is the natural instinct and it now leads
    somewhere bad. Record in the PR body that option 2 was taken **and why option 1 was not**:
    1. **~~Adopt first.~~ — NOT AVAILABLE after ST (struck 2026-08-06).** This read: *bring
       forward S2-T2's adopt step so the rebuild runs under the corrected upstream role.*
       **There is no corrected upstream role.** `ST-T2′` deleted the `bedrock-serverless-rag`
       entry from `var.projects`, and **S2-T0 re-creates it — two sprints after this one.**
       Attempting this option means either waiting on a sprint that runs later, or re-adding the
       upstream entry here *without* the boundary construction, which reopens **F41** to unblock
       a rebuild. Do neither.
    2. **Widen first — now the DEFAULT, not the fallback.** Extend `state_access_policy` with the
       missing verbs — `aoss:*AccessPolicy`,
       `iam:PassRole` (conditioned on `iam:PassedToService = bedrock.amazonaws.com`),
       `bedrock:Get*`/`TagResource`, `s3:*EncryptionConfiguration`/`GetBucket*` — as a temporary
       measure on a role S2 then deletes.
    **⚠️ Regenerate the verb list from the dry run, not from the list above or from F55.**
    That list is indicative; its source advisory rates confidence *high* that the named verbs
    are missing and required, and only *medium* that the list is complete.
  - **Target Files:** `bootstrap/state-backend.tf` (option 2), or `.github/workflows/` +
    repository variables (option 1)
  - **Acceptance Criteria:** A recorded dry run showing a from-scratch create path with **no
    `AccessDenied`**, linked from the PR body. Which option was taken, and why, is stated.
    **Task 1 does not begin until this is green.**

- **Task 1 (F39, F51): Reconcile state by teardown and rebuild**
  - **⚠️ BR-D19 is REVERSED. Do not write `import` blocks.** This task once said *import, never
    recreate*, to protect embeddings and source documents. **There are none** — the corpus is
    empty and the collection holds nothing (BR-D20). Importing would be slower, riskier, and
    would freeze the current bad resource names into the configuration. Delete the orphans, fix
    the IaC, apply clean. The **only** exemption is anything shared with the organization — the
    OIDC provider above all (BR-D18).
  - **Description:** Run `26788807269` proves the split brain: `EntityAlreadyExists: Role with
    name personal-bedrock-kb-execution-role already exists`, and a stalled
    `waiting for S3 Bucket (…-source) create`. The resources were created out-of-band with human
    SSO credentials; CI's state does not contain them.
    1. **Inventory what actually exists.** For each resource the module declares, check AWS
       directly (`aws iam get-role`, `aws s3api head-bucket`,
       `aws opensearchserverless batch-get-collection`, `aws bedrock-agent list-knowledge-bases`,
       and the three AOSS policy APIs). Write the result into `docs/hardening_roadmap.md` under
       F39 as a table: resource → exists in AWS? → present in state? **Record resource *names*
       only — no ARNs, no account id** (BR-D4).
    2. **Delete the orphans**, after confirming from step 1 that each is genuinely this
       project's and genuinely empty. **Never** touch the OIDC provider or anything
       `global-bootstrap` owns.
    3. **Apply clean** — every resource created by the pipeline, not by hand.
    4. **Then prove the cycle**: `tofu destroy` → `tofu apply` → an end-to-end
       `RetrieveAndGenerate` query. That round trip, not a passing plan, is what closes F51.
    5. **Take the opportunity the rebuild grants.** Fix the resource names now (the task
       formerly known as **S3-T6**, folded in here by BR-D23 — the original plan already
       conceded that *"doing it during the rebuild costs nothing at all"*, and doing it
       separately buys a second replacement cycle for nothing). In particular, close the
       `CLAUDE.md` hazard: `opensearch.tf` writes `collection/bedrock-rag-store` as a **literal**
       inside both security policies while the collection resource declares the same name
       separately — the two can silently diverge, and the failure surfaces as an unauthorized
       data plane, not a plan error.
  - **Target Files:** `environments/ai-lab/`, `modules/aws-bedrock-rag/`,
    `docs/hardening_roadmap.md`
  - **Acceptance Criteria:** `tofu plan` in `environments/ai-lab` reports **`No changes.`**
    against the live account. **A CI apply on `main` succeeds — the first one ever.** Then the
    full cycle green, closing **F51**. The F39 inventory table exists and contains no ARN or
    account id. **The PR body states explicitly that the OIDC provider was untouched.** No
    resource name is written as a literal in more than one place.

- **Task 2 (F5): Make the AOSS data-plane principal explicit**
  - **Description:** *(Was S2-T6.)* Run `26788807269` shows `create_index.py` failing
    `AuthorizationException(403, '')` six times — because `data.aws_arn.current_identity.arn`
    resolved to a **human SSO session** when the policy was last applied, so the CI role has no
    data-plane access at all. Not a latent risk: **it is the reason the pipeline has never
    worked.**
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
    `Principal` becomes `concat([aws_iam_role.bedrock_kb_role.arn], var.data_plane_principal_arns)`,
    and `environments/ai-lab` passes ~~**the upstream apply role**~~ **this repo's own
    `github-actions-deploy-role`** and the human operator's SSO role.
    > **⚠️ Corrected 2026-08-07 (ST-T5).** This said *the upstream apply role*, written when ST
    > was going to hand CI over to `github-actions-bedrock-serverless-rag`. **That role does not
    > exist** — `ST-T2′` deleted it, and `S2-T0` re-creates it two sprints from here. Passing an
    > ARN read from `global-bootstrap`'s `github_actions_role_arns` output yields an **empty
    > string**, which the `validation` block above rejects at plan time — a good failure, but a
    > confusing one if you are looking for a typo. **Pass the role CI actually assumes**, i.e.
    > the one `vars.AWS_OIDC_ROLE_ARN` names today. **S2-T2 must re-point this list when it
    > switches over** — the data-plane grant does not follow the identity automatically, and a
    > forgotten entry here reproduces **F5** exactly: a `403` from `create_index.py` naming
    > nothing useful.

    Both are BR-D4 *restricted*: source them from `.env` locally and a repository variable
    in CI, **never** a committed `.tfvars`.
  - **Target Files:** `modules/aws-bedrock-rag/iam.tf`, `modules/aws-bedrock-rag/variables.tf`,
    `environments/ai-lab/main.tf`, `environments/ai-lab/variables.tf`
  - **Acceptance Criteria:** A **successful `create_index.py` run in CI** — not a valid plan.
    `grep -rn 'aws_arn.current_identity' modules/ environments/` returns nothing. No ARN appears
    in a committed file or a workflow log.

- **Task 3 (F46): Make the failure diagnosable**
  - **Description:** *(Was S4-T4's retry half, pulled forward two sprints.)* `create_index.py`
    retries any `Exception` six times; run `26788807269` shows six consecutive
    `AuthorizationException(403, '')` — a condition that **can never resolve by waiting**,
    because it is F5, not IAM eventual consistency. Commit `0aa56dc` raised the delay to 45 s,
    so CI now spends **~12 minutes** failing at it. *(The most recent work on this repo before
    the hardening effort was tuning the wrong variable — worth noting, because the retry loop
    is convincing.)*
    **Retry only what can succeed on a retry.** Catch the authorization failure separately and
    fail fast with a message naming the actual cause; keep the backoff for genuine eventual
    consistency only.
    **⚠️ Order matters within this sprint:** this lands with — ideally *before* — Task 2's
    verification. Without it, the sprint whose entire purpose is diagnosis is the least
    diagnosable one, and a 403 that means "your policy is wrong" is indistinguishable from a
    403 that means "wait".
    **Do not also do S4-T4's destructive-delete guard here.** That is the `create_index.py`
    "delete the index if it exists" path, which stays in S3+S4 — it costs nothing today
    (BR-D20: the index is empty) and it is a forward-looking rule under BR-D10.
  - **Target Files:** `environments/ai-lab/create_index.py`
  - **Acceptance Criteria:** An authorization failure exits in **under a minute** with a message
    that names the authorization cause. The retry path still covers genuine eventual
    consistency. **The exception text does not reach the log** — bare `print(e)` renders the
    collection endpoint and caller identity into a public workflow log (**F31**, BR-D4); fix it
    here since the file is open, and note it in S5's list as closed early.

---

## Definition of Done

`gates.green` passes. **A `destroy` → `apply` → verify cycle has completed end-to-end, in CI,
observed in real run links** — this is the whole sprint and no partial credit substitutes for
it. F51, F39, F5, F46 and F55 are marked closed with the run links that prove each. Nothing
shared with the organization was deleted, stated explicitly in the PR body. `/way-of-working:critic-gate` has
run — propose `security-critic` (Task 0 changes an IAM policy, Task 2 changes a data-plane
access policy) and `architect` (this sprint touches the module, the environment and the
scripts at once).

---

## Critical review

**Security**

- **The teardown is the only irreversible act in this roadmap that a coder can perform alone.**
  Every other high-consequence step needs a human apply or an org-owner click. This one is
  `aws s3 rb` and friends, and its safety rests entirely on Task 0 having been run first. That
  is why Task 0 is a task and not a bullet inside Task 1 — an ordering that exists only as
  prose is an ordering that gets reversed under time pressure.
- **"Delete the orphans" and "never delete anything shared" sit two lines apart**, and the
  distinction is load-bearing (F47). The workload is disposable; the account is not. Task 1's
  acceptance criterion makes the operator *state* that the OIDC provider was untouched rather
  than merely not mention it, because a silent omission and a careful check look identical in a
  PR body.
- **Option 2 of Task 0 widens a role this sprint does not delete.** `state_access_policy` gains
  `iam:PassRole` and lives on until S2-T2 — so the widening **must** be recorded as temporary,
  with S2-T2 named as its removal, or it becomes permanent by forgetting. ⚠️ **This is now the
  only path, so the mitigation is the only mitigation** *(corrected 2026-08-07 by ST-T5; this
  bullet used to end "Option 1 avoids this entirely and is preferred where S2's switchover can
  be pulled forward cleanly", which contradicts the blocking gate above — option 1 was struck
  on 2026-08-06 because `ST-T2′` deleted the role it adopts)*. Write the removal into S2-T2's
  step 3 in the same PR that widens, not afterwards: a temporary grant whose removal is
  recorded only in a PR body is a permanent grant with a good story.

**Logic**

- **This sprint can fail in a way that is not a defect.** If the cycle does not complete, the
  correct outcome is a documented reason, not a widened permission. The pressure here runs
  exactly the wrong way: the sprint's success criterion is "it works", and the fastest route to
  "it works" is always to grant more. Any grant made to close this sprint is recorded in the PR
  body with the finding it re-opens.
- **F31 is fixed here opportunistically**, which is a scope departure worth naming: it belongs
  to S5. It is included because Task 3 already opens the file, the fix is one line, and the
  finding is an active BR-D4 disclosure into a public log. S5's entry is marked closed-early
  rather than silently dropped.
- **Nothing in this sprint depends on S1.** That is the point of the reordering, and it should
  be re-checked if S1 is ever pulled earlier: an Environment gate around this sprint's applies
  would add a human approval to every iteration of a debugging loop.

**Execution**

- **A coder agent can do most of this**, but Task 1 step 2 deletes live AWS resources and Task 0
  option 1 changes which role CI assumes. Both want a human eye on the *inventory* before the
  deletions run — the inventory table is the artifact that makes the deletion reviewable.
- **The retry fix should land before the long debugging loop starts**, not after it. Twelve
  minutes per iteration is what turns a half-day sprint into a two-day one.
- **`AWS_PROFILE` must be set in the shell** for any local verification (`$env:AWS_PROFILE = "admin-sso"`)
  — `bootstrap/providers.tf` sets no profile (F49).
