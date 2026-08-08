# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`implementing` — `S1b` (the pipeline rewrite).** Five tasks, `T2 → T1 → T3 → T6 → T7`.

> **Why `implementing` and not `planning`** *(the usual state after a sprint close)*: `S1b`'s
> planning pass already happened and merged as PR #71. There is no design question left open —
> `T2` is ready to write.

## Just done

**`S1a` closed and archived** (final cursor snapshot: `.ai/archive/S1a-next-steps.md`).

- **`S1a`-T5 merged as PR #69 (`664ea62`)** — `tofu-plan-main` → `tofu-apply`,
  `environment: production` on the apply job only, saved-plan apply (F14), workflow-level
  `concurrency` (F20), `paths:`/`name:` removed (the F18 half). **Verified live, not inferred:**
  run `31272226259` — plan green in 32s, apply paused in `waiting`, approved, applied green in
  40s. Closes **F13, F14, F16, F20** and half of **F18**.
- **The mandated reassessment ran and merged as PR #71 (`8cc1d5b`).** `S1b` went from six tasks
  to five. **`T4` deferred to `S2`**; **`checkov` run by `T3` but not required by `T7`** (gating
  moved to `S3`). The approval-on-every-merge trade it was called to weigh is **confirmed
  unchanged**.

## Next

**`S1b`-T2 — split `deploy-ai-lab.yml` into `ci.yml` + `deploy.yml`.**

> ⚠️ **Read the sprint plan's TOP banner before the task body.** Three banners are stacked
> newest-first; the 2026-08-08 post-`S1a` one outranks both the others *and* every task body.

**The one correction that matters most:** **`deploy.yml` gets NO `pull_request` trigger** —
`push: branches: [main]` and `workflow_dispatch` only. T2's body still described one "(plan,
Task 4)" and is corrected in place. With `T4` in `S2`, deleting `deploy-ai-lab.yml` leaves this
repo with **zero credentialed `pull_request` jobs for the first time in its history** — that is
the point of the task. Re-adding the trigger "for T4" undoes the sprint's largest single
security gain in its first commit.

Also carry forward, per the task body: `destroy-ai-lab` **byte-identical — keeping its `name:`
key** (it is `workflow_dispatch`-only, can never be a required check, so F18's rule does not
bind it); the `Register bare account id for log masking` step as the **first step after
checkout** in every credentialed job; `ruff`/`bandit` as their own uncredentialed `ci.yml` job;
a committed `.tflint.hcl`.

**Model: `sonnet` / coder.** **Run `/way-of-working:critic-gate` before `/ship`** — this diff is
entirely `code_paths` and entirely trust-boundary.

## Open gates and blockers

**HITL Gate: NONE OPEN for `T2`.** The "stop and reassess before `S1b`" gate is closed — the
reassessment was performed, approved, and merged (#71). `T2` is a workflow-file rewrite,
depends on nothing below, and still ends at `/critic-gate` and `/ship`.

### ⚠️ The stack is live, and it is not cheap — owner decision open

Measured 2026-08-08. **All 12 resources exist and match config**, evidenced by run
`31274238499`'s apply reporting `0 added, 0 changed, 0 destroyed` under the CI role. The cost:
[`opensearch.tf:61-72`](modules/aws-bedrock-rag/opensearch.tf#L61-L72) sets **no
`standby_replicas`**, so the `VECTORSEARCH` collection takes AWS's default `ENABLED` — the
~4-OCU redundancy floor, not the 2-OCU dev floor. **AOSS bills that floor regardless of usage**;
at $0.24/OCU-hour that is roughly **$690/month** against the **$20** guardrail in
[`variables.tf:34`](environments/ai-lab/variables.tf#L34), on a corpus BR-D20 says is empty.
*Derived from AWS's published pricing, **not** an observed bill — confirm in Cost Explorer.*

**Recommendation: destroy it.** Not a compromise — BR-D20 says nothing here is precious, and
`S1b`'s own DoD requires a `destroy → apply → verify` cycle anyway, so the rebuild is work that
must happen regardless. **Not fired:** `destroy-ai-lab` is `workflow_dispatch` + typed confirm
phrase + human-watched (~11 min for AOSS; per the `MW` lesson, check *which* step is slow before
reading elapsed time as stuck). *Worth a small separate change: `standby_replicas = DISABLED`
roughly halves the floor for a lab needing no redundancy — not yet filed.*

### ⚠️ Destroying changes what an Environment approval means

Since `S1a`-T5 removed `paths:`, **every** merge to `main` runs `tofu-apply`. While the stack is
up those are `0/0/0` no-ops and approving by reflex is harmless — which is exactly the habit the
two approvals on #70 and #71 just established. **The moment the stack is destroyed that stops
being true:** the next merge of anything, including a docs-only handoff PR, plans `12 to add`
and **rebuilds the whole stack** if approved. **Read `tofu-plan-main`'s summary before
approving** — a non-zero `total changes:` on a docs-only merge means a rebuild, not a no-op.

`glunk-works/global-bootstrap#7` (org-wide lock-table question) still awaits a response —
informational, not blocking.

## Pointers

- `docs/hardening_roadmap.md` — reference of record and threat model.
- `sprints/S1_pipeline_hardening/sprint_plan.md` — **top banner first.** `T4`'s body is retained
  there verbatim under a do-not-execute header, as the normative spec `S2` inherits.
- `.ai/archive/S1a-next-steps.md` — `S1a`'s final cursor, for history queries.
