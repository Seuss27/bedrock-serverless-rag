# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`awaiting_review` — `S2` (Identity, state reconciliation, and `bootstrap/` retirement).**
Tasks **0 (0a/0b/0c), 1, 2, 3 are done, applied, and verified.** **Task 4 PR A —
[PR #114](https://github.com/glunk-works/bedrock-serverless-rag/pull/114) — has every required
check green** and is ready for human review and merge.

## Just done — PR A implemented, critic-gate converged, three live CI bugs found and fixed

- **Task 4 PR A implemented and critic-gate ran to convergence** (4 rounds, 2 past the normal
  cap with explicit human sign-off) — see the previous cursor entry / PR #114's description for
  the full findings list. `deploy.yml`'s stale `||` fallback, stale "zero credentialed
  `pull_request` jobs" claims in `CLAUDE.md`/the roadmap, an unbounded credential-exfiltration
  window in `plan.yml`, and a repeated `S2-T2`/`S2-T4` sprint-numbering error across five
  sibling copies — all fixed.
- **Then CI failed three times, each a genuine live bug the local green gate could not catch:**
  1. `plan.yml`'s new `tofu init -lockfile=readonly` failed on the `ubuntu-latest` runner —
     `environments/ai-lab/.terraform.lock.hcl` only recorded a **Windows** provider hash.
     Fixed: `tofu providers lock -platform=linux_amd64 -platform=windows_amd64`, committed.
  2. The repointed `secrets.AWS_OIDC_ROLE_ARN` failed `modules/aws-bedrock-rag/variables.tf`'s
     `data_plane_principal_arns` validation. Traced with two rounds of a **temporary,
     BR-D4-safe diagnostic step** (PASS/FAIL only, then a 16-byte hex dump) added to `plan.yml`,
     run in CI, then removed once confirmed. Root cause: **PowerShell piping a string to a
     native executable's stdin (`$val | gh secret set ...`) silently prepends a UTF-8 BOM that
     `.Trim()` does not strip.** Fixed by using `gh secret set --body $val` instead of a pipe.
     ⚠️ **BR-D4 near-miss, named rather than glossed over:** the hex-dump diagnostic printed the
     first 3 digits of the AWS account id into a public CI log on one run. The step and that
     code no longer exist, but the historical log line for that specific run is not
     retroactively scrubbable.
  3. One CI run's `zizmor` job hit a **GitHub platform-side reporting glitch** — every step
     completed successfully but the job-level status never finalized, staying `pending`
     against an already-`completed` parent run. Not a repo defect; resolved with `gh run
     rerun`, not more waiting.
- **All required checks green on PR #114**: `pr-title`, `tofu-fmt`, `tofu-validate`, `tflint`,
  `secrets-scan`, `zizmor`, `tofu-plan`. Only `checkov` (non-required, pre-existing expected
  findings) is red — `mergeStateStatus: UNSTABLE` for that reason alone; `mergeable: true`.

## Next

1. **Human: review and merge [PR #114](https://github.com/glunk-works/bedrock-serverless-rag/pull/114).**
2. **Then drive Task 4 step 3's verify cycle** (full spec:
   `grep -n '^### Task 4' -A 200 sprints/S2_identity_least_privilege/sprint_plan.md`):
   1. The merge's own `tofu-plan-main` → `tofu-apply` should plan `12 to add`; after the
      human clicks the `production` Environment approval, it should succeed — **exercises the
      create verbs under the new apply role.** Capture the run link.
   2. Dispatch `destroy-ai-lab` (typed confirm phrase, human watches live per BR-D25) —
      **exercises the destroy verbs under the new apply role.** Capture that run link too.
   3. Record both run links per Task 4's acceptance criteria.
3. **Then PR B** (Task 4 step 4: delete `bootstrap/`'s escalation-capable role +
   `state_access_policy` — human apply) and **PR C** (step 5: require `tofu-plan` as the
   seventh check).

**Separately, outside S2:** the user wants `SD` (the devcontainer sprint) corrected and
started. Its "deferred, Docker unavailable" banner is **stale** — Docker has always been
available on this workstation. **Correct `sprints/SD_devcontainer/sprint_plan.md`'s banner in
its own small PR** before resuming SD's tasks; don't fold that correction into S2 work.
Devcontainer adoption is now wanted as standard practice going forward, not a one-off.

**Model: `sonnet` / coder** for both threads — the S2 design is settled, and the SD banner
correction is mechanical.

## Open gates and blockers

**HITL Gate: OPEN.** PR #114 must be reviewed and merged by a human before Task 4 step 3's
verify cycle begins — merging is not an agent action in this repo. The cycle itself carries
two more human-gated steps already built into the pipeline (the Environment approval, the
destroy confirm phrase). Do not begin step 3 unattended.

**Not filed, deliberately** (`security-critic` #1, LOW, carried from Task 2): no required
check can *see* `encryption.tf`'s `enforced = true`, so deleting it passes all six checks
green. Details in `.ai/state.json`'s `known_followups`.

**New process notes, worth carrying forward:**
- The action classifier blocks some agent-run commands in this repo/session (`gh secret set`
  observed) — secret rotation needs the human to run handed-over commands directly.
- **PowerShell + piping a value to a native exe's stdin can silently inject a UTF-8 BOM** that
  `.Trim()` won't remove. Use `--body`/equivalent argument-passing for exact-match values
  (secrets, tokens) instead of piping.
- `tofu init -lockfile=readonly` needs the committed lockfile to carry hashes for **every**
  platform CI runs on, not just the authoring workstation's.

## Pointers

- `docs/hardening_roadmap.md` — reference of record and threat model. Touched this session
  only for the S2-T2/S2-T4 misattribution fix; no scope or decision change.
- `sprints/S2_identity_least_privilege/sprint_plan.md` — Tasks 0–3 done; Task 4 PR A green,
  awaiting merge.
- `sprints/SD_devcontainer/sprint_plan.md` — needs its stale deferred-banner corrected.
- [PR #114](https://github.com/glunk-works/bedrock-serverless-rag/pull/114) — Task 4 PR A,
  all required checks green.
