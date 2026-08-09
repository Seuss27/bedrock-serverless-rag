# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`implementing` — `S1b` (the pipeline rewrite).** `T2`, `T1`, `T3`, `T6` done. `T7` is the
**last task in the sprint** — and it opens with a decision, not a mechanical execute.

## Just done

**`S1b`-T6 merged as PR #83** (`9c1ac27`); its cursor sync merged as PR #84 (`2b4dd97`).

- `T6` asked for a BR-D4 raw-output sweep of `ci.yml`/`deploy.yml`, plus a live test of
  whether `zizmor` actually catches an `actions/github-script` injection (the repo has no
  such step to check directly). **The sweep found nothing to fix** — every check named
  (`set -x`, env dumps, `aws sts get-caller-identity`, bare `tofu output`, `tofu show` of
  state, `set -euo pipefail` on all 9 multi-line `run:` blocks, no `${{ }}` outside safe
  positions across all four workflow files) was already compliant. The PR was **docs-only** —
  no `.github/workflows/` file changed.
- **The zizmor question was tested, not assumed.** The exact pinned `zizmor` image this
  repo's CI uses was pulled and run locally via Docker (no need to plant a real injection
  example on this public repo's PR list just to test it) against a scratch workflow with
  `${{ github.event.pull_request.title }}` inlined into `actions/github-script`'s `script:`.
  Result: `error[template-injection]`, confidence **High** — matching `zizmor`'s own source,
  whose sink list is derived in part from CodeQL's models and explicitly names
  `actions/github-script`.
- `docs-consistency` ran on the record before it shipped and **independently reproduced the
  Docker test itself**, not just read the claim. It caught a wrong block count (said 8,
  actual 9) and a framing that overstated `zizmor` as currently *enforcing* the finding —
  `F60` leaves that job unconditionally red regardless, so it's a tested **detector** today,
  not yet a gate. Both fixed. Also fixed: the roadmap's `S1b` status row, stale at `planned`
  since `T2` merged three tasks ago.

## Next

**`S1b`-T7 — the sprint's last task.** Appends this sprint's checks to
`ruleset.required_checks`, `.ai/project.yml`, and `ruleset-drift.yml`'s check list (all
three in one PR, BR-D9).

⚠️ **This is not a mechanical append.** `T7`'s task body carries a blocking note (added by
`T3`'s own `/critic-gate` pass): `secrets-scan` and `zizmor` cannot both go straight into
the required five as originally written. **Present the options to the human and wait for a
choice** before touching the ruleset:
- **F59** — `secrets-scan` can never pass a fork PR (`GITLEAKS_LICENSE` withheld from forks
  by GitHub itself, not fixable from this repo). Hold it out of `required_checks`, or accept
  the fork-PR cost explicitly.
- **F60** — `zizmor` is red today on `deploy.yml:27`'s excessive-permissions finding plus a
  `dependabot-cooldown` warning. Scope `zizmor`'s `inputs:` away from `deploy.yml`,
  job-scope `deploy.yml`'s permission (likely `S2`'s work) and fix the cooldown, set a
  `min-severity`, or accept-and-suppress with a justified `zizmor.yml` citing F60.

Once resolved: append the agreed list, then `gh api -X PUT` the live ruleset — read it first,
a partial-body `PUT` drops the rules it omits.

**Model: `sonnet` / coder.**

## Open gates and blockers

**HITL Gate: OPEN — `S1b`-T7 needs a human decision on F59/F60 before any ruleset edit.**
Do not auto-start the `gh api -X PUT` step; present the options above and wait.

**Once `T7` lands, `S1b` is COMPLETE** — the next session should consider `/archive-sprint`.

Both PR #83 and #84's merges each queued `deploy.yml`'s push-triggered `tofu-plan-main` →
`tofu-apply` again (by-design, every merge does this) — unrelated to `S1b`, a human decision,
not yet acted on as of this cursor.

`glunk-works/global-bootstrap#7` (org-wide lock-table question) still awaits a response —
informational, not blocking.

## Pointers

- `docs/hardening_roadmap.md` — reference of record and threat model.
- `sprints/S1_pipeline_hardening/sprint_plan.md` — **top banner first.** Task 7's body
  carries the blocking F59/F60 note with the resolution options.
