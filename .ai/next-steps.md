# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`implementing` — `MW` ("make it work"): the first successful `destroy → apply → verify` cycle.**

`MW`'s plan was **reviewed against live AWS and approved** on 2026-08-07 (PR **#41**). The
review changed the sprint's shape, so **read the banner under the plan's title before any
task body** — where the two disagree, the banner wins. **The task numbers moved:** what the
roadmap and older docs call `MW-T0/T1/T2/T3` are now Tasks **5/6/4/3**.

## Just done

- **`MW` plan review complete**, shipped as PR **#41** at **`61f70b5`** *(unmerged)*.
- **The blocking gate's premise is spent, and the plan now says so.** AWS holds **one
  policy-less IAM role**; everything else is absent and the state is **empty**. The workload
  was destroyed at **`2026-06-02T00:22:37Z`** — proven from the state object's S3 version
  history (153-byte latest version) and CloudTrail in the same minute, under a human SSO
  session. The role survived because **it was never in state**, which is also why run
  `26788807269` hit `EntityAlreadyExists` 43 minutes earlier.
- **F55's verb list was stale, not "indicative"** — four more gaps found, one of which
  (`aoss:APIAccessAll`) means the data-plane task **did not close F5** as written.
- **`MW` could not reach its own Definition of Done** — CI job 1 dies at `ruff check`, so the
  apply job reports `skipped` and **has never executed** (run `31110724740`). Now Task 2.
- **`docs/hardening_roadmap.md` corrected in the same PR** — F39 (→ Low), F55 (stays High,
  new rationale), § 5 ordering hazard 1. Originals kept and marked superseded.

## Next

**Implement `MW` Task 3, then Task 2. Model: `sonnet` (coder).**

- **Task 3 first, deliberately** — its fix removes `BLE001` from Task 2's error list, and
  nothing touching the data plane may run before it. Fail fast on the authorization failure
  (**F46**: a `403` from F5 can never resolve by waiting, yet costs ~12 min), and stop
  `print(e)` rendering the collection endpoint into a public log (**F31**, BR-D4).
  **Do not** add S4-T4's destructive-delete guard — that stays in S3+S4.
- **Task 2 next** — pin `ruff`/`bandit` (unpinned today, which is *why* `I001`/`BLE001`
  appeared), declare the rule set explicitly, fix the rest. Leave `pyproject.toml`, bandit
  config and the test suite in S5.
- **Precondition: merge #41 and the cursor-sync PR first.** Both are open; the revised plan
  this work follows lives on #41.

## Open gates and blockers

**HITL Gate: NONE OPEN** for the next action — Tasks 3 and 2 are pure Python and workflow
edits: no AWS call, no `bootstrap/`, no deletion. **Three gates are still ahead inside `MW`:**

- **Task 1 (#37) is human-only** — the backup's location is deliberately unrecorded (BR-D4).
- **The `bootstrap/` apply in Task 5** — BR-D1; it is now *the* most consequential act in the
  sprint, running against the unbacked-up state file that holds the org-shared OIDC provider.
- **Deleting the orphan role** (Task 5 step 1) — cheap and reversible, but confirm it is still
  policy-less and still out of state **against a fresh measurement**, never against the plan.

## Pointers

- `sprints/MW_make_it_work/sprint_plan.md` — **the active sprint.** Banner first.
- `docs/hardening_roadmap.md` — reference of record **and** threat model.
- **Regenerate the verb list from CloudTrail in Task 5** — not from F55, and not from the
  sprint plan's own table. Every list ever written here came from a *create* path, while the
  acceptance test is `destroy → apply → verify`.
- **The trap that outlives ST:** an org-owned repo presents
  `repo:<owner>@<org_id>/<repo>@<repo_id>:<context>`; a plain glob does **not** match it. The
  comment block in `bootstrap/oidc-setup.tf` is the best writeup of it.
- **A recurring failure worth watching for:** a corrected fact surviving in a **summary** while
  the detail beside it is fixed. This session's roadmap edits exist to avoid exactly that.
