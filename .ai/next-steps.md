# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`planning` — `S2` (Identity, state reconciliation, and `bootstrap/` retirement).**
Nothing planned yet this session — read `sprints/S2_identity_least_privilege/sprint_plan.md`
and the roadmap's S2 row before proposing a task order.

## Just done

`S1b` archived 2026-08-09 — all five tasks (`T2`, `T1`, `T3`, `T6`, `T7`) merged, and the
Definition of Done's `destroy → apply → verify` cycle closed clean: a same-day fix (PR #93,
`F46`) replaced a too-short `AuthorizationException` retry with an AWS-timed sliding-window
retry after the DoD's own rebuild attempt failed on the propagation-lag bug it fixes; the
following cycle then ran end-to-end with no manual retry — destroy, rebuild (all 12
resources), a real `RetrieveAndGenerate` verify call with no `ClientError`, destroy again,
confirmed clean against live AWS. Full detail in `.ai/archive/S1b-next-steps.md` and
`.ai/state.json`'s `session_summary`.

## Next

**Plan `S2`.** Read, in order:
1. `docs/hardening_roadmap.md` § 9 (`glunk-works/global-bootstrap`) and the `BR-D17`/`BR-D18`
   decisions — `bootstrap/` is being **retired**, not hardened; this sprint is where
   ownership of identity and state moves upstream. Do not design a role, a trust policy, or
   a state backend change locally.
2. `docs/hardening_roadmap.md`'s S2 status row for the findings it owns: F1–F4, F40, F43,
   F47 (local half), F48, F56, F58, the `permissions_boundary` half of F57, `BR-D22`. Note
   **F42 is explicitly NOT closed here** — ST removed the offending policy instead of
   correcting it, so F42 survives org-wide.
3. `sprints/S2_identity_least_privilege/sprint_plan.md` in full, including its own Critical
   review section, before proposing a task order to the human.

**Model: `opus` / architect** (planning role per `.ai/project.yml`).

## Open gates and blockers

**HITL Gate: NONE OPEN.** Planning has not started.

**F61** (floating tool versions on `tofu-fmt`/`tofu-validate`/`tflint`) has no sprint owner
yet — consider assigning it while planning S2, or explicitly deferring it further.

`glunk-works/global-bootstrap#7` (org-wide lock-table question) still awaits a response —
informational, not blocking.

**Minor, unfiled:** `test_rag.py` crashes on a default Windows console (`cp1252`) printing
its response emoji unless `PYTHONIOENCODING=utf-8` is set first. Cosmetic; file as an issue
if it recurs.

## Pointers

- `docs/hardening_roadmap.md` — reference of record and threat model. `S1b`'s status row is
  now `✅ complete`. `F46`'s row records the final sliding-window retry design and why it
  supersedes `MW`-T3's original acceptance criterion.
- `sprints/S2_identity_least_privilege/sprint_plan.md` — the sprint plan for the current
  planning phase. Not yet reviewed this session.
- `sprints/S1_pipeline_hardening/sprint_plan.md` — closed; its Definition of Done section now
  carries a dated `✅ DONE` note recording how the final cycle actually closed.
