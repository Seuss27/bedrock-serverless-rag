# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`blocked` — `S2` (Identity, state reconciliation, and `bootstrap/` retirement).**
Tasks **0 (0a/0b/0c), 1, 2, 3 are done, applied, and verified.** **Task 4 is scoped and
blocked** on an upstream apply (below).

## ⚠️ The incoming cursor pointed at already-completed work — corrected

The previous cursor said *"the real next action is Task 0, not Task 4 … Scope Task 0a first."*
**Wrong, in the direction that wastes a session redoing applied infrastructure.** Re-measured:

- **Task 0a/0b** landed and were verified — this repo's own cursor-sync **PR #102**.
- **Task 0c**: `glunk-works/global-bootstrap#11` — **MERGED 2026-08-10**, and **applied**.
- **Confirmed in live AWS**: both roles exist — `github-actions-bedrock-serverless-rag` and
  `…-plan` (names only, BR-D4). Apply role's operator is **`StringEquals`** (**F2 closed at
  the IAM layer**), subjects exactly `ref:refs/heads/main` + `environment:production`, **no
  `:pull_request`**. Plan role trusts `:pull_request` **and** `:ref:refs/heads/main`
  (**F56 gap (a) closed**). Both carry the BR-D27 ID-qualified prefix.

**The prior session's evidence was real but misread**: it ran `gh secret list`, found no
`AWS_PLAN_ROLE_ARN`, and concluded the upstream role didn't exist. That secret is *this
repo's* wiring, which **Task 4 step 1 creates**. **A missing consumer is not a missing
producer.**

## Just done — Task 4 scoped, and its real blocker found and fixed upstream

- **Task 4 split agreed (3 PRs)**: **PR A** = step 1 secrets + step 2 `plan.yml` +
  `ci.yml` header amendment → **step 3 verification cycle** (no PR) → **PR B** = step 4
  delete `bootstrap/`'s role + `state_access_policy` (**F1**) + the Task 3 bridge (human
  apply) → **PR C** = step 5 require `tofu-plan` as the seventh check.
- 🔴 **Found the actual live break in step 1 — and it is NOT the one the sprint plan
  documents.** The plan warns the break would be a trust-policy subject mismatch; that is
  closed. The real one: **the plan role cannot complete a `tofu init` at all.** OpenTofu's
  `aws_kms` key provider calls **`kms:GenerateDataKey` unconditionally** on every operation
  (measured from its source — `internal/encryption/keyprovider/aws_kms/provider.go`'s
  `Provide()`; `Decrypt` is the *conditional* call). The plan role had only
  `kms:Decrypt`/`kms:DescribeKey`. Creating `secrets.AWS_PLAN_ROLE_ARN` flips
  `tofu-plan-main`'s `||` fallback onto it → **every merge to `main` would fail at init.**
- **Fixed upstream: `glunk-works/global-bootstrap#12` — OPEN, awaiting human review +
  hand-apply.** Baseline `No changes.`; with the fix `0 to add, 1 to change, 0 to destroy`
  (`aws_iam_policy.bedrock_rag_plan_policy` only). No sibling project's policy is in the
  change set. Not a write path — writing state needs `s3:PutObject`, which the plan role
  still lacks.
- **⚠️ This corrects a previous `security-critic` recommendation.** The verb was dropped on
  a critic's advice; it reads as correct least-privilege and is tool-breaking. The
  superseded reasoning is retained struck-through in the upstream file with a
  do-not-re-tighten warning.
- **No critic pass ran on the upstream diff** — offered and declined in favour of handing
  off. On the record.
- Also fast-forwarded a stale local `main` to `c06856d` (cursor-sync PR #112 had merged) and
  pruned 2 squash-merged branches. Ruleset healthy (4 rule types, 6 required checks).

## Next

1. **Human: review and apply `glunk-works/global-bootstrap#12`** (hand-applied; that repo
   has no CI and — worth noting separately — **no branch protection at all**).
2. **Verify the verb landed** before anything else:
   `aws iam get-policy-version` on `glunk-works-bedrock-serverless-rag-plan-readonly`,
   `StateEncryptionKeyReadAccess` must list `kms:GenerateDataKey`. Read it from AWS, never
   from the upstream HCL.
3. **Then PR A.** Full step-by-step and the 8 inherited security constraints are in
   `sprints/S2_identity_least_privilege/sprint_plan.md` `### Task 4` (re-derive the line
   range with `grep -n '^### Task 4'`). Key ones: `plan.yml` is a **new third workflow
   file** (it can live in neither `ci.yml` — uncredentialed by construction — nor
   `deploy.yml` — no `pull_request` trigger); it points at the **plan** role from its first
   commit; `tofu plan -lock=false`; no `name:` override; summarize to
   `$GITHUB_STEP_SUMMARY`, never an artifact.

⚠️ **Also correct the sprint plan's step 3 sub-order in PR A** (dated banner, per the
banner-vs-body convention): it is written *destroy → merge/apply → destroy* assuming "the
lab already up from Task 2". **The lab is torn down**, so the first destroy dispatch is a
no-op proving nothing. Correct order from here: **PR plan green → merge/apply (`12 to add`,
create verbs) → destroy dispatch (destroy verbs) → down.**

⚠️ **No other PR may be open across this cutover** (`strict_required_status_checks_policy`).

**Model: `sonnet` / coder** — the design is settled; PR A is specified implementation.
**`/way-of-working:critic-gate` is mandatory on PR A** (security-critic + architect): it puts
a credentialed job back on `pull_request` for the first time since `S1b`-T2 closed F3's
exploitable instance.

## Open gates and blockers

**HITL Gate: OPEN.** `global-bootstrap#12` must be reviewed and hand-applied by a human
before any Task 4 implementation begins — PR A's first act creates the secret that flips CI
onto the role that PR fixes. Do not start unattended.

**Not filed, deliberately** (`security-critic` #1, LOW, carried from Task 2): no required
check can *see* `encryption.tf`'s `enforced = true`, so deleting it passes all six checks
green. Details in `.ai/state.json`'s `known_followups`.

## Pointers

- `docs/hardening_roadmap.md` — reference of record and threat model. Unchanged this session.
- `sprints/S2_identity_least_privilege/sprint_plan.md` — Tasks 0–3 done; Task 4 next.
- `glunk-works/global-bootstrap#12` — the open upstream blocker.
