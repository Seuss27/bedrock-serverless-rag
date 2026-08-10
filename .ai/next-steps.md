# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`implementing` — `S2` (Identity, state reconciliation, and `bootstrap/` retirement).**
Task 1 merged. **Task 2 is complete on both halves**: the `bootstrap/` grant merged as
PR #106 and was human-applied 2026-08-10; the encryption block is shipped as **PR #109**,
open, awaiting review and merge.

## Just done

**S2 Task 2's encryption half**, 2026-08-10, as **PR #109**
(`sprint/s2-t2-state-encryption`, commit `5d808ec`):

- `environments/ai-lab/encryption.tf` (new) — `aws_kms` key provider against the upstream
  org state key, `aes_gcm` method, **`enforced = true`**. **No `fallback`**: the state
  object was an empty 373-byte skeleton tracking **zero** resources (verified before
  deleting) and was deleted, so the first apply writes ciphertext from scratch (BR-D20).
- `deploy.yml` — `TF_VAR_state_kms_key_arn` from `secrets.STATE_KMS_KEY_ARN` on all three
  credentialed jobs; also adds the `Clean up plan files` step `destroy-ai-lab` lacked.
- **A blocker was reported and withdrawn the same day.** I measured that
  `tofu init -backend=false` needed AWS credentials and concluded `ci.yml`'s uncredentialed
  `tofu-validate` required check would break. Confounded by an already-initialized local
  `.terraform` — and **CLAUDE.md's claim that `-reconfigure` fixes that is false**, which is
  corrected in PR #109. Re-measured clean: `-backend=false` never evaluates the encryption
  block. **Do not re-derive this locally without moving `.terraform` aside first.**
- **Critic gate: 3 rounds, converged at the cap** (`docs-consistency` + `security-critic`).
  14 findings, 12 fixed, 1 deferred, 1 cleared. `enforced = true` came from that pass.

## Next

**PR #109 needs review and merge:** https://github.com/glunk-works/bedrock-serverless-rag/pull/109

**Then two human actions, and the second is easy to get backwards:**

1. Merge the PR.
2. **APPROVE** the resulting `tofu-apply`. Every recent push-to-`main` apply was correctly
   **declined** because it predated the encryption block — **this one is the opposite.**
   It is one of only two rebuilds S2 accepts, and it writes the first encrypted state.
3. Verify Task 2's acceptance criterion: the state object must **not parse as JSON**. That
   is the only check that distinguishes native encryption from SSE.

**Then S2 Task 3** (`sprint_plan.md` lines 507–555): repoint `environments/ai-lab/backend.tf`
at the org bucket, `key = "bedrock-serverless-rag/terraform.tfstate"` — the prefix **must**
equal the `var.projects` map key byte for byte, or the role's `s3:prefix` condition denies
access and the failure reads as a credentials error, not a naming one — then
`tofu init -migrate-state` by hand under admin SSO. **Task 3 needs no `bootstrap/` apply of
its own:** its read-only bridge policy is already live, having ridden Task 2's.

**Model: `sonnet` / coder.**

## Open gates and blockers

**HITL Gate: OPEN.** PR #109 needs human review + merge, then the **approve** (not decline)
of its `tofu-apply`, then the not-JSON verification. Task 3's migration is a separate manual
admin-SSO operation, never a CI action.

**Not filed, deliberately** (`security-critic` #1, LOW): no required check can *see* the
encryption block, so deleting `encryption.tf` or its `enforced = true` line passes all six
checks green and the next apply writes plaintext. `enforced` closes the realistic accident
but is not self-defending. Sketched fix and the reasons for deferring are in
`.ai/state.json`'s `known_followups`.

## Pointers

- `docs/hardening_roadmap.md` — reference of record and threat model. Unchanged this session.
- `sprints/S2_identity_least_privilege/sprint_plan.md` — Task 1 (done, 360–394); **Task 2
  (395–506)**, carrying a dated banner with the measured `-backend=false` matrix; **Task 3
  (507–555)**, next up.
