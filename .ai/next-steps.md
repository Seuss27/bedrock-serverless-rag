# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`implementing` — `S1b` (the pipeline rewrite).** `T2`, `T1`, `T3`, `T6` done. `T7` — the
**last task in the sprint** — is shipped, verified READY, and awaiting merge.

## Just done

**`S1b`-T7 shipped as PR #86** (branch `ci/s1b-t7-required-checks`, commit `212ecc3`), open
and `/pr-checks`-verified **READY**, not yet merged. Direction given: fix `F59`/`F60` at the
cause rather than hold them out of the required list or accept the cost.

- **F59 closed.** `secrets-scan` no longer uses `gitleaks/gitleaks-action` — its own wrapper
  code enforces a `GITLEAKS_LICENSE` secret for any org-owned repo, and GitHub withholds
  every secret from a fork PR. It now runs the raw, MIT-licensed `gitleaks` CLI directly via
  a pinned `ghcr.io/gitleaks/gitleaks` digest — no secret consumed at all. Verified locally
  against this repo's real history (133 commits, no leaks) **and** in real CI on this PR.
- **F60 closed.** `deploy.yml`'s workflow-level `id-token: write` moved to job-scoped grants
  on its three credentialed jobs; `dependabot.yml` gained a 7-day `cooldown`. Verified
  locally with the pinned `zizmor` image (zero findings) **and** in real CI.
- `/critic-gate` ran both `security-critic` and `architect`. Both independently caught that
  4 of the 5 newly-required checks resolve their tool version at `latest` by default —
  `zizmor`'s was pinned in this same change (`1.29.0`); the other two
  (`opentofu/setup-opentofu`'s `tofu_version`, `terraform-linters/setup-tflint`'s
  `tflint_version`) are recorded as new finding **F61** rather than fixed here — a version
  pin interacts with this repo's `required_version` constraints and the deferred `SD`
  sprint's devcontainer-parity plan, a separate decision.
- Also fixed: two stale comments (`deploy.yml`, `CLAUDE.md`) this same diff would have left
  self-contradictory. `gitleaks`'s deliberate `--all` (every-branch, not just `main`) scan
  scope was investigated (confirmed via `-l debug`) and documented as a considered tradeoff,
  not silently accepted — narrowing it via `--log-opts` was considered and rejected as
  riskier than the residual it would close.
- **Sequence followed architect's explicit recommendation:** pushed the branch, watched all
  6 checks go green in real CI **first**, then applied the live ruleset `PUT` (read-modify-
  write, preserving all 4 existing rule types) so the PR's own required-checks state could be
  observed matching the new ruleset before merge — confirmed via the rules endpoint (exact
  6-value set match) and a green `ruleset-drift.yml` dispatch against the updated ruleset.

## Next

**Merge PR #86.** `/pr-checks` already verified it READY — all 6 required checks
(`pr-title`, `tofu-fmt`, `tofu-validate`, `tflint`, `secrets-scan`, `zizmor`) green.

**This is `S1b`'s last task.** Once merged, run **`/archive-sprint`** — but first re-check
`sprint_plan.md`'s Definition of Done section for the `MW` re-run acceptance criterion (a
fresh `destroy → apply → verify` cycle against the final `ci.yml`/`deploy.yml` shape) before
declaring the sprint fully done; don't assume it was already satisfied without checking.

**Model: `sonnet` / coder.**

## Open gates and blockers

**HITL Gate: OPEN — PR #86 awaiting human merge.** The live branch-protection ruleset is
**already updated and live** (not an open action — done deliberately before merge, per
`S1b`'s Definition of Done). What's open is only the merge click.

`glunk-works/global-bootstrap#7` (org-wide lock-table question) still awaits a response —
informational, not blocking.

**F61** (floating tool versions on `tofu-fmt`/`tofu-validate`/`tflint`) has no sprint owner
yet — flag it for whoever plans the next sprint.

## Pointers

- `docs/hardening_roadmap.md` — reference of record and threat model. `F59`/`F60` now
  `✅ CLOSED`; new `F61` recorded. `S1b`'s status row still needs updating to `complete` —
  do that in the post-merge cursor sync, matching the pattern used after `T3` and `T6`.
- `sprints/S1_pipeline_hardening/sprint_plan.md` — Task 7 is the sprint's last task; its
  Definition of Done section is the next thing to re-check.
