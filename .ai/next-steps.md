# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`awaiting_review` — `S2` (Identity, state reconciliation, and `bootstrap/` retirement).**
Tasks **0 (0a/0b/0c), 1, 2, 3 are done, applied, and verified.** **Task 4 PR A is shipped as
[PR #114](https://github.com/glunk-works/bedrock-serverless-rag/pull/114)**, awaiting human
review and merge.

## Just done — the `global-bootstrap#12` blocker cleared, PR A implemented and shipped

- **Verified live** (not just trusted the report) that `glunk-works/global-bootstrap#12`
  merged and applied: `StateEncryptionKeyReadAccess` on the plan-readonly policy now lists
  `kms:GenerateDataKey` alongside `kms:Decrypt`/`DescribeKey` (policy version v2). The plan
  role can complete a real `tofu init`.
- **Task 4 PR A implemented**: step 1 (secrets — `AWS_OIDC_ROLE_ARN` repointed at the new
  apply role, `AWS_PLAN_ROLE_ARN` created for the plan role; done directly by the human, since
  the action classifier blocks `gh secret set` from the agent in this session) + step 2
  (`.github/workflows/plan.yml`, a new third workflow running the deferred PR-time `tofu-plan`
  job on the read-only plan role) + the `ci.yml` header amendment + the Task 4 step 3 sub-order
  correction in `sprint_plan.md` (the lab is down entering Task 4, not up, so the verify order
  is plan → apply → destroy, not destroy-first).
- **`/way-of-working:critic-gate` ran to convergence — mandatory, not skipped**: this PR puts a
  credentialed job back on `pull_request` for the first time since `S1b`-T2 closed F3's
  exploitable instance. **4 rounds** (security-critic + architect + docs-consistency, in
  parallel each round; **2 rounds past the normal cap, with explicit human sign-off** to keep
  going rather than ship with known contradictions open). Real findings fixed, not just
  wording: `deploy.yml`'s stale `||` fallback (now points at the plan role alone);
  `CLAUDE.md`/the roadmap's F3 row both still asserting "zero credentialed `pull_request`
  jobs" file-wide; an unbounded credential-exfiltration window in `plan.yml` (added
  `role-duration-seconds`/`role-session-name`, `-lockfile=readonly`, a concurrency group);
  `encryption.tf`'s stale blanket "F3 closed by S1b-T2" claim; and — recurring across **three**
  rounds — the same `S2-T2`/`S2-T4` sprint-numbering error (the bootstrap role's deletion is
  Task 4 step 4, not Task 2/native-state-encryption) surfacing in one sibling copy after
  another: `sprint_plan.md`'s Security Considerations section, the roadmap's planning-review
  item, F1/F2's Sprint cells, and finally two spots inside `CLAUDE.md` contradicting its own
  already-corrected text six and 130 lines away.
- **5 commits** on `feat/s2-t4-pr-a-plan-role`. Rebased onto `main` after the human merged the
  incoming cursor-sync PR #113 (Task 4's own "no other PR may be open across this cutover"
  precondition), green gate re-verified clean post-rebase, PR #114 opened.

## Next

1. **Human: review and merge [PR #114](https://github.com/glunk-works/bedrock-serverless-rag/pull/114).**
2. **Then drive Task 4 step 3's verify cycle** (full spec:
   `grep -n '^### Task 4' -A 200 sprints/S2_identity_least_privilege/sprint_plan.md`):
   1. The merge's own `tofu-plan-main` → `tofu-apply` should plan `12 to add`; after the
      human clicks the `production` Environment approval, it should succeed — **exercises the
      create verbs under the new apply role.** Capture the run link.
   2. Dispatch `destroy-ai-lab` (typed confirm phrase, human watches live per BR-D25) —
      **exercises the destroy verbs under the new apply role.** Capture that run link too.
   3. Record both run links per Task 4's acceptance criteria ("each evidenced by the run,
      never inferred from the file").
3. **Then PR B** (Task 4 step 4: delete `bootstrap/`'s escalation-capable role +
   `state_access_policy` — human apply) and **PR C** (step 5: require `tofu-plan` as the
   seventh check).

**Model: `sonnet` / coder** — the design is settled; this is driving a defined verify cycle,
not planning.

## Open gates and blockers

**HITL Gate: OPEN.** PR #114 must be reviewed and merged by a human before Task 4 step 3's
verify cycle begins — merging is not an agent action in this repo. The cycle itself carries
two more human-gated steps already built into the pipeline (the Environment approval, the
destroy confirm phrase). Do not begin step 3 unattended.

**Not filed, deliberately** (`security-critic` #1, LOW, carried from Task 2): no required
check can *see* `encryption.tf`'s `enforced = true`, so deleting it passes all six checks
green. Details in `.ai/state.json`'s `known_followups`.

**New process note:** the action classifier in this session blocked the agent from running
`gh secret set` directly — secret rotation needs the human to run the handed-over commands
themselves. Not repo-specific; may recur.

## Pointers

- `docs/hardening_roadmap.md` — reference of record and threat model. Touched this session
  only for the S2-T2/S2-T4 misattribution fix; no scope or decision change.
- `sprints/S2_identity_least_privilege/sprint_plan.md` — Tasks 0–3 done; Task 4 PR A shipped,
  awaiting merge.
- [PR #114](https://github.com/glunk-works/bedrock-serverless-rag/pull/114) — Task 4 PR A, open.
