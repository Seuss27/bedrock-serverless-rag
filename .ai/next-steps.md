# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`implementing` — `S1b` (the pipeline rewrite).** All five tasks (`T2`, `T1`, `T3`, `T6`,
`T7`) are merged. **The sprint is NOT done anyway** — its Definition of Done has a standing
sixth requirement that hasn't been satisfied. Read `Next` below before assuming `/archive-sprint`
applies.

## Just done

**`S1b`-T7 merged as PR #86** (`cfed547`); its cursor sync merged as PR #87 (`bae7a13`).
Direction given: fix `F59`/`F60` at the cause rather than hold them out of the required list
or accept the cost.

- **F59 closed.** `secrets-scan` no longer uses `gitleaks/gitleaks-action` — its own wrapper
  code enforces a `GITLEAKS_LICENSE` secret for any org-owned repo, and GitHub withholds
  every secret from a fork PR. It now runs the raw, MIT-licensed `gitleaks` CLI directly via
  a pinned `ghcr.io/gitleaks/gitleaks` digest — no secret consumed at all. Verified locally
  against this repo's real history (133 commits, no leaks) **and** in real CI.
- **F60 closed.** `deploy.yml`'s workflow-level `id-token: write` moved to job-scoped grants
  on its three credentialed jobs; `dependabot.yml` gained a 7-day `cooldown`. Verified
  locally with the pinned `zizmor` image (zero findings) **and** in real CI.
- `/critic-gate` ran both `security-critic` and `architect`. Both independently caught that
  4 of the 5 newly-required checks resolve their tool version at `latest` by default —
  `zizmor`'s was pinned in this same change (`1.29.0`); the other two
  (`opentofu/setup-opentofu`'s `tofu_version`, `terraform-linters/setup-tflint`'s
  `tflint_version`) are recorded as new finding **F61** — a version pin interacts with this
  repo's `required_version` constraints and the deferred `SD` sprint's devcontainer-parity
  plan, a separate decision.
- The live branch-protection ruleset was updated (`gh api -X PUT`, read-modify-write) with
  all six checks (`pr-title`, `tofu-fmt`, `tofu-validate`, `tflint`, `secrets-scan`,
  `zizmor`), verified via the rules endpoint and a green `ruleset-drift.yml` dispatch —
  **before** `#86` merged, so its own required-checks state was observed matching the new
  ruleset first (`S1b`'s DoD requirement).
- **PR #87 briefly showed `zizmor` red on its own head SHA** — expected, not a regression:
  it was cut from `main` before `#86` merged, so it was testing `main`'s still-unfixed
  `deploy.yml`/`dependabot.yml`. Self-resolved once the branch picked up `main`'s post-`#86`
  content and re-ran green; merged normally through the required checks, no bypass used.

## Next

**`S1b`-T7 is merged, but the sprint is not done.** Re-reading `sprint_plan.md`'s Definition
of Done (as this cursor's own prior note said to do before declaring completion) surfaced a
**standing requirement no task run since `T2` has satisfied**: a full
`destroy → apply → verify` cycle, **human-watched**, run against the FINAL shape (split
`ci.yml`/`deploy.yml`, all five required checks live, `F59`/`F60`'s fixes). `T2` deleted the
workflow file `MW`'s original proof was measured against, so nothing since has demonstrated
the shipped pipeline can actually stand the system up.

**Present this to the human — do not dispatch or approve any of it unattended:**
1. Dispatch `destroy-ai-lab` on `main` with the exact confirm phrase `destroy-ai-lab`, let
   it complete.
2. Merge a trivial change to `main` to trigger `tofu-plan-main` → `tofu-apply`.
3. Approve the `production` Environment's approval request.
4. Confirm the apply succeeds. Expect the AOSS collection alone to take ~11 minutes — check
   **which step** is actually slow before reading elapsed time as stuck (the `MW` lesson).

Only once this cycle is confirmed (or the human explicitly decides to waive/defer it — their
call) does `/archive-sprint` apply.

**Model: `sonnet` / coder.**

## Open gates and blockers

**HITL Gate: OPEN — the destroy/apply/verify cycle above is human-watched by the sprint
plan's own words and BR-D25.** Do not dispatch `destroy-ai-lab` or approve a `tofu-apply`
unattended.

`glunk-works/global-bootstrap#7` (org-wide lock-table question) still awaits a response —
informational, not blocking.

**F61** (floating tool versions on `tofu-fmt`/`tofu-validate`/`tflint`) has no sprint owner
yet — flag it for whoever plans the next sprint.

## Pointers

- `docs/hardening_roadmap.md` — reference of record and threat model. `F59`/`F60` now
  `✅ CLOSED`; new `F61` recorded. `S1b`'s status row still says `implementing` — correct,
  don't mark it `complete` until the DoD's final cycle is run or explicitly waived.
- `sprints/S1_pipeline_hardening/sprint_plan.md` — Definition of Done section (the paragraph
  starting `**`S1b` (~~T2, T1, T4, T3, T6, T7~~**`) is the authoritative text for what remains.
