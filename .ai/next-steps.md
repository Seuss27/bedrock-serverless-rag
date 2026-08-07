# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`implementing` — `MW` ("make it work"): the first successful `destroy → apply → verify` cycle.**

Read the banner under the sprint plan's title before any task body. **The task numbers
moved:** what the roadmap and older docs call `MW-T0/T1/T2/T3` are now Tasks **5/6/4/3**.
Tasks 2, 3, 4 are **done**; Task 1 is next (human-only).

## Just done

- **Task 4 (F5)** landed in PR **#45**, merged at **`7bfa742`**: removed
  `data.aws_arn.current_identity` from the AOSS data-access policy, replaced it with an
  explicit, regex-validated `data_plane_principal_arns` variable. `/critic-gate` ran
  (`security-critic` + `architect`); fixed an empty-list validation gap and a possible
  duplicate-principal entry before merge. **CI wiring of the new variable was deliberately
  deferred** (operator choice) and is still open — see "Open gates" below.
- **Incident, found and closed this session — twice, same root cause.** No `-input=false`
  meant a missing required variable made `tofu plan` block on stdin instead of erroring, which
  hangs a GitHub-hosted runner indefinitely and holds the state lock the whole time. (1) PR
  #45's own `pull_request` check hung 70+ minutes on the DynamoDB lock. (2) PR #47's
  `pull_request` check hung too — its branch was cut *before* the fix merged, so it never
  inherited it — this time on the new native-S3 lock file. Both cancelled, both locks cleared
  by hand (`tofu force-unlock`, confirmed in each case). **PR #46** (`-input=false`) closes the
  mechanism; every branch cut after it is safe.
- **Bigger discovery, also this session:** while preparing this handoff, `tofu state list`
  against the real backend showed real tracked resources — not the "everything empty" the
  roadmap's last measurement recorded. The push-triggered CI run for PR #43 (`ccc76e6`,
  ~15:04 UTC) had reached the apply step for the first time ever and **partially succeeded**:
  AOSS collection + its 2 security policies + the S3 source bucket got created; the KB IAM
  role hit `EntityAlreadyExists` (F55, reconfirmed live) and blocked everything downstream.
  **Task 3's fail-fast fix was live-confirmed working correctly** — one clean attempt, no
  leaked exception text. Per BR-D20 this was **destroyed, not fixed forward** — the operator
  ran `tofu destroy` under admin credentials; verified after: state is empty again, orphan
  role unchanged (path `/`, zero policies). Full writeup in `sprint_plan.md`'s "Update, later
  the same day" subsection under *Measured live state* — read it before trusting any AWS-state
  claim written before this session.
- **DynamoDB-locking migration — done, not just proposed.** Operator decision reversing part
  of BR-D22's 2026-08-05 amendment: `bedrock-lab-state-locks` had exactly one consumer (this
  repo) and retired under BR-D17 regardless, so the original amendment's coordination argument
  never applied to it — only to the org's separate, shared `global-tofu-lock` table. **PR #47**
  (`environments/ai-lab` → native S3 `use_lockfile`) and **PR #48** (`bootstrap/` drops
  `aws_dynamodb_table.tofu_locks` + its IAM grants) are **both merged and applied**. Verified
  end to end: a real CI run against merged `main` succeeded past locking entirely (its only
  remaining failure is the already-known `data_plane_principal_arns` gap below), and
  `aws dynamodb describe-table --table-name bedrock-lab-state-locks` returns
  `ResourceNotFoundException` — the table is gone. The org-wide question on `global-tofu-lock`
  is raised separately, not decided by this repo alone: **`glunk-works/global-bootstrap#7`**,
  still awaiting a response.
- `docs/hardening_roadmap.md`: **BR-D22 re-amended**, **F8** and **F12** corrected to match.

## Next

**MW Task 1: restore-test the `bootstrap/` state backup (`#37`). Human-only** (BR-D4: the
backup's location is deliberately unrecorded) — no coder action to take.

- At `/resume`, confirm whether Task 1 has completed. If so, **Task 5** is next: delete the
  orphan IAM role (`personal-bedrock-kb-execution-role`) under a **fresh** measurement, then a
  human `bootstrap/` apply widening `state_access_policy` from a CloudTrail-derived verb list
  (**not** copied from any prior document — see "Regenerate Task 5's verb list" below).
- The `data_plane_principal_arns` CI-wiring gap is **still open and still deliberately
  deferred** — don't wire it unprompted, ask first. It blocks Task 6's proof run regardless of
  Task 1/5's progress.

## Open gates and blockers

**HITL Gate: NONE OPEN for coding** — the DynamoDB-locking migration is fully merged, applied,
and verified; only this cursor-sync PR itself needs an ordinary merge. **The real gates ahead:**

- **Task 1 (`#37`) is human-only** — the backup's location is deliberately unrecorded (BR-D4) —
  and blocks every part of Task 5.
- **The `bootstrap/` apply in Task 5** is human-only (BR-D1) regardless of the DynamoDB work.
- **The `data_plane_principal_arns` CI-wiring gap** is open and deliberately deferred — ask
  before wiring it.
- **`glunk-works/global-bootstrap#7`** (the org-wide locking question) awaits a response from
  whoever owns that repo's roadmap — informational, not blocking this repo's work.

## Pointers

- `sprints/MW_make_it_work/sprint_plan.md` — **the active sprint.** Banner first, then the
  "Update, later the same day" subsection under *Measured live state* for this session's
  partial-apply-and-destroy incident.
- `docs/hardening_roadmap.md` — reference of record **and** threat model. BR-D22, F8, F12
  all touched this session.
- **Regenerate Task 5's verb list from CloudTrail on the real apply** — not from F55, and not
  from the sprint plan's own table. This session's live `budgets:ModifyBudget` failure is one
  data point toward that list, not a substitute for regenerating it. Note also: `dynamodb:*`
  verbs are no longer needed on `state_access_policy` at all now — don't re-add them.
- **The trap that outlives ST:** an org-owned repo presents
  `repo:<owner>@<org_id>/<repo>@<repo_id>:<context>`; a plain glob does **not** match it. The
  comment block in `bootstrap/oidc-setup.tf` is the best writeup of it.
