# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`implementing` — `ST` (organization transfer). The repo now lives at
`glunk-works/bedrock-serverless-rag`.**

**`ST-T3` is COMPLETE.** The irreversible, time-critical part of this sprint is behind us.

## Just done

- **Transfer executed**, and `ST-T3`'s `widen → transfer → narrow` completed **in one
  session**, as the sprint required. PR **#29** (widen, `8563844`), PR **#30** (narrow,
  `ae06e51`). Verified against **live AWS, not the HCL**: the trust policy is now the single
  subject `repo:glunk-works@…/bedrock-serverless-rag@…:*`, **zero `Seuss27` occurrences**,
  and both a push-context and a `pull_request`-context run authenticated afterwards.
  `github-actions-bedrock-serverless-rag` still returns `NoSuchEntity`, so **F45 stayed
  closed through the moment it would have activated**.
- **⚠️ The transfer broke CI auth, and the reason is not in any plan.** An **org-owned** repo
  presents an **ID-qualified** OIDC subject — `repo:<owner>@<org_id>/<repo>@<repo_id>:…` —
  which a plain `repo:<owner>/<repo>:*` glob does **not** match. Measured from CloudTrail,
  not inferred. **This is written into `S2-T2` and the roadmap's F2 row**, because
  enumerating the *plain* form under `StringEquals` — the obvious way to satisfy S2-T2's
  criterion — reproduces the outage, in the task that also deletes the fallback role.
- **`/critic-gate` ran** (`security-critic`, `docs-consistency`); every finding was applied
  and merged. Notably: a third validation now rejects `*`/`?` in a subject prefix (the two
  original guards only caught inputs that already failed *closed*), the dead plain-form glob
  was dropped, and the trust subjects moved **into committed code** so the boundary is
  reviewable from the tree.
- **PR #31 (`2f9ca85`)** fixed four stale `CLAUDE.md` claims — worst of them the assertion
  that `.ai/project.yml`'s `ruleset` is `null`, the one sentence that routes a plugin skill
  down the no-gate branch.
- **Issue #32 filed:** Checkov scans **nothing** and passes green.

## Next

**`ST-T4` — re-establish what the transfer did not carry. Model: `sonnet` (coder).**
Nothing blocks it; no AWS apply and no human-only act remain in ST.

**Two of its criteria are already verified — record them, do not redo them:** the ruleset
**survived** intact (four rule types, `pr-title` required), and the repository variables and
secret **survived too** (so the plan's "assume gone" is satisfied by observation).

Still to do: merge settings from S0-T2, labels from S0-T3, `.github/CODEOWNERS` (still
`* @Seuss27` — GitHub *silently ignores* entries for principals without write access), and
the issue-template discussions URL. Work the plan's **explicit operative list**, never the
old repo-wide `grep -rn 'Seuss27'` criterion — it is unachievable and would rewrite history.

**Then `ST-T5` — switch to `opus` (architect) for it.** Recording the outcome and the
re-homed findings is judgement work, not mechanical.

## Open gates and blockers

**HITL Gate: NONE OPEN.** Every human-only act in ST is done — the transfer, and all three
`bootstrap/` applies. T4 and T5 are GitHub settings plus documentation.

The next gate is **ST's completion review before `/archive-sprint`**, which must not run
until T4 and T5 are both merged.

## Pointers

- `docs/hardening_roadmap.md` — reference of record **and** threat model.
- `sprints/ST_org_transfer/sprint_plan.md` — **the active sprint.** It carries a **reshape
  banner**; where the banner and a task body disagree, **the banner wins.** Task 4's
  acceptance criterion was rewritten, and the historical record is **exempt by name**.
- `sprints/S2_identity_least_privilege/sprint_plan.md` — carries the ID-qualified subject
  trap. **Read it before writing any `StringEquals` list.**
- `.ai/state.json` — the machine cursor, with the full detail this file deliberately omits.
