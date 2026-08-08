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

**Re-confirmed 2026-08-08 after PR #73 merged:** both rebuild approvals were **rejected**
(runs `31277980735`, `31283111192`), AWS still returns no collections and no knowledge bases,
and the lab remains down. ⚠️ **These verifications expire the moment any rebuild approval is
granted — re-measure rather than re-quoting them.**

**It tore down clean in ONE pass** — worth recording, because `MW`-T6 needed three rounds before
the CI role held enough IAM verbs. The destroy path is now proven sufficient end-to-end. *(This
does not discharge `S1b`'s DoD, which requires the cycle against the **new** split files that
`T2` has not written yet.)*

**`standby_replicas = DISABLED` is now FILED, not a suggestion** — the attribute is
[`opensearch.tf:97`](modules/aws-bedrock-rag/opensearch.tf#L97), inside the resource at
[`61-104`](modules/aws-bedrock-rag/opensearch.tf#L61-L104), and the decision is **BR-D26**. It
costs nothing to adopt against an empty state and takes effect on the next build.

### ⚠️ A RED push-to-`main` run is now the EXPECTED steady state — do not read it as broken

**This is the single most misreadable signal in the repo right now, so read it before reacting
to a red X on `main`.**

Since `S1a`-T5 removed `paths:`, **every** merge to `main` runs `tofu-apply`. With the lab
deliberately torn down, every such run plans **`12 to add`** — a full rebuild — so the correct
response is to **reject the Environment approval**. **Rejecting records the job and the whole
run as `failure`** (measured: runs `31277980735` and `31283111192`, both rejected, both
`conclusion: failure`, with `security-and-linting` and `tofu-plan-main` green inside them).

> 🔴 **The trap.** Until 2026-08-08 `CLAUDE.md` cited *"every push-to-`main` run remains
> `failure`"* as the evidence for **F39/F51 — that no CI apply had ever succeeded.** That
> sentence was struck the same day, because `MW`-T6 disproved it. **The identical red X is now
> back, meaning the opposite:** the pipeline works, the plan is trustworthy, and a human
> correctly declined a rebuild. Do not re-derive the retired conclusion from the recurring
> symptom. **To tell them apart, look INSIDE the run:** `tofu-plan-main` green + `tofu-apply`
> failed = a rejected approval, working as designed. `tofu-plan-main` failed = a real problem.

**Before approving anything, read `tofu-plan-main`'s summary.** `total changes: 0` is a no-op;
`total changes: 12` is a rebuild. Declining leaves `main` describing a stack that is not
applied — the correct posture for a lab the `S1` plan calls *"designed to sit destroyed with
nobody on call"* (`sprint_plan.md`, in a BR-D23 reshape banner).

⚠️ **Runs queue, they do not cancel.** `deploy-ai-lab.yml`'s workflow-level `concurrency` group
sets `cancel-in-progress: false`, and `destroy-ai-lab` shares it — so each merge's apply queues
behind any still-waiting one, and a burst of three or more can silently drop a middle run's
pending approval. Resolve one before stacking the next.

### 📌 New input for `S1b`, arising from the above — decide, don't drift

`S1a` accepted "every merge consumes an approval" on the premise that **the stack would be up
and the applies would be no-ops**. That premise inverted the moment the lab was torn down: with
it down, every merge — including every docs-only handoff PR — now costs **a manual rejection and
leaves a red run on `main`**. Two real consequences: approval fatigue on a gate whose entire
value is that someone reads it, and a `main` whose CI history is red by design, which is exactly
the condition under which a genuine failure stops being noticed.

**This is not a bug and `S1a`-T5 was not wrong** — it is a premise that changed after the
decision. **`S1b`-T2 should decide it explicitly** (options: leave as-is and accept the noise;
gate `tofu-apply` on a non-zero `total changes:`; or a `workflow_dispatch`-only apply while the
lab is meant to sit destroyed). ⚠️ **Note the tension before choosing:** the reassessment banner
in the sprint plan explicitly warns against a skip-if-no-changes short-circuit, because it
reduces how often the gate is exercised. That warning was written while the stack was UP and
every apply was a no-op — the reverse of today. Re-read it against the current premise rather
than treating it as settled either way.

`glunk-works/global-bootstrap#7` (org-wide lock-table question) still awaits a response —
informational, not blocking.

## Pointers

- `docs/hardening_roadmap.md` — reference of record and threat model.
- `sprints/S1_pipeline_hardening/sprint_plan.md` — **top banner first.** `T4`'s body is retained
  there verbatim under a do-not-execute header, as the normative spec `S2` inherits.
- `.ai/archive/S1a-next-steps.md` — `S1a`'s final cursor, for history queries.
