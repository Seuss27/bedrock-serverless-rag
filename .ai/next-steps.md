# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`planning` — `S1` (pipeline hardening) has not started.** `MW` is complete; nothing is
`implementing` yet. Read `sprints/S1_pipeline_hardening/sprint_plan.md`'s reshape banner
before anything else — it was rewritten 2026-08-05 to run behind `MW` and several of its
premises (F56, the upstream plan role) changed again in `ST`.

## Just done

**`MW` ("make it work") is COMPLETE — 2026-08-08. All six tasks done; the sprint's own
acceptance test (BR-D20's `destroy → apply → verify` cycle) passed for the first time in
this project's history, under the CI role, human-watched throughout.** Full detail archived
at `.ai/archive/MW-next-steps.md` and `docs/hardening_roadmap.md`'s 2026-08-08 changelog
entry; the short version:

- **Destroy mechanism added** (PR #61): a `workflow_dispatch` job on `deploy-ai-lab.yml`,
  gated on an exact typed confirm phrase matched entirely inside the job's `if:` (never a
  `run:` block). Verified with a negative test (wrong phrase → job `skipped`, no credentials
  assumed) before the real one.
- **Real destroy under the CI role, three dispatches, each further than the last**
  (runs `31259407481` → `31260054651` → `31260209345`): stopped on `aoss:DeleteAccessPolicy`
  (fixed, PR #62), then on `iam:ListInstanceProfilesForRole` (fixed, PR #63) — both measured
  from a real destroy failing, not guessed in advance, same method as `MW`-T5's create-path
  harvest. Third dispatch destroyed the last resource clean: AWS held nothing from
  `environments/ai-lab`.
- **Real apply under the CI role** (PR #64 triggered run `31261657155`): rebuilt all 12
  resources from scratch — `Apply complete! Resources: 12 added, 0 changed, 0 destroyed`.
  The AOSS collection alone took 11m14s; a first attempt looked hung on
  `configure-aws-credentials` at the 14-minute mark and was cancelled, which turned out to
  be premature (the credentials step wasn't actually what was slow) — a rerun of the same
  run succeeded. **Lesson: check which step is actually slow before reading elapsed time as
  stuck.**
- **End-to-end `RetrieveAndGenerate` verified**: `test_rag.py` run locally under admin-SSO
  (it's interactive and reads a local `KNOWLEDGE_BASE_ID` — Task 6 never required the query
  itself to run inside a GitHub Actions job, only the destroy/apply either side of it)
  returned cleanly, no `ClientError`. A "no relevant documents" answer is *correct* against
  BR-D20's empty corpus.
- **F51 and F39 closed** in the roadmap. **F55 updated**: the destroy path it flagged as
  unmeasured now is measured (both gaps above).
- One process note worth carrying forward: mid-troubleshooting, a local
  `aws sts get-caller-identity` run put the account id and an SSO role ARN into a session
  transcript — a real BR-D4 near-miss, caught and named rather than repeated, recorded in
  the roadmap's 2026-08-08 entry.

## Next

**Plan `S1`.** No `implementing` work is queued — the next action is a planning pass, not a
coding task. Before planning, two things worth a look (neither blocks planning, both are
honest gaps left over from `MW`):

- **F5's roadmap row (`docs/hardening_roadmap.md:161`) is stale.** It's scoped to `S2`, but
  `MW`'s CI apply just exercised the exact mechanism it's about (`data_plane_principal_arns`
  under the CI role) successfully — `create_index.py` ran clean in CI with no
  `AuthorizationException`. Worth confirming whether F5 should note this or stays as-is
  pending `S2`'s fuller fix; not verified precisely enough this session to edit the row
  directly.
- `sprints/S1`, `S3`, `S4` (and `S2`'s own risk section) may still restate F39's old
  pre-`MW`-T5 "split-brain" premise, now doubly stale since F39 fully closed today — correct
  opportunistically if touching those files.

## Open gates and blockers

**HITL Gate: NONE OPEN.** `MW`'s gate (destroy mechanism sign-off, human-watched destroy)
closed with the sprint. `glunk-works/global-bootstrap#7` (org-wide lock-table question)
still awaits a response — informational, not blocking anything here.

## Pointers

- `docs/hardening_roadmap.md` — reference of record and threat model. 2026-08-08 entry has
  the full `MW`-T6 narrative; F51/F39 closed, F55 updated.
- `sprints/S1_pipeline_hardening/sprint_plan.md` — next sprint. Read its reshape banner
  first; several premises changed again after it was written (F56, the upstream plan role).
- `.ai/archive/MW-next-steps.md` — `MW`'s final cursor before archival, for history queries.
