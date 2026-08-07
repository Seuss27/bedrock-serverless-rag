# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`implementing` — `ST` (organization transfer). The repo lives at
`glunk-works/bedrock-serverless-rag`.**

**ST-T3 and ST-T4 are both COMPLETE and merged.** Only **ST-T5** (recording the outcome)
remains before this sprint's `/archive-sprint`.

## Just done

- **ST-T3 complete and verified against live AWS, not the HCL.** `widen → transfer → narrow`
  completed in one session, as the sprint required: PR **#29** (widen, `8563844`), PR **#30**
  (narrow, `ae06e51`). Trust policy is now the single subject
  `repo:glunk-works@…/bedrock-serverless-rag@…:*`, zero `Seuss27` occurrences, both a push- and
  a `pull_request`-context run authenticated afterwards, and
  `github-actions-bedrock-serverless-rag` still returns `NoSuchEntity`.
  - **⚠️ The transfer broke CI auth, for a reason not in any plan.** An **org-owned** repo
    presents an **ID-qualified** OIDC subject — `repo:<owner>@<org_id>/<repo>@<repo_id>:…` —
    which a plain `repo:<owner>/<repo>:*` glob does **not** match. Measured from CloudTrail.
    Written into `S2-T2` and the roadmap's F2 row, because enumerating the plain form under
    `StringEquals` reproduces the outage in the task that also deletes the fallback role.
  - `/critic-gate` ran (`security-critic`, `docs-consistency`) on the T3 diff; every finding
    applied and merged. PR #31 (`2f9ca85`) fixed four stale `CLAUDE.md` claims. Issue #32
    filed: Checkov scans nothing and passes green.
- **ST-T4 MERGED as PR #34** (`1c72369`, 2026-08-07T01:01:07Z). Worked the sprint plan's
  rewritten, explicit operative-file list rather than the old (unachievable)
  `grep -rn Seuss27` criterion:
  - Edited `.ai/project.yml` (`repo:` key → `glunk-works/bedrock-serverless-rag`; the
    explanatory **comment** above it is deliberately untouched — that's T5's job) and
    `.github/ISSUE_TEMPLATE/config.yml` (discussions URL repointed; Discussions confirmed
    enabled at the new location).
  - Verified, no edit needed: `.github/CODEOWNERS` still resolves cleanly (`codeowners/errors`
    empty; `Seuss27` holds `admin` on the transferred repo, so GitHub is **not** silently
    ignoring it); `README.md`/`CLAUDE.md` have no self-referential repo path to fix; the live
    trust policy on `github-actions-deploy-role` is the single ID-qualified
    `glunk-works@…/bedrock-serverless-rag@…` subject with zero `Seuss27` occurrences.
  - **Re-verified every S0 acceptance criterion live, under the new owner**, per T4's own
    instruction ("treat as absent until observed present"): ruleset healthy; merge settings
    already matched (no `PATCH` needed); labels all present; `pr-title` workflow still clean;
    baseline files intact; **`ruleset-drift.yml` manually dispatched and passed** (run
    `31136157954`). `environments` `total_count` still `0` — that's S1-T5's job, not this
    task's.
  - Green gate passed (`tofu fmt`, `tofu validate` ×2 — only non-`.tf` files changed).
  - `/critic-gate` was **not** run on this diff — it touches neither `code_paths` entry
    (`modules/`, `environments/`, `bootstrap/`, `.github/workflows/`), so no pass was owed.
  - The branch needed a **merge-main-in refresh** before merge — PR #33 landed first and
    `strict_required_status_checks_policy` blocks a `BEHIND` branch. Refreshed by merging
    `main` in (never rebase/force-push, per this repo's convention); `pr-title` re-ran clean
    on the merge commit.

## Next

**`ST-T5` — record the outcome. Model: `opus` (architect); this is judgement work, not
mechanical.** Nothing blocks it: no AWS apply, no irreversible action remains in ST.

- Update `docs/hardening_roadmap.md`: mark **BR-D13 executed** with the transfer date, note in
  **F44/F45** what was verified (F45 closed **by removal**, not correction — state the
  mechanism), add a status-log row.
- Rewrite `.ai/project.yml`'s `repo:` **comment** (not the key — T4 already changed that) now
  that the transfer is real.
- **Write each re-homed finding into its destination sprint's plan**, not only here — a
  finding moved out of ST and not written into where it landed is a finding dropped:
  **F55 → MW** (`bootstrap/state-backend.tf`'s `state_access_policy`), **F56, F58, F57's
  `permissions_boundary` half → S2** (Task 2b is normative). **F41/F42 stay OPEN org-wide** —
  link `glunk-works/global-bootstrap#6`.
- Acceptance: no **operative** reference claims the repo is at `Seuss27/` (sprint plans and
  the roadmap's finding inventory keep theirs as history, by name); `docs-consistency` finds
  no contradiction across `load_bearing_docs`.

## Open gates and blockers

**HITL Gate: NONE OPEN.** No human-only act remains in ST: no AWS apply, no irreversible
action left. The next gate is ST's completion review before `/archive-sprint`, which waits on
T5 landing.

## Pointers

- `docs/hardening_roadmap.md` — reference of record **and** threat model; § 10's 2026-08-06
  entry is the authoritative record of the reshape. T5 adds the T3/T4 outcome rows.
- `sprints/ST_org_transfer/sprint_plan.md` — **the active sprint.** Reshape banner wins over
  task-body disagreements. Task 4's acceptance criterion was rewritten; the historical record
  is exempt by name.
- `sprints/S2_identity_least_privilege/sprint_plan.md` — carries the ID-qualified OIDC subject
  trap (an org-owned repo's subject is `repo:<owner>@<org_id>/<repo>@<repo_id>:…`, which a
  plain `StringLike "repo:<owner>/<repo>:*"` does not match) and is where F56/F58/F57's
  boundary half land.
- `sprints/MW_make_it_work/sprint_plan.md` — where F55 lands, re-pointed at this repo's own
  `state_access_policy`.
- `.ai/archive/S0-next-steps.md` — S0's final cursor, frozen for history.
