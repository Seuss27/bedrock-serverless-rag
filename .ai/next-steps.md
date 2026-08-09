# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`implementing` — `S1b` (the pipeline rewrite).** `T2` done. Four tasks left:
`T1 → T3 → T6 → T7`.

## Just done

**`S1b`-T2 shipped as PR #76 (`d2d3ef2`).** `deploy-ai-lab.yml` split into `ci.yml`
(uncredentialed, `pull_request`-triggered) and `deploy.yml` (credentialed, `push`+
`workflow_dispatch` only) — **zero credentialed `pull_request` jobs, for the first time in
this repo's history.**

- `/critic-gate` ran two full rounds (`security-critic` + `architect`). Round 1 caught a
  **HIGH** bug (`tofu-validate` as a `matrix` job — GitHub never names a matrix job's
  check-run the bare id a required check matches). Round 2 caught a **self-introduced**
  bug: round 1's own `CLAUDE.md` fix wrongly declared **F3 "closed"** — only the exploitable
  `pull_request` *instance* closed; F3 itself stays **open** pending `S2`-T2's actual
  plan/apply role separation. Both `CLAUDE.md` and the roadmap's F3 row now agree.
- **Live incident, fully resolved.** The merge-triggered rebuild (run `31286993215`) got
  11/12 resources created; `tofu-apply` failed on `create_index.py`'s `AuthorizationException`
  — diagnosed as AOSS data-access-policy **propagation timing**, not a real permissions
  regression (the failed check ran **1.4ms** after the policy reported "complete"; `tofu-apply`'s
  own commands were diffed byte-identical against pre-`T2` first, to rule out the diff itself).
  `gh run rerun --failed` succeeded immediately, confirming the timing hypothesis.
- **`S1b`'s own Definition-of-Done — `destroy → apply → verify` against the NEW split
  files — PASSED.** Owner dispatched `destroy-ai-lab` after the successful rebuild:
  `Plan: 0 to add, 0 to change, 12 to destroy` → `Apply complete! Resources: 0 added,
  0 changed, 12 destroyed`, **one clean pass** (run `31288349529`) — unlike `MW`-T6's
  original three-round teardown. Caveat: "verify" here is the apply's own resource-count
  summary; no `retrieve_and_generate` call was run this cycle.
- **The lab is deliberately torn down again** as of this handoff.

## Next

**`S1b`-T1 — pin every action to a commit SHA, close the remaining `persist-credentials`
gap.**

- Resolve each `uses:` tag in `ci.yml`/`deploy.yml` with
  `gh api repos/<owner>/<repo>/git/ref/tags/<tag> --jq '.object.sha'` (dereference an
  annotated-tag object per the sprint plan's Task 1 body). Six actions are already
  verified in `glunk-works/bounty-infra` and may be reused as-is — see the task body.
- Add `with: persist-credentials: false` to `destroy-ai-lab`'s checkout in `deploy.yml` —
  the one checkout across both files still missing it (`T2` deliberately left it, since
  that job had to carry byte-identical).
- Run `zizmor` and confirm no `unpinned-uses` or `artipacked` finding.

**Model: `sonnet` / coder.**

## Open gates and blockers

**HITL Gate: NONE OPEN for `T1`.** Nothing blocks starting it unattended.

**Worth watching, not yet acting on:** the `AuthorizationException`-on-first-attempt this
session hit once, explained by an unusually fast apply. If a future apply hits the same
failure **after** a retry-with-delay too, that's real evidence of a genuine gap (unlike this
one) and should be investigated as such — don't assume timing twice.

`glunk-works/global-bootstrap#7` (org-wide lock-table question) still awaits a response —
informational, not blocking.

## Pointers

- `docs/hardening_roadmap.md` — reference of record and threat model.
- `sprints/S1_pipeline_hardening/sprint_plan.md` — **top banner first.** Task 1's body has
  the SHA-resolution commands and the six pre-verified action pins.
