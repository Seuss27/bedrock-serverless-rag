# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`planning` — `ST` (organization transfer, `Seuss27/` → `glunk-works/`). S0 archived.**

## Just done

- **S0 archived.** All eight tasks (T1–T8) landed and independently verified across PRs
  #20–#24. Full evidence trail: `docs/hardening_roadmap.md` § 10 (2026-08-06 entry) and
  the frozen cursor at `.ai/archive/S0-next-steps.md`.

## Next

**Plan/review `ST`** (`sprints/ST_org_transfer/sprint_plan.md`) with fresh eyes before
implementation starts — read its own Critical Review section first. **Model: `opus`
(architect).**

⚠️ **Task 1 is already marked done** in the plan's own header (`prevent_destroy` on the
OIDC provider, PR #17 / `1ad5aa7`) — confirm that against live state rather than trusting
the note, then plan forward from **Task 0**.

⚠️ ST is higher-stakes than S0: it transfers the repo and has **three** human-apply gates
in `bootstrap/` (Task 0 drift reconciliation, Task 2's `global-bootstrap` apply, Task 3's
widen/narrow) — admin SSO only, never CI or an agent (BR-D1). Its own header states the
central risk: not the transfer failing, but succeeding *quietly*, activating a dormant
over-privileged org role (F45) the instant the owner name in the OIDC subject matches.

**HITL Gate: OPEN.** The plan has not been re-confirmed since S0 completed — get explicit
human sign-off that nothing has drifted before flipping `sprint_status` to `implementing`
and starting Task 0.

## Pointers

- `docs/hardening_roadmap.md` — reference of record **and** threat model.
- `sprints/ST_org_transfer/sprint_plan.md` — **the active sprint.**
- `.ai/archive/S0-next-steps.md` — S0's final cursor, frozen for history.
