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

### ✅ The stack is DESTROYED — nothing is running, nothing is billing

> **⚠️ Corrected 2026-08-08 21:10 UTC.** This section previously read *"The stack is live, and it
> is not cheap"* and recommended destroying it. **That was true when written and false by the
> time it merged** — the owner had already acted on the recommendation ~90 minutes earlier, and
> the handoff restated the finding without re-measuring. The repo's own `record-is-not-evidence`
> failure, committed into the ledger whose job is to prevent it. Left visible rather than
> quietly overwritten.

**Verified against AWS and state, not inferred:** `aws opensearchserverless list-collections`
and `bedrock-agent list-knowledge-bases` both return empty; `tofu state list` returns 0
resources; the S3 state object is 373 bytes (an empty state). The teardown was run
`31274829358` — a `workflow_dispatch` of `destroy-ai-lab` **dispatched 19:36:11 UTC, completed
19:37:16** — `Plan: 0 to add, 0 to change, 12 to destroy` → **`Apply complete! Resources: 0
added, 0 changed, 12 destroyed`**. *(Both minutes appear across these docs; they are the run's
start and finish, not a discrepancy.)*

⚠️ **The three verifications above have a short shelf life, by design:** granting the pending
approval below falsifies all of them at once.

**It tore down clean in ONE pass** — worth recording, because `MW`-T6 needed three rounds before
the CI role held enough IAM verbs. The destroy path is now proven sufficient end-to-end. *(This
does not discharge `S1b`'s DoD, which requires the cycle against the **new** split files that
`T2` has not written yet.)*

**`standby_replicas = DISABLED` is now FILED, not a suggestion** — the attribute is
[`opensearch.tf:97`](modules/aws-bedrock-rag/opensearch.tf#L97), inside the resource at
[`61-104`](modules/aws-bedrock-rag/opensearch.tf#L61-L104), and the decision is **BR-D26**. It
costs nothing to adopt against an empty state and takes effect on the next build.

### 🔴 A rebuild approval is PENDING RIGHT NOW — do not click it by reflex

**Run [`31277980735`](https://github.com/glunk-works/bedrock-serverless-rag/actions/runs/31277980735)
(the merge of PR #72) has `tofu-apply` sitting in `waiting` since 20:54 UTC.** `tofu-plan-main`
already succeeded on it. Against an empty state that plan is **`12 to add`**, so **granting that
approval rebuilds the entire stack** (~15 min, most of it the AOSS collection) and restarts the
OCU meter. This is not hypothetical or "next time" — it is one click, outstanding, now.

Since `S1a`-T5 removed `paths:`, **every** merge to `main` runs `tofu-apply`. While the stack was
up those were `0/0/0` no-ops and approving by reflex was harmless — the habit the approvals on
#70 and #71 established. **That habit is now the hazard.**

**Read `tofu-plan-main`'s summary before approving.** `total changes: 0` is a no-op;
`total changes: 12` is a rebuild. To keep the lab torn down, **decline** — `main` then describes
a stack that is not applied, which is the correct posture for a lab the `S1` plan describes as
*"designed to sit destroyed with nobody on call"* (`sprint_plan.md`, in a BR-D23 reshape banner).

⚠️ **Runs queue, they do not cancel.** `deploy-ai-lab.yml`'s workflow-level `concurrency` group
sets `cancel-in-progress: false`, and `destroy-ai-lab` shares that group — so any later merge's
apply **queues behind this waiting one**, and a burst of three or more can silently drop a
middle run's pending approval. Resolve this one before stacking another merge on top of it.

`glunk-works/global-bootstrap#7` (org-wide lock-table question) still awaits a response —
informational, not blocking.

## Pointers

- `docs/hardening_roadmap.md` — reference of record and threat model.
- `sprints/S1_pipeline_hardening/sprint_plan.md` — **top banner first.** `T4`'s body is retained
  there verbatim under a do-not-execute header, as the normative spec `S2` inherits.
- `.ai/archive/S1a-next-steps.md` — `S1a`'s final cursor, for history queries.
