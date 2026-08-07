### FILEPATH: /sprints/MW_make_it_work/sprint_plan.md

# MW — Make it work

> **New sprint, created 2026-08-05 by BR-D23.** It is not new *work*: it pulls three existing
> tasks forward — **S2-T1** (teardown and rebuild), **S2-T6** (the AOSS data-plane principal)
> and **S4-T4's retry fix** — out of sprints scheduled fourth and sixth. Nothing here was
> invented; what changed is *when*.

> ## 🔄 REVISED 2026-08-07 by the pre-implementation plan review — read this banner first
>
> The plan was reviewed against **live AWS and live GitHub**, not against its own text, before
> a single task ran. Five things changed, and the first one changes the sprint's shape:
>
> 1. **The premise of the blocking gate is spent.** AWS is empty apart from **one policy-less
>    IAM role**. There is no working-but-orphaned system to destroy, so the "expensive mistake"
>    the gate was built around **can no longer occur**. The gate survives in weaker form and
>    for a different reason — see § *The blocking gate*.
> 2. **The task order is wrong for the method.** `T0 → T1 → T2 → T3` puts the data-plane fix
>    *after* the run that tests it. The order below is the corrected one.
> 3. **The verb list was materially incomplete**, and not merely "indicative": `budgets:*`
>    was missing entirely because `budget.tf` landed *after* F55 was written, and
>    `aoss:APIAccessAll` was missing, which means **Task 2 as originally written does not fix
>    F5**. See § *The regenerated verb list*.
> 4. **`MW` could not reach its own Definition of Done.** CI job 1 fails at `ruff check`, so
>    the apply job has never run at all. Nothing in this sprint fixed that and no other sprint
>    owned it. It is now **Task 2**.
> 5. **Task 0 is blocked by #37** — it needs a human `bootstrap/` apply, and #37 blocks every
>    one of those. That dependency was written nowhere. It is now **Task 1**.
>
> **Where the banner and a task body disagree, the banner wins.**

**Sprint Goal:** Complete a full `destroy` → `apply` → verify cycle. Once. Successfully.
**From this sprint onward, every later sprint validates against a real system instead of a
plan of a fiction.**

**Closes:** **F51**, F39, F5, F46, **F55**. *(F31 closes early here — see Task 3.)*

**Dependencies:** **✅ ST is COMPLETE** (2026-08-07) — the transfer is done and CI authenticates
from `glunk-works/…` in real runs, confirmed on run `31110724740` step 5.

> **⚠️ Two dependencies this line used to carry are GONE, and both would stall the sprint if
> read literally** *(corrected 2026-08-07 by ST-T5)*:
>
> - ~~"and the corrected upstream policy is applied"~~ — **there is no corrected upstream
>   policy and there will not be one until S2-T0.** `ST-T2′` closed **F45** by *deleting* the
>   `bedrock-serverless-rag` entry, not by correcting it.
> - ~~"**ST-T2c** must have passed"~~ — **ST-T2c *is* this sprint's identity task.** It moved
>   here in the same reshape.

S1 has **not** run, and that is deliberate.

---

## Measured live state — 2026-08-07

**Measured, not inferred.** Every earlier statement about what exists in AWS traced back to run
`26788807269`, dated **2026-06-01**, and was carried through the 2026-08-05 evaluation without
re-measurement. Region `us-east-1`, confirmed against both the committed default in
`environments/ai-lab/variables.tf` and the local `.env`. **Resource names only — no ARNs, no
account id, no bucket name, no collection endpoint (BR-D4).**

| resource | exists in AWS? | present in state? |
| --- | --- | --- |
| S3 source bucket | **no** | no |
| AOSS collection `bedrock-rag-store` | **no** | no |
| AOSS encryption policy | **no** | no |
| AOSS network policy | **no** | no |
| AOSS data access policy `personal-rag-data-access` | **no** | no |
| Bedrock KB `serverless-rag-kb` | **no** | no |
| Bedrock S3 data source | **no** | no |
| **IAM role `personal-bedrock-kb-execution-role`** | **YES** — path `/`, **zero inline and zero attached policies** | **no** |
| Budget `bedrock-serverless-rag-ai-lab-monthly` | **no** | no |
| GitHub OIDC provider *(org-shared)* | yes, exactly 1 — **untouched, and out of teardown scope** | *(`bootstrap/`'s state, not this one)* |

`tofu -chdir=environments/ai-lab state list` exits 0 and returns **nothing**: the state CI reads
holds **zero resources**.

### What actually happened, and why it matters

**The state was populated and then destroyed from the S3 backend at `2026-06-02T00:22:37Z`.**
The state object's version history shows apply/destroy churn throughout 2026-06-01 — sizes
oscillating between ~150 bytes (an empty state) and ~13 KB — with the **latest version at 153
bytes** and no write since. CloudTrail places `DeleteCollection`, `DeleteBucket` and
`DeleteSecurityPolicy` at `00:22:05`–`00:22:36Z`, the same minute as the final state writes,
under a **human SSO session**. That is the destroy, and it completed.

**The surviving role was never in that state.** That is exactly why run `26788807269` collided
with `EntityAlreadyExists` at `2026-06-01T23:39Z` — 43 minutes *before* the destroy — and why
the destroy left the role standing: `tofu destroy` cannot delete what it does not track. The
role's inline policy was removed by hand on 2026-06-25, leaving the empty shell measured above.

**So F39 is not "the state does not describe the deployed system."** It is **a clean empty
state, plus one out-of-band role shell** — and the difference is the whole sprint's risk
profile. Two further consequences worth stating:

- **The teardown is one `delete-role` call.** Not an inventory-and-purge exercise.
- **A `tofu destroy` from this backend has already succeeded once**, under admin credentials,
  against an earlier revision of the module. Never under the CI role, and never with the
  current module — but "destroy has never worked here" is not a thing anyone should believe.

### ⚠️ Update, later the same day: the table above is stale — CI's own apply ran

**The table above described the state as of the morning of 2026-08-07. It no longer does.**
The push-triggered CI run for PR #43 (commit `ccc76e6`, ~15:04 UTC) reached the apply step —
the first time this pipeline had ever gotten that far — and **partially succeeded**, discovered
during Task 4's later handoff by re-running `tofu state list`, not assumed from any document.

| resource | created by that apply? |
| --- | --- |
| AOSS collection `bedrock-rag-store` | **YES** |
| AOSS encryption policy | **YES** |
| AOSS network policy | **YES** |
| S3 source bucket | **YES** (a `waiting for ... create: empty result` waiter error surfaced, but the resource landed in state — the bucket exists) |
| `terraform_data.init_vector_schema` (the `create_index.py` local-exec) | recorded in state, **provisioner failed** |
| IAM role `personal-bedrock-kb-execution-role` | **no — `EntityAlreadyExists`**, the same orphan-role collision F55 already documented, reconfirmed live |
| AOSS data access policy, Bedrock KB, Bedrock S3 data source, Budget | **no** — each depends on the IAM role or a separate grant that also failed |

**Two things worth recording precisely, not just "it partially failed":**

1. **Task 3's fail-fast fix worked correctly under real, live failure conditions.** The apply
   log shows exactly one attempt, then: *"not authorized to manage the OpenSearch Serverless
   index. This is a permissions problem, not eventual consistency... Exiting without
   retrying."* No exception text, no ARN, no endpoint in the log. This is the first live
   confirmation of F46/F31's fix, not merely a passing local test.
2. **The budget resource failed on `budgets:ModifyBudget` AccessDenied.** Live confirmation of
   the `budgets:*` gap the regenerated verb list already names below — not a new finding, but
   now measured rather than inferred a second time.

**Disposition: destroy, not fix-forward — done.** Per BR-D20, this partial deployment was worth
nothing — it indexed no documents and answered no queries — so the correct move was `tofu
destroy` against these 5 resources (confirmed via a `tofu plan -destroy` first, not assumed),
run by the operator under admin credentials the same session this was found. **Verified after:
`tofu -chdir=environments/ai-lab state list` returns nothing, and the orphan IAM role is
unchanged** (path `/`, zero inline and zero attached policies) — AWS is back to exactly the
baseline the table at the top of this section describes. That table is therefore accurate
again as of 2026-08-07, not stale; the correction above is a historical record of the
in-between state, not the current one.

---

## ⚠️ The blocking gate — what survives, and what does not

> **🔄 REWRITTEN 2026-08-07 against measured state. The original is kept below it, because the
> reasoning is still correct and only its premise died.**
>
> **What the gate used to say:** the teardown deletes a working-but-orphaned system; the rebuild
> then fails `AccessDenied` on grants that have never been exercised; F51 goes from *"never
> demonstrated"* to *"actively broken"*; this is *"the single most expensive mistake available
> in this roadmap."*
>
> **Why that is no longer true:** there is no working system. The workload was destroyed on
> 2026-06-02. The only deletable thing is an **empty IAM role**, and recreating it costs one
> apply. **The irreversibility argument is spent, and this document should not keep asserting
> it** — a gate defended by a danger that no longer exists teaches the next reader to discount
> the gates that are real.
>
> **What survives, and it is still enough to keep the gate:** the deploy identity is still
> **not** provably sufficient, and every gap discovered the slow way — by watching CI fail —
> costs a PR **plus a human `tofu apply` in `bootstrap/`**, against the single unbacked-up,
> unversioned local state file that **F48** and **#37** are about. Six missing verbs is six
> such applies. **Proving sufficiency first is now an argument from cost and from F48's
> exposure, not from irreversibility** — and it points at the same order, which is why the gate
> stays.
>
> **The gate, restated:** the identity's sufficiency is established in **Task 5** before CI is
> ever asked to apply, and `state_access_policy` is widened **once**, from a measured list.

---

## Tasks

> **⚠️ THE ORDER BELOW IS NOT THE ORIGINAL ORDER.** The original ran
> `T0 identity → T1 rebuild → T2 data-plane → T3 retry`. That fails: the run which proves the
> identity is also the run that first exercises the data plane, so the data-plane fix (F5) and
> the fail-fast fix (F46) must both be **in the tree before it**, or the proving run spends
> ~12 minutes on a blind `403` that the later tasks were going to fix. Task 3's own note
> already argued for moving early — *"this lands with, ideally before, Task 2's verification"*.
> The method makes it mandatory rather than preferable.

- **Task 1 (blocking, closes #37): Restore-test the `bootstrap/` state backup**
  - **Description:** Every remaining task that touches identity needs a human `tofu apply` in
    `bootstrap/`, and **#37 blocks every one of them**. ST-T0's backup was taken, but its
    *restorability* is **operator-attested, not proven** — and an unverified backup is the
    ordinary failure mode of backups. Restore the copy to a scratch path, confirm it parses,
    and confirm it lists the **org-shared OIDC provider**. That file is the only record of a
    resource whose loss is an organization-wide outage (**F48**, BR-D18).
  - **Target Files:** none in-tree — this is an operational check. The **location of the backup
    is deliberately not written down** (public repo, BR-D4).
  - **Acceptance Criteria:** The restore-test result is recorded **in the PR body of the task
    that relies on it** (Task 5), not only in an issue comment. Issue **#37** is closed with the
    parse result and the provider's presence stated. **No `bootstrap/` apply happens before
    this passes.**
  - > **Why this is a task and not a remembered precondition.** ST's single genuine process
    > failure was that a blocking criterion's only evidence was someone's memory, which made it
    > indistinguishable from one that had been **skipped** — it took a human at the completion
    > review to resolve. This is the direct application of that finding. Upstream
    > `claude-workbench#7` is open on the same gap and must not be worked around locally.

- **Task 2 (new — unblocks the Definition of Done): Make CI job 1 pass**
  - **Description:** **`MW` cannot currently reach its own acceptance criterion.** The DoD
    requires a CI apply; the apply job is `needs: security-and-linting`, and job 1 fails at
    `ruff check .` with **5 errors** — so `OpenTofu Plan & Apply` reports **`skipped`**, not
    `failure`, and **has never executed**. Confirmed on run `31110724740`, step 10.
    Three parts:
    1. **Pin `ruff` and `bandit` to exact versions.** `pip install ruff bandit` is unpinned, so
       the rule set gating this sprint is whatever the newest release ships. The 5 errors
       include `I001` and `BLE001`, which are not what an older default would have flagged —
       **this gate can go red with no change to this repository**, mid-sprint.
    2. **Declare the rule set explicitly** in a minimal config rather than inheriting a default
       that moves.
    3. **Fix the 5 errors.** One of them — `BLE001 Do not catch blind exception: Exception` at
       `create_index.py:86` — **is Task 3's fix**, so land Task 3 first and this shrinks.
  - **Target Files:** `.github/workflows/deploy-ai-lab.yml`, a minimal `ruff` config,
    `environments/ai-lab/create_index.py`, `environments/ai-lab/test_rag.py`
  - **Acceptance Criteria:** Job 1 green on a real run, and job 2 **reaches its plan step**
    (whatever that step then reports). The linter versions are pinned and the rule set is
    explicit. **S5's Python-toolchain entry is marked `closed early` rather than silently
    dropped** — the same bookkeeping the plan already applies to F31.
  - > **Scope note.** This is S5 work pulled forward, and it is exactly the pattern BR-D23
    > created `MW` to *undo* — building machinery in front of the sprint that makes the thing
    > work. It is included anyway, minimally, because without it the sprint's acceptance
    > criterion is unreachable. **Pull forward the pin and the five fixes; leave `pyproject.toml`,
    > `bandit` configuration and the test suite in S5.**

- **Task 3 (F46, F31): Make the failure diagnosable — *land this before Task 4***
  - **Description:** *(Was Task 3, unchanged in content; its position is now load-bearing.)*
    `create_index.py` retries any `Exception` six times; run `26788807269` shows six consecutive
    `AuthorizationException(403, '')` — a condition that **can never resolve by waiting**,
    because it is F5, not IAM eventual consistency. Commit `0aa56dc` raised the delay to 45 s,
    so CI spends **~12 minutes** failing at it. *(The most recent work on this repo before the
    hardening effort was tuning the wrong variable — worth noting, because the retry loop is
    convincing.)*
    **Retry only what can succeed on a retry.** Catch the authorization failure separately and
    fail fast with a message naming the actual cause; keep the backoff for genuine eventual
    consistency only.
    **Do not also do S4-T4's destructive-delete guard here.** That is the `create_index.py`
    "delete the index if it exists" path, which stays in S3+S4 — it costs nothing today
    (BR-D20: there is no index at all right now) and it is a forward-looking rule under BR-D10.
  - **Target Files:** `environments/ai-lab/create_index.py`
  - **Acceptance Criteria:** An authorization failure exits in **under a minute** with a message
    that names the authorization cause. The retry path still covers genuine eventual
    consistency. **The exception text does not reach the log** — bare `print(e)` renders the
    collection endpoint and caller identity into a public workflow log (**F31**, BR-D4); fix it
    here since the file is open, and mark it closed early in S5's list.
  - > **Why it moved to third.** Every iteration of Task 5's identity loop that touches the data
    > plane costs 12 minutes without this, and — worse — a `403` meaning *"your policy is wrong"*
    > is indistinguishable from one meaning *"wait"*. The sprint whose entire purpose is
    > diagnosis would otherwise be the least diagnosable one.

- **Task 4 (F5): Make the AOSS data-plane principal explicit — *land this before Task 5***
  - **Description:** *(Was S2-T6, then Task 2.)* Run `26788807269` shows `create_index.py`
    failing `AuthorizationException(403, '')` six times — because
    `data.aws_arn.current_identity.arn` resolved to a **human SSO session** when the policy was
    last applied, so the CI role has no data-plane access at all. Not a latent risk: **it is the
    reason the pipeline has never worked.**
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
    > forgotten entry here reproduces **F5** exactly.

    > **🚨 ADDED 2026-08-07 by the plan review — THIS TASK AS ORIGINALLY WRITTEN DOES NOT CLOSE
    > F5.** AOSS data-plane authorization requires **two** independent grants, and this task
    > only ever supplied one. The data access policy names the principal; an **IAM** policy must
    > *also* grant **`aoss:APIAccessAll`** on the collection. The KB role has it
    > (`modules/aws-bedrock-rag/iam.tf`, `OpenSearchServerlessAPIAccessAllStatement`);
    > **`state_access_policy` does not grant it at all.** So with only the change above,
    > `create_index.py` still returns `403` under the CI role — and Task 3 would then correctly
    > fail fast naming an authorization cause that this task believed it had removed.
    > **`aoss:APIAccessAll` is in Task 5's widen list for exactly this reason, and the two tasks
    > are only correct together.**

    Both principals are BR-D4 *restricted*: source them from `.env` locally and a repository
    variable in CI, **never** a committed `.tfvars`.
  - **Target Files:** `modules/aws-bedrock-rag/iam.tf`, `modules/aws-bedrock-rag/variables.tf`,
    `environments/ai-lab/main.tf`, `environments/ai-lab/variables.tf`
  - **Acceptance Criteria:** `grep -rn 'aws_arn.current_identity' modules/ environments/`
    returns nothing. No ARN appears in a committed file or a workflow log. **The successful
    `create_index.py` run that proves this is Task 6's**, not this task's — it cannot happen
    until the identity is sufficient.

- **Task 5 (F55, F39): Establish identity sufficiency, and delete the orphan**
  - **Description:** *(Was Task 0.)* **The separate probe is gone.** With AWS empty, the
    original proof-before-teardown construction — build a parallel-namespace throwaway stack,
    prove the verbs against it, tear it down, then build for real — protects against a
    collision that cannot occur and buys a whole extra build/destroy cycle plus OCU spend for
    it. **The first real build *is* the proof.** Steps:
    1. **Delete the orphan role.** `personal-bedrock-kb-execution-role`, path `/`, no policies
       attached. It is not in state, it is not referenced by anything (no KB exists), and it is
       the sole cause of `EntityAlreadyExists`. Recreating it costs one apply, so this is the
       cheapest reversible act in the sprint — **but confirm both properties immediately before
       deleting**, do not trust this paragraph's measurement.
    2. **Apply the real configuration under admin SSO credentials.** This is the from-scratch
       create the gate wanted evidence of, and it leaves a working system rather than a
       discarded one.
    3. **Harvest the verb list from CloudTrail**, not from F55's text and not from § *The
       regenerated verb list* below. Read the `AssumeRoleWithWebIdentity`-adjacent management
       events for the apply window and derive **exactly** which API calls were made. F55's own
       confidence note rates completeness only *medium*, and the review below proves it was
       right to.
    4. **Widen `state_access_policy` once**, from that measured list — one PR, one human
       `bootstrap/` apply. **Blocked on Task 1.**
    5. **Record the widening as temporary, and write its removal into `S2-T2`'s step 3 in the
       same PR that widens.** Not in a PR body. *A temporary grant whose removal is recorded
       only in a PR body is a permanent grant with a good story.*
  - **Scoping decision (2026-08-07):** condition **`iam:PassRole`** on
    `iam:PassedToService = bedrock.amazonaws.com`, exactly as the original option 2 specified;
    grant the remaining verbs flat on `Resource = "*"`, matching the statement's existing style
    and its own `# This should be locked down outside of lab use`. **The honest rationale, so
    nobody re-litigates it:** F1 already makes this role account-admin-equivalent
    (`iam:CreateRole` + `iam:PutRolePolicy` on `*` is a self-assumable admin role away from
    full control), so resource-scoping the other verbs on a role S2 deletes buys close to no
    real risk reduction. `PassRole` is conditioned because the plan named it and it costs
    nothing to honour.
  - **⚠️ Struck option, reasoning retained:** ~~**Adopt the corrected upstream role first.**~~
    **NOT AVAILABLE.** `ST-T2′` deleted the `bedrock-serverless-rag` entry from
    `var.projects`, and **S2-T0 re-creates it two sprints after this one.** Taking this option
    means waiting on a later sprint, or re-adding the upstream entry here *without* the
    boundary construction — which reopens **F41** to unblock a rebuild. Do neither. It is
    recorded because "adopt the fixed role first" is the natural instinct and it now leads
    somewhere bad.
  - **Target Files:** `bootstrap/state-backend.tf`, `docs/hardening_roadmap.md` (F39, F55)
  - **Acceptance Criteria:** The admin apply completed and its resource list is recorded. The
    widen PR states **which verbs were added, that the list came from CloudTrail rather than
    from a document, and that the grant is temporary with S2-T2 named**. Task 1's restore-test
    result is quoted in this PR body. **The PR states explicitly that the OIDC provider was
    untouched.** The F39 row in the roadmap carries the measured inventory table — resource
    names only, no ARN, no account id.

- **Task 6 (F51, F39): Prove the cycle under the CI role**
  - **⚠️ BR-D19 is REVERSED. Do not write `import` blocks.** This task once said *import, never
    recreate*, to protect embeddings and source documents. **There are none, and now there is no
    infrastructure either** — the workload was destroyed on 2026-06-02 and the corpus was always
    empty (BR-D20). The **only** exemption is anything shared with the organization — the OIDC
    provider above all (BR-D18).
  - **Description:**
    1. **Fix the resource names** *(the task formerly known as S3-T6, folded in by BR-D23)*.
       The rebuild makes it free. In particular, close the `CLAUDE.md` hazard: `opensearch.tf`
       writes `collection/bedrock-rag-store` as a **literal** inside both security policies
       while the collection resource declares the same name separately — the two can silently
       diverge, and the failure surfaces as an unauthorized data plane, not a plan error.
       *(Plan-review note: this was briefly a **prerequisite** when Task 5 used a
       parallel-namespace probe, which needed a name prefix variable. The probe is gone, so
       this is back to being opportunistic — but it is still the cheapest it will ever be.)*
    2. **`destroy` → `apply` under the CI role, in CI**, followed by an end-to-end
       `RetrieveAndGenerate` query. That round trip, not a passing plan, is what closes F51.
  - **Target Files:** `environments/ai-lab/`, `modules/aws-bedrock-rag/`,
    `docs/hardening_roadmap.md`
  - **Acceptance Criteria:** `tofu plan` in `environments/ai-lab` reports **`No changes.`**
    against the live account. **A CI apply on `main` succeeds — the first one ever.** A
    successful `create_index.py` run in CI (this is where Task 4's proof lands). Then the full
    cycle green, closing **F51**. **The PR body states explicitly that the OIDC provider was
    untouched.** No resource name is written as a literal in more than one place.
  - > **Accepted, and worth naming:** the first successful CI apply in this project's history
    > will run through `deploy-ai-lab.yml`'s **ungated `-auto-approve` path** — a live **BR-D2**
    > violation (**F13**), fixed by S1-T5, which by design runs *after* this sprint. That
    > ordering is BR-D23's deliberate choice: an Environment gate around this sprint would add a
    > human approval to every iteration of a debugging loop. It is accepted, not overlooked.

---

## The regenerated verb list

**This list is an input to Task 5 step 3, not a substitute for it.** It is recorded because it
demonstrates *why* the regeneration is mandatory: F55 named four gaps, and a review of the
declared resources against the live policy found **four more**, one of which silently breaks
another task in this sprint.

| gap | needed by | status in F55 |
| --- | --- | --- |
| `aoss:*AccessPolicy` (Create/Get/Update/Delete) | `aws_opensearchserverless_access_policy` | named |
| `iam:PassRole` | the KB's `roleArn` | named |
| `s3:*EncryptionConfiguration` | `aws_s3_bucket_server_side_encryption_configuration` — **`s3:PutBucket*` matches neither verb** | named |
| `s3:GetBucket*` | `aws_s3_bucket` refresh | named |
| **`budgets:*`** | **`aws_budgets_budget`** — the role holds **no `budgets:` verb at all** | **MISSED** |
| **`aoss:APIAccessAll`** | **the data plane — without it Task 4 does not close F5** | **MISSED** |
| **`bedrock:Get*`** | create waiters poll `GetKnowledgeBase`/`GetDataSource`; only Create/Delete are granted | **MISSED** |
| **the entire destroy path** | `force_destroy` on the source bucket lists and deletes object versions, but `s3:ListBucket`/`s3:DeleteObject` are scoped to the **state bucket** only; a policy-body change needs `aoss:UpdateSecurityPolicy` | **MISSED** |

> **The two lessons, and the second is the general one.**
> **(a)** `budget.tf` landed with **S0-T8 on 2026-08-06**, *after* F55 was written on 2026-08-05.
> A resource was added to the configuration and the sufficiency finding was never re-derived —
> so the gap is not that the list was *approximate*, it is that the list was **stale**.
> **(b)** *Every* verb list in this plan and in the roadmap was derived from a from-scratch
> **create** path, while the Definition of Done is `destroy → apply → verify`. **Half the
> acceptance test had no verb analysis at all.** Task 5's CloudTrail harvest must cover the
> destroy, which is why Task 6 runs `destroy` first rather than `apply` first.

**The live policy matches the committed HCL exactly** — verified 2026-08-07 against
`get-role-policy`, actions-only projection. So unlike **F50**, no out-of-band drift is hiding
here and the committed file can be trusted as the starting point.

---

## Definition of Done

`gates.green` passes. **A `destroy` → `apply` → verify cycle has completed end-to-end, in CI,
observed in real run links** — this is the whole sprint and no partial credit substitutes for
it. F51, F39, F5, F46 and F55 are marked closed with the run links that prove each; F31 and
S5's linting entry are marked **closed early**. Issue **#37** is closed with its restore-test
result. Nothing shared with the organization was deleted, **stated explicitly** in the PR body.
`/way-of-working:critic-gate` has run — propose `security-critic` (Task 5 changes an IAM policy,
Task 4 changes a data-plane access policy) and `architect` (this sprint touches the module, the
environment, the workflow and the scripts at once).

---

## Critical review

**Security**

- **The teardown is no longer the sprint's dangerous act, and pretending otherwise is its own
  hazard.** It is one `delete-role` on an empty, unreferenced, out-of-state role. The genuinely
  consequential acts are now **the `bootstrap/` apply in Task 5** — against the unbacked-up
  state file holding the org-shared OIDC provider — and, further out, forgetting to remove the
  widen. Task 1 exists for the first; Task 5 step 5 exists for the second.
- **"Delete the orphan" and "never delete anything shared" still sit close together**, and the
  distinction is still load-bearing (F47). The workload is disposable; the account is not.
  Tasks 5 and 6 both make the operator *state* that the OIDC provider was untouched rather than
  merely not mention it, because a silent omission and a careful check look identical in a PR
  body.
- **The widen is temporary on a role this sprint does not delete.** `state_access_policy` gains
  `iam:PassRole` and lives until S2-T2 — so the removal is written into S2-T2's step 3 **in the
  same PR that widens**. This is now the only path, so the mitigation is the only mitigation.
- **Task 5 runs an apply with admin credentials on purpose.** That is a wider credential than
  CI's, used deliberately to *measure* what CI needs rather than to grant CI more than it needs.
  The output of that step is a list of verbs, not a policy — the policy still gets written and
  reviewed.

**Logic**

- **This sprint can fail in a way that is not a defect.** If the cycle does not complete, the
  correct outcome is a documented reason, not a widened permission. The pressure runs exactly
  the wrong way: the success criterion is *"it works"*, and the fastest route to *"it works"* is
  always to grant more. **Any grant made to close this sprint is recorded in the PR body with
  the finding it re-opens.**
- **Two findings are fixed here opportunistically** — **F31** (Task 3) and S5's linting entry
  (Task 2). Both are scope departures and both are named as such rather than absorbed silently;
  S5's entries are marked closed-early rather than dropped.
- **Nothing in this sprint depends on S1**, and the first successful CI apply therefore runs
  through the ungated `-auto-approve` path. Accepted; see Task 6's note.
- **⚠️ The recurring failure this sprint is most likely to reproduce.** Three times in ST's
  final session, *a corrected fact survived in a summary while the detail beside it was fixed*.
  This revision rewrote the sprint's premise — **`docs/hardening_roadmap.md`'s F39 row, F55 row,
  and § 5 ordering hazard 1 all still assert the old one.** They are corrected in the same
  change as this file, and anyone reading only one of the two will get the wrong sprint.

**Execution**

- **A coder agent can do most of this.** The two acts that want a human are the `bootstrap/`
  apply (BR-D1 — `bootstrap/` is never applied by CI) and the orphan-role deletion, which is
  cheap but should still be eyeballed against a fresh measurement rather than against this
  document.
- **The retry fix lands third, before anything exercises the data plane.** Twelve minutes per
  iteration is what turns a half-day sprint into a two-day one.
- **`AWS_PROFILE` must be set in the shell** for any local verification
  (`$env:AWS_PROFILE = "admin-sso"`) — `bootstrap/providers.tf` sets no profile (F49). Note also
  that Git Bash mangles a leading-slash argument such as `--path-prefix /bedrock-rag/` into a
  Windows path; use PowerShell or quote defensively when querying IAM paths.
