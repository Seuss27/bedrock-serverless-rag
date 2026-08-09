# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`implementing` — `S1b` (the pipeline rewrite).** All five tasks (`T2`, `T1`, `T3`, `T6`,
`T7`) are merged. `PR #91` (the retry-logic fix) has also merged. The sprint's Definition of
Done has **destroy and apply both proven, twice each, under the final shape** — only
**`verify` is still outstanding.**

## Just done

`S1b`-T7 merged (F59/F60 closed at the cause; new finding `F61` on floating tool versions,
unassigned). Then, working through the DoD's outstanding cycle:

- **Apply succeeded** (after one rejected attempt and one that failed on the vector index —
  diagnosed live as AOSS access-policy propagation lag, not a misconfiguration; a third
  no-op-touch retry succeeded, all 12 resources including the vector index).
- **Root cause fixed**: `create_index.py`'s `AuthorizationException` handling got a short,
  separately-bounded retry (2 attempts, 15s apart) so this self-heals in the common case,
  without reopening `F46`'s original "hides a real error for minutes" problem.
  `security-critic` proved the exit-code guarantee correct by exhaustive simulation over all
  3⁶ failure sequences; three low-severity wording findings, all fixed in the same change.
  Shipped as **PR #91** (rebuilt after the branch's original PR, #90, merged one commit
  early — a real trap: pushing to an already-merged PR's branch fires no further CI).
  **Update, same day:** merging PR #92 (a docs-only cursor sync) itself re-triggered a
  rebuild `tofu-apply` — every push to `main` does, regardless of path — and this time the
  2×15s budget wasn't enough; a third occurrence, diagnosed live and confirmed genuine
  propagation lag again (not misconfiguration). Rather than tune the same fixed short
  budget again, replaced it: `AuthorizationException` now retries with an increasing delay
  (5s doubling to a 60s cap) against a **5:15 total elapsed budget**, sized to AWS's own
  documented worst case (`serverless-data-access.html`: "about a minute" typical, "contact
  Support" past 5 minutes) plus a small margin. This explicitly replaces `MW`-T3's
  under-a-minute criterion for this one exception type — see `F46`'s roadmap row for the
  decision record. Not yet re-run against a live apply.
- **The full cycle then ran, twice over, human-driven:** `destroy-ai-lab` dispatch
  (20:08–20:09 UTC, succeeded) → `PR #91`'s merge auto-triggered a rebuild `tofu-apply`
  (20:19, since deploy.yml runs on every push and the lab was just empty — succeeded, all 12
  resources again) → `destroy-ai-lab` dispatched again (20:30–20:31, succeeded). **Both
  `destroy` and `apply` are now proven, twice each, under `T7`'s final job-scoped
  permissions shape.** Confirmed: **no `RetrieveAndGenerate` verify call was made** in the
  ~10-minute window the lab was live between the two destroys — that's the one DoD component
  still open.
- **BR-D4 near-miss, disclosed rather than glossed over:** a bare
  `aws sts get-caller-identity` while diagnosing printed the account id and an SSO role ARN
  into the session transcript — the identical incident this repo hit during `MW`-T6. Caught
  and named; not repeated in the follow-up AWS CLI calls, all scoped to
  `--query`/`--output text` returning only booleans or counts.

## Next

**Close `S1b`'s DoD: run the `verify` step.** **Correction — the lab is NOT currently torn
down.** Merging PR #92 (docs-only) itself re-triggered a rebuild `tofu-apply` (every push to
`main` does, regardless of path); that apply ran for real (not a declined approval — run
`31334750838`, confirmed via the Actions API) and got through 11 of 12 resources before
failing on the vector index with the third `AuthorizationException` occurrence. **No
`destroy-ai-lab` has run since** — the collection is `ACTIVE` right now (confirmed directly
against AWS, read-only, admin-SSO), billing its OCU floor. Present to the human, don't run
unattended:
1. Push the sliding-window retry fix (this session's `create_index.py`/`automation.tf`
   change) to `main`. OpenTofu will see 11 of 12 resources already matching and only retry
   the tainted `init_vector_schema` resource — not a full 12-resource rebuild.
2. Once the index exists, run a `RetrieveAndGenerate` call (`test_rag.py`, locally under
   admin-SSO — it's interactive) to satisfy the DoD's `verify` component.
3. Then dispatch `destroy-ai-lab` to return to the accepted torn-down steady state
   (`BR-D20`) — `S1b`'s DoD asks for the cycle in `destroy → apply → verify` order; this
   closes it with the lab left down afterward, same end state as originally planned, just a
   different starting point than this file previously claimed.

**Alternative, if a fourth full cycle feels like overkill:** the human may reasonably judge
that two successful destroy/apply pairs under the final shape is sufficient evidence and
choose to explicitly waive the literal `verify` step — that's a call for them to make, not
one to assume.

Only after `verify` lands (or is explicitly waived) does `S1b` truly close, and
`/archive-sprint` applies.

**Model: `sonnet` / coder.**

## Open gates and blockers

**HITL Gate: OPEN — the verify step above is human-watched** (sprint plan + BR-D2/BR-D25),
same as any apply/destroy.

**PR #88 (`docs/sync-cursor-s1b-t7-merged`) is OPEN but STALE — do not merge it as-is.** It
predates this entire DoD-rebuild sequence. Close it unmerged.

`glunk-works/global-bootstrap#7` (org-wide lock-table question) still awaits a response —
informational, not blocking.

**F61** (floating tool versions on `tofu-fmt`/`tofu-validate`/`tflint`) has no sprint owner
yet — flag it for whoever plans the next sprint.

**Process lesson, not yet written into a doc — consider a `/retro`:** merging a PR while
more commits are still being actively pushed to its branch is a real trap in this repo's
flow. Squash-merge takes whatever was on the branch at merge time; anything pushed after
fires no further CI, since the PR is already closed. Hit once this session (PR #90).

## Pointers

- `docs/hardening_roadmap.md` — reference of record and threat model. `F59`/`F60` closed,
  `F61` recorded, `F46`'s row updated with this session's refinement. `S1b`'s status row
  still says `implementing` — correct, don't mark it `complete` until `verify` lands or is
  explicitly waived.
- `sprints/S1_pipeline_hardening/sprint_plan.md` — Definition of Done section (the paragraph
  starting `**`S1b` (~~T2, T1, T4, T3, T6, T7~~**`) is the authoritative text for what remains.
