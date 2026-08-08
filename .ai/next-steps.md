# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`implementing` — `S1a` (the F13 gate).** `S1` was re-planned and **split at T5** on
2026-08-08. `S1a` is **Task 5 alone**; `S1b` is everything else. Nothing is in flight.

## Just done

**`S1` planning is complete and merged** — PR #67 (`97a2c15`), preceded by PR #66
(`e088776`). Re-planned against live measured state, self-critiqued, then split.

- **Split at T5.** `S1a` = T5 alone (F13, F14, F20, + the `paths:`/`name:` half of F18).
  `S1b` = `T2 → T1 → T4 → T3 → T6 → T7` (F15, F16, F19, F21, rest of F18). Reassess between.
- **Four dead premises corrected in the task bodies, not just the banner** — they are
  copy-pasteable literals. Chief among them: **`vars.*` no longer exists in this repo**
  (all four values are `secrets.*` after `MW`-T6's BR-D21 correction), so every `vars.X`
  in the plan was **dead syntax resolving to an empty string rather than erroring**. Also:
  F39's "plan output cannot be trusted" bullet struck; `GITLEAKS_LICENSE` deadlock resolved
  by measurement (org secret, visibility `ALL`); `Seuss27/` → `glunk-works/` in T5's and
  T7's operative `gh` commands.
- **Two ordering defects, found by critique rather than execution.** The `paths:` filter
  excludes `.github/workflows/`, so **no `S1` merge could trigger the deploy workflow** and
  the F13 gate would have landed unverifiable — proof: commit `8f51501` had to touch
  `environments/ai-lab/main.tf` to trigger `MW`-T6's rebuild. `paths:`/`name:` removal moved
  from T2 into **T5**. And T1 ran before T2, SHA-pinning a file T2 then deletes — T1 moved after.
- **BR-D25 recorded** (the manual destroy path stays phrase-gated — an accepted residual on a
  trust boundary). That made `BR-D1..BR-D24` stale in `CLAUDE.md` (×2) and `.ai/project.yml`;
  all three updated.
- One process note worth carrying: the banner's first draft opened *"Measured, not assumed"*
  while resting on two unverified claims, one of which was **wrong**. Recorded in the banner
  rather than quietly fixed.

## Next

**Implement `S1a` = Task 5 only**, in `.github/workflows/deploy-ai-lab.yml` — `deploy.yml`
does **not** exist yet (T2 creates it, in `S1b`). **Read the sprint plan's 2026-08-08
`RE-PLANNED` banner first**; it outranks the older banner and every task body.

Five changes, one file: split `opentofu-pipeline` into `tofu-plan-main` → `tofu-apply`; add
`environment: production` to `tofu-apply` only; apply the **saved plan file** instead of
re-planning (F14); add a `concurrency` group with `cancel-in-progress: false` (F20); delete
the `paths:` filter and **both** `name:` overrides (F18 half). Leave the `destroy-ai-lab` job
and the account-id log-masking step untouched.

**Model: `sonnet` / coder.** Run `/critic-gate` (propose `security-critic` + `architect`)
before `/way-of-working:ship` — this diff is `code_paths`, and this repo has no CI review gate.

## Open gates and blockers

**HITL Gate: NONE OPEN** — the workflow edit is safe to start unattended. **Two gates open
later, both *inside* `S1a`-T5:**

1. **Creating the `production` Environment** is a repo-**settings** change made outside the
   diff, with a silent failure mode — a wrong reviewer id yields an environment that pauses
   for nobody, and GitHub raises no error. **Confirm with the owner** before the
   `gh api -X PUT …/environments/production` call. Reviewer id `22668449` (`Seuss27`) was
   verified live 2026-08-08; `glunk-works` has no teams.
2. **At merge:** T5's acceptance requires **observing** the `tofu-apply` job pause for
   approval on T5's own merge — not inferring it from the YAML.

`glunk-works/global-bootstrap#7` (org-wide lock-table question) still awaits a response —
informational, not blocking.

## Pointers

- `docs/hardening_roadmap.md` — reference of record and threat model. **BR-D25** added; the
  sprint table now lists `S1a` and `S1b`, with a governing note mapping the finding
  inventory's older `S1-T<n>` cells (`T5` → `S1a`, all others → `S1b`).
- `sprints/S1_pipeline_hardening/sprint_plan.md` — **read the 2026-08-08 banner first.**
- `.ai/archive/MW-next-steps.md` — `MW`'s final cursor, for history queries.
