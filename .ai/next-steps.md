# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`implementing` — `S1b` (the pipeline rewrite).** `T2`, `T1`, `T3`, `T6` done. One task
left: `T7` — and it opens with a decision, not a mechanical execute.

## Just done

**`S1b`-T6 shipped as PR #83** (branch `ci/s1b-t6-purge-raw-output`, commit `a2635e0`), open
and mergeable, not yet merged.

- `T6` asked for a BR-D4 raw-output sweep of `ci.yml`/`deploy.yml`, plus a live test of
  whether `zizmor` actually catches an `actions/github-script` injection (the repo has no
  such step to check directly). **The sweep found nothing to fix** — every check named
  (`set -x`, env dumps, `aws sts get-caller-identity`, bare `tofu output`, `tofu show` of
  state, `set -euo pipefail` on all 9 multi-line `run:` blocks, no `${{ }}` outside safe
  positions across all four workflow files) was already compliant. This PR is **docs-only** —
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
- Live CI on PR #83 confirmed the docs-only nature: `checkov`/`zizmor` fail on exactly the
  same already-known findings as PR #80 — nothing new.

## Next

**Merge PR #83.** Then **`S1b`-T7 — the sprint's last task**, appending this sprint's checks
to `ruleset.required_checks`, `.ai/project.yml`, and `ruleset-drift.yml`'s check list (all
three in one PR, BR-D9).

⚠️ **This is not a mechanical append.** `T7`'s task body now carries a blocking note (added
by `T3`'s own `/critic-gate` pass): `secrets-scan` and `zizmor` cannot both go straight into
the required five as originally written. Read **F59** (secrets-scan fails on any fork PR —
not fixable from this repo) and **F60** (zizmor is red today on `deploy.yml:27`'s
excessive-permissions plus a `dependabot-cooldown` warning) and `sprint_plan.md`'s Task 7
body before running `gh api -X PUT` — each needs resolving or knowingly accepting first.

**Model: `sonnet` / coder.**

## Open gates and blockers

**HITL Gate: OPEN — PR #83 awaiting human merge.** Do not auto-start `T7` before it lands.

**Separately, once `T7` is reached:** it needs a human decision on F59/F60 (hold the checks
out of the required list, fix the underlying cause, or accept the cost) before the
ruleset-append step — not an unattended-executable task even after PR #83 merges.

`glunk-works/global-bootstrap#7` (org-wide lock-table question) still awaits a response —
informational, not blocking.

## Pointers

- `docs/hardening_roadmap.md` — reference of record and threat model.
- `sprints/S1_pipeline_hardening/sprint_plan.md` — **top banner first.** Task 6's body now
  carries the full sweep + injection-test evidence trail; Task 7's body carries the blocking
  F59/F60 note.
