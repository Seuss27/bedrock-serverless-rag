# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`implementing` — `S2` (Identity, state reconciliation, and `bootstrap/` retirement).**
Tasks 1 and 2 are **done and verified live**. **Task 3 is next**, and it opens with a human
admin-SSO step, not a code edit.

## Just done

**S2 Task 2 complete on both halves and verified**, 2026-08-10:

- `bootstrap/` KMS grant + org-bucket bridge — PR #106, merged and human-applied.
- Native state encryption — PR #109, merged as `51ef17b`; CI run `31443695508` green
  (`tofu-plan-main` + `tofu-apply`).
- **Acceptance criterion PASSED, with stronger evidence than it asked for.** The state
  object (21,360 B) contains `"encrypted_data"` and `"encryption_version"` and does **not**
  contain `"resources"`, `"outputs"` or `"terraform_version"`; `serial`/`lineage`/`meta`
  stay clear by design. `tofu state list` reads all **12** resources back through the KMS
  key, so `enforced = true` locks nobody out.
  ⚠️ **Refine the criterion before re-running it after Task 3's migration.** *"Does not parse
  as JSON"* is imprecise — the encrypted envelope **is** `{`-prefixed and JSON-shaped, so a
  bare `jq empty` can pass or fail for the wrong reason. The decisive test is the key
  presence/absence above. Worth folding into `sprint_plan.md`.
- **A blocker was reported and withdrawn the same day.** `tofu init -backend=false` does
  **not** evaluate an encryption block; the confound was an already-initialized local
  `.terraform`, whose documented `-reconfigure` remedy does not work. Both corrected in #109.
  **Do not re-derive this locally without moving `.terraform` aside first.**
- Critic gate: **3 rounds, converged at the cap** (`docs-consistency` + `security-critic`).
  `enforced = true` came out of that pass.

## Next

**S2 Task 3** — bridge, then migrate. Re-derive its line range with
`grep -n '^### Task' sprints/S2_identity_least_privilege/sprint_plan.md` rather than
trusting a number written here.

⚠️ **Ordering hazard — the human step comes FIRST.** Repointing `backend.tf` and merging it
would leave CI initialising against a bucket the state is not in yet. The migration is a
**human, local, admin-SSO** operation (`tofu init -migrate-state`), done *before* the change
merges. The `key` prefix must equal the `var.projects` map key **byte for byte**, or the
role's `s3:prefix` condition denies access and the failure reads as a credentials error
rather than a naming one.

**Task 3 needs no `bootstrap/` apply** — its read-only bridge policy is already live, having
ridden Task 2's. And its `No changes.` criterion is meaningful only because **the lab is UP**
(12 resources); against an empty state it would pass vacuously.

**Model: `sonnet` / coder** for the code half; the migration itself is a human action.

## Open gates and blockers

**HITL Gate: OPEN.** Task 3 begins with the manual admin-SSO state migration above. Do not
start the `backend.tf` edit unattended — doing the code first inverts the safe order.

**Not filed, deliberately** (`security-critic` #1, LOW): no required check can *see* the
encryption block, so deleting `encryption.tf` or its `enforced = true` line passes all six
checks green and the next apply writes plaintext. `enforced` closes the realistic accident
but is not self-defending. Sketched fix and deferral reasons are in `.ai/state.json`'s
`known_followups`.

## Pointers

- `docs/hardening_roadmap.md` — reference of record and threat model. Unchanged this session.
- `sprints/S2_identity_least_privilege/sprint_plan.md` — Task 2 carries a dated banner with
  the measured `-backend=false` matrix; Task 3 is next.
