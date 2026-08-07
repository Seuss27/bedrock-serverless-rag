# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`implementing` — `MW` ("make it work"): the first successful `destroy → apply → verify` cycle.**

Read the banner under the sprint plan's title before any task body. **The task numbers
moved:** what the roadmap and older docs call `MW-T0/T1/T2/T3` are now Tasks **5/6/4/3**.
Tasks 1–5 are **done**. **Task 6 — the sprint's last task — is next.**

## Just done

- **Task 5 (F55, F39) closed 2026-08-07.** Orphan `personal-bedrock-kb-execution-role`
  re-confirmed and deleted; `environments/ai-lab` applied from scratch under admin SSO (all
  12 resources now exist in AWS and are tracked in state); verb list harvested from CloudTrail
  against that real apply, not copied from any prior document; `state_access_policy` widened
  in PR #51, which merged and was human-applied the same day (`bootstrap/` apply: `0 added,
  1 changed, 0 destroyed`). Two rounds of `/critic-gate` (`security-critic`,
  `docs-consistency`) ran against the widen and both found real defects that were fixed before
  merge — a wildcard-mapping error that would have left F55's own named `s3:*EncryptionConfiguration`
  gap open, and an unscoped `budgets:*` grant that would have exposed this repo's one PII
  secret to a `pull_request`-triggered credential. Full account in
  `sprints/MW_make_it_work/sprint_plan.md` § *Update, same day: Task 5 done*.
- **F39 is half-closed, not fully** — `environments/ai-lab`'s state now matches AWS (Task 5's
  half), but the finding's own criterion also needs `MW`-T6's CI-driven `No changes.` with a
  run link. Don't read F39 as closed.
- Task 1 (`#37`) closed 2026-08-07 — restore-test of the `bootstrap/` state backup, entirely
  outside any session tool call (BR-D4). Unchanged from before, not repeated here.

## Next

**MW Task 6 (F51, F39): prove the cycle under the CI role — the sprint's Definition of Done.**

1. **Fix the resource-name hazard** (opportunistic, cheap now): `opensearch.tf` writes
   `collection/bedrock-rag-store` as a literal inside both AOSS security policies while the
   collection resource declares the same name separately — CLAUDE.md's own documented hazard.
2. **`destroy → apply` under the CI role, in CI**, followed by an end-to-end
   `RetrieveAndGenerate` query. A passing plan does not close this — the round trip does.
3. **Harvest Task 6's own verb list from CloudTrail** when the destroy runs. Task 5's harvest
   covered the create path only; do not assume `state_access_policy` is sufficient for
   destroy. In particular `s3:DeleteObject`/`s3:ListBucket` are still scoped to the state
   bucket only — given `force_destroy = true` on the source bucket, widen them scoped to that
   bucket specifically, not to the flat `Resource = "*"` style the rest of the statement uses.

**Blocked until a human decides:** `deploy-ai-lab.yml` has no `TF_VAR_data_plane_principal_arns`
wired at all, so a CI plan currently fails "No value for required variable" before reaching
apply. Wiring it needs a human decision on which ARNs and how they're sourced into a GitHub
Actions variable (BR-D4 — don't fetch/print the value in-session). Ask before wiring it.

## Open gates and blockers

**HITL Gate: OPEN.**
- The `data_plane_principal_arns` CI-wiring gap blocks Task 6 and needs a human decision
  first — see above.
- Task 6's CI-triggered destroy/apply is the first-ever real CI apply in this project's
  history; a human should watch it run rather than have it fire unattended.
- `glunk-works/global-bootstrap#7` (org-wide lock-table question) still awaits a response —
  informational, not blocking.

**Known follow-up, not blocking:** `sprints/S1`, `S3`, `S4` (and `S2`'s own risk section)
still restate F39's old pre-`MW`-T5 "split-brain" premise in their own text. None of those
sprints have started; correct opportunistically if touching those files.

## Pointers

- `sprints/MW_make_it_work/sprint_plan.md` — the active sprint. Read the banner, then Task 6's
  full step list and Definition of Done before executing it.
- `docs/hardening_roadmap.md` — reference of record and threat model. F55 closed; F39 half
  closed; F5/F46 confirmed under a human principal only, not yet under CI.
- An org-owned repo presents `repo:<owner>@<org_id>/<repo>@<repo_id>:<context>`; a plain
  `repo:<owner>/<repo>:*` glob does not match it — see `bootstrap/oidc-setup.tf`'s comment
  block. Binds S2-T0/S2-T2, not Task 6.
