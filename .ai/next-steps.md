# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`done` — `S1a` (the F13 gate).** `S1a` = Task 5 alone, merged as PR #69 (`664ea62`).
`S1b` (`T2 → T1 → T4 → T3 → T6 → T7`) has not started — the sprint plan calls for a
reassessment pause between the two slices, and that reassessment is what's next.

## Just done

**`S1a`-T5 implemented, critic-reviewed, and merged.** `.github/workflows/deploy-ai-lab.yml`
now splits the fused plan+apply job into `tofu-plan-main` → `tofu-apply`, with
`environment: production` on `tofu-apply` only, a saved-plan apply (F14), a workflow-level
`concurrency` group (F20), and the `paths:`/`name:` overrides removed (F18 half).

- **`/critic-gate` ran before shipping** (security-critic + architect, both confirmed by the
  owner). Both independently caught the same **HIGH-severity regression** in the first
  draft: the plan/apply split had dropped `-no-color … > /dev/null` from `tofu plan`, which
  would have dumped the full plan render — account id, role ARNs, the AOSS endpoint — into
  the **public** workflow log on the next infra-bearing merge. Fixed before merge. Also
  fixed: `persist-credentials: false` on `tofu-apply`'s checkout, `-lock-timeout=5m` on its
  apply step, null-safe jq, a matching plan-file cleanup step.
- **Two residuals recorded as comments, not fixed** — both already named as accepted in the
  sprint plan's own Critical Review: the plan the approver reads (`tofu-plan-main`'s) isn't
  quite the plan that applies (`tofu-apply` re-plans after approval); and a burst of 3+
  rapid merges can silently drop a *pending* run's approval (`cancel-in-progress: false`
  still correctly protects any *in-progress* apply).
- **The `production` Environment was created out-of-band**, with the owner's explicit
  go-ahead — required reviewer `Seuss27`/`22668449`, `protected_branches: true`, verified
  live both before and after creation.
- **The gate was observed working on this PR's own merge** — `tofu-plan-main` succeeded,
  `tofu-apply` sat in `waiting`, and the owner saw GitHub's own "requested your review to
  deploy to production" notification live. T5's Definition of Done is fully satisfied.

## Next

**Human: reassess `S1b`'s task order/scope** in light of what `S1a` actually showed — with
`paths:`/`name:` gone, **every** merge to `main`, including docs-only ones, now triggers
`tofu-plan-main` + `tofu-apply` and consumes an approval. Confirm that trade is still
accepted before starting the six-task rewrite (`sprints/S1_pipeline_hardening/sprint_plan.md`'s
2026-08-08 banner has `S1b`'s full order: `T2 → T1 → T4 → T3 → T6 → T7`).

Once reassessed: either run `/way-of-working:archive-sprint` to formally close `S1a` and
advance the cursor to `S1b`, or begin `S1b`'s `T2` directly.

**Model: `opus` / architect** for the reassessment; `S1b`'s own tasks are `sonnet` / coder
work once scoped.

## Open gates and blockers

**HITL Gate: OPEN** — "stop and reassess before `S1b`" is an explicit owner decision point
named in the sprint plan itself, not a mechanical continuation. The next session should not
auto-start `S1b`-T2 on the strength of this cursor alone.

Whether the merged PR's own `tofu-apply` run was subsequently approved/completed is not
tracked here — it doesn't gate `S1a`'s own Definition of Done, which names only the observed
pause (satisfied above).

`glunk-works/global-bootstrap#7` (org-wide lock-table question) still awaits a response —
informational, not blocking.

## Pointers

- `docs/hardening_roadmap.md` — reference of record and threat model.
- `sprints/S1_pipeline_hardening/sprint_plan.md` — read the 2026-08-08 banner first;
  `S1b`'s task order and its own Definition of Done paragraph are both there.
- `.ai/archive/MW-next-steps.md` — `MW`'s final cursor, for history queries.
