# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`implementing` — `MW` ("make it work"): the first successful `destroy → apply → verify` cycle.**

Task 6's **plan-verification blocker is resolved** — CI reaches `No changes.` — and its
resource-name-hazard step is fixed (PR #59, open). What's left is the sprint's actual
Definition of Done: a real `destroy → apply` under the CI role, in CI, followed by an
end-to-end `RetrieveAndGenerate` query. That step needs a human decision on mechanism (see
below) and live supervision — it does not have an unattended next action.

## Just done

- **`s3:ListBucket` fix merged and applied** (PR #58) — closed the `HeadBucket` 403
  misdetection that made CI plan to recreate the source bucket. Confirmed live.
- **`aws_budgets_budget` notification drift root-caused and fixed** — a stale
  `BUDGET_NOTIFICATION_EMAIL` GitHub secret didn't match the live AWS resource's subscriber
  address (not a permissions or config-parity issue — every input-variable theory was ruled
  out first: email, `budget_limit_usd`, provider version, PR #56 branch content). Diagnosed
  via a temporary, BR-D4-safe attribute-names-only debug step added to `deploy-ai-lab.yml`
  on PR #56's branch, then removed once root-caused. Fixed via a local admin-SSO
  `tofu apply` (reconciling live AWS to the intended address) + a matching secret reset.
  **CI now reaches exactly `No changes.`**, confirmed on two consecutive runs.
- **PR #56 closed without merging** — it had drifted stale behind `main` (missing #57, #58);
  merging would have regressed `next-steps.md` and reverted the `s3:ListBucket` fix. It had
  already served its purpose as the re-verification branch.
- **Resource-name hazard closed, plus one found by review** (PR #59, open, not yet merged):
  - `opensearch.tf`'s AOSS collection name (`"bedrock-rag-store"`, three literals) now reads
    one `local.collection_name`.
  - `architect` pre-review (this repo has no review CI gate, so this is the diff's only
    critic look) found the same hazard one level down: `bedrock.tf`'s `vector_index_name`
    and `create_index.py`'s `index_name` were two independent `"personal-rag-index"`
    literals — now both derive from `local.vector_index_name`, threaded to the
    out-of-process script via a `VECTOR_INDEX_NAME` env var.
  - Also fixed by that review: `terraform_data.init_vector_schema` was missing a
    `depends_on` on `aws_opensearchserverless_access_policy.data_access_policy` — a real
    race that could 403-fail `create_index.py` on the very from-scratch apply Task 6 is
    about to run. `CLAUDE.md`'s hazard bullet updated to stop describing a now-fixed
    instance as current.
  - **Deliberately not done:** the full `var.collection_name`-style rename with an AOSS
    `validation` block (former S3-T6's original scope). That task's own rationale points at
    a naming convention in `docs/hardening_roadmap.md` § 7 that **does not exist there** —
    doing it would mean inventing a convention on the spot. `F11` stays open for that piece;
    MW-T6's actual, narrower acceptance bar ("no resource name literal in more than one
    place") is met once #59 merges.

## Next

**Merge PR #59**, then start Task 6's real Definition of Done:

1. **Decide the destroy mechanism.** `deploy-ai-lab.yml` has no destroy job or
   `workflow_dispatch` trigger today — "destroy → apply under the CI role, in CI" has no
   existing path to run through. This needs a human decision on how to add one (a
   human-triggered `workflow_dispatch` job is the obvious shape, kept out of the
   `pull_request`/`push` triggers per this repo's GitHub Actions security rules) before
   anything else in this list can happen.
2. **Execute destroy → apply → `RetrieveAndGenerate` query, human-watched.** First-ever real
   destroy under the CI role — per this sprint's Critical review, a human watches it live
   rather than letting it fire unattended. A passing plan does not close F51; the round trip
   does.
3. **Harvest Task 6's own verb list from CloudTrail** during the destroy. Task 5's harvest
   covered the create path only; `state_access_policy`'s `s3:DeleteObject`/`s3:ListBucket`
   are still scoped to the state bucket only, and `force_destroy = true` on the source
   bucket means the destroy path is genuinely unmeasured. Widen from the measured list, not
   from guesswork — one PR, one human `bootstrap/` apply, recorded as temporary with S2-T2
   named as its removal (per Task 5's own precedent).

## Open gates and blockers

**HITL Gate: OPEN.**
- Step 1 above needs a human decision (no existing destroy mechanism to route through).
- Step 2 is the first-ever real destroy under the CI role — human-watched, not
  coder-executable unattended.
- `glunk-works/global-bootstrap#7` (org-wide lock-table question) still awaits a response —
  informational, not blocking.

**Known follow-up, not blocking:** `sprints/S1`, `S3`, `S4` (and `S2`'s own risk section)
still restate F39's old pre-`MW`-T5 "split-brain" premise in their own text — correct
opportunistically if touching those files.

## Pointers

- `sprints/MW_make_it_work/sprint_plan.md` — the active sprint. Read the banner, then Task 6's
  full step list and Definition of Done before continuing it.
- `docs/hardening_roadmap.md` — reference of record and threat model. F55 closed; F39 half
  closed; F11 half closed (collection/index name hazard fixed, full naming-convention rename
  deferred); F5/F46 confirmed under a human principal only, not yet under CI.
- An org-owned repo presents `repo:<owner>@<org_id>/<repo>@<repo_id>:<context>`; a plain
  `repo:<owner>/<repo>:*` glob does not match it — see `bootstrap/oidc-setup.tf`'s comment
  block. Binds S2-T0/S2-T2, not Task 6.
