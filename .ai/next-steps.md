# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`implementing` — `S2` (Identity, state reconciliation, and `bootstrap/` retirement).**
Tasks 1, 2, and 3 are **done and verified**. **Task 0 (0a/0b/0c) is next** — Task 4 is
blocked on it, not the other way around.

## Just done

**S2 Task 3 complete and verified**, 2026-08-11 — bridge, then migrate to the org backend:

- Looked up the state-encryption KMS key ARN — **first attempt was wrong** (matched an
  unrelated alias; `IncorrectKeyException` proved it). Corrected by reading the ARN actually
  granted on the deployed `github-actions-deploy-role`'s policy via `aws iam get-role-policy`,
  not by guessing again.
- Verified the precondition first: 12 managed resources tracked (+1 data source) before
  migrating — Task 3's `No changes.` criterion is meaningful only against a populated state.
- Repointed `environments/ai-lab/backend.tf` to `glunk-works-tofu-state-00042`; human ran
  `tofu init -migrate-state` + `tofu plan` locally under admin-SSO — `No changes.`, all 12
  resources intact.
- Shipped as **PR #111, merged** (`e8247d9`). Critic-gate was proposed and **explicitly
  declined** by the human for this diff — shipped with no critic look, on the record.
- CI's `tofu-plan-main` went green against the org bucket (Task 3's CI criterion, satisfied).
- ⚠️ **`tofu-apply` then failed for a NEW reason** — not a declined Environment approval:
  `s3:PutObject AccessDenied` on the org bucket's `.tflock` object. **This is expected**:
  Task 3's bridge policy is deliberately read-only (no `PutObject`/`DeleteObject`) — the
  first CI *write* to the org bucket is explicitly Task 4's job, via the upstream apply role.
  Matches Task 4's own spec (`tofu plan -lock=false` is required for exactly this reason).
  No state was written or corrupted. **CLAUDE.md's red-X paragraph doesn't yet name this as
  a third category** (declined / real-problem / this) — worth a correction if it trips
  someone up again.
- **Lab torn down** at the human's request (BR-D20) via a **local** admin-SSO `tofu destroy`
  — not the `destroy-ai-lab` CI workflow, which would hit the identical `AccessDenied`.
  Verified independently: `aws opensearchserverless list-collections` returns zero.

## Next

**S2 Task 0** (0a → 0b → 0c), not Task 4. Confirmed via `gh secret list`: no
`AWS_PLAN_ROLE_ARN` exists yet, only the local `AWS_OIDC_ROLE_ARN` — the upstream role Task 4
adopts does not exist until Task 0c is merged and human-applied (the sprint plan's own words).

Read **`ST` Task 2b** (`sprints/ST_org_transfer/sprint_plan.md`) first — it is the *normative*
spec Task 0 implements, retained verbatim. Then re-derive Task 0's line range with
`grep -n '^### Task 0\|^#### Task 0' sprints/S2_identity_least_privilege/sprint_plan.md`
rather than trusting a number written here.

**Task 0 splits three ways, three PRs, two upstream applies:**
- **0a** — subject-prefix schema. Proves `No changes.`, needs no apply of its own.
- **0b** — the two trust-policy shape changes. **Changes the trust policy of three sibling
  projects** (`bounty-infra`, `tri-loop-dev`, `resume-optimizer`) — the **largest blast
  radius in this sprint**, not 0c.
- **0c** — this project's entry, the boundary, and the findings-archive `Deny`.

**Model: `opus` / architect** — this needs a reviewed plan before implementation, not direct
coding.

## Open gates and blockers

**HITL Gate: OPEN.** Task 0b touches shared org infrastructure outside this repo. Do not
begin any Task 0 implementation unattended — scope it with the human first, per the sprint
plan's own Critical review section.

**Not filed, deliberately** (`security-critic` #1, LOW, carried from Task 2): no required
check can *see* the encryption block, so deleting `encryption.tf` or its `enforced = true`
line passes all six checks green. Sketched fix and deferral reasons are in `.ai/state.json`'s
`known_followups`.

## Pointers

- `docs/hardening_roadmap.md` — reference of record and threat model. Unchanged this session.
- `sprints/S2_identity_least_privilege/sprint_plan.md` — Tasks 1–3 done; Task 0 is next.
- `sprints/ST_org_transfer/sprint_plan.md` — Task 2b, the normative spec for Task 0.
