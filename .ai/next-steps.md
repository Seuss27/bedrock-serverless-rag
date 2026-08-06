# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`done` — `S0` (governance and repository baseline). All eight tasks complete and
independently verified. Not yet archived.**

## Just done

- **All of S0 (T1–T8) landed and verified**, across three merged PRs: **#20** (file work —
  `pr-title.yml`, `ruleset-drift.yml`, the five F37 baseline files, issue-template taxonomy,
  Infisical deletion, `budget.tf`), **#21** (Dependabot's own PR — live proof the
  `commit-message.prefix: chore` fix works), **#22** (`.ai/project.yml`'s `ruleset` block
  synced to live values).
- **`protected-integration-branches` is live on `main`** (current id `20506099` — it
  changed once already, during T6's own test; never trust a previously-recorded id).
  Verified two ways: a real `git push` to `main` was rejected (`GH013`), and T6's
  `ruleset-drift.yml` was observed to go **red** when the ruleset was deliberately deleted
  (run `31096079937`) and **green** after it was restored from the Task 1 payload (run
  `31096554632`) — T6's own stated acceptance bar ("never observed to go red has not been
  tested").
- **A `security-critic` pass ran on PR #20's diff before commit** (human confirmed which
  critic to run). 8 findings; fixed inline except one deliberately-accepted, documented gap
  (`ruleset-drift.yml` cannot see a non-empty `bypass_actors` without minting a new
  admin-scoped credential — not done without a separate decision).
- Private vulnerability reporting was off while `SECURITY.md` told reporters to use it —
  enabled live.

## Next

**Run `/archive-sprint`** to retire S0 and advance the cursor to `ST`. Then **begin `ST`**
(`sprints/ST_org_transfer/sprint_plan.md`) at **Task 0** — **Task 1 is already done**
(`prevent_destroy` on the OIDC provider, PR #17 / `1ad5aa7`, verified live 2026-08-05) —
**do not re-implement it.** Model: `sonnet` (coder), same as S0 — the plan is written and
carries its own Critical Review section.

⚠️ ST is higher-stakes than S0: it transfers the repo to `glunk-works` and has **three**
human-apply gates in `bootstrap/` (Task 0 drift reconciliation, Task 2's `global-bootstrap`
apply, Task 3's widen/narrow) — admin SSO only, never CI or an agent (BR-D1). Its own header
states the central risk: not the transfer failing, but succeeding *quietly*, activating a
dormant over-privileged role (F45) the instant the owner name in the OIDC subject matches.

**HITL Gate: NONE OPEN for S0.** ST's three human-apply gates are the next ones, each hit
in its own task.

## Separately open (not sprint-blocking)

`BUDGET_NOTIFICATION_EMAIL` repo secret is unset — `deploy-ai-lab.yml`'s plan step fails on
any PR touching `environments/ai-lab/**` until a human runs
`gh secret set BUDGET_NOTIFICATION_EMAIL` with a real address. No required check covers
that job, so this doesn't block merges, but the budget can't actually apply until it's set.

## Pointers

- `docs/hardening_roadmap.md` — reference of record **and** threat model.
- `sprints/ST_org_transfer/sprint_plan.md` — **the next sprint.** Start at Task 0.
- `sprints/S0_governance_baseline/sprint_plan.md` — closed; archive will snapshot this file.
- `.ai/project.yml` — `ruleset` block now reflects live state (was `null` all of S0).
