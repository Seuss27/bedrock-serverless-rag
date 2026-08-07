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
- **Incident, found and closed this session:** the `pull_request` CI run for PR #45 hung at
  `tofu plan` for 70+ minutes (OpenTofu blocking on stdin for the missing variable — no
  `-input=false`), holding the DynamoDB state lock and failing the next push. The stuck run
  was cancelled, the resulting stale lock force-unlocked by hand (confirmed cleared). **PR
  #46** adds `-input=false` so this can't recur.
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
- **Operator decision: dropping this repo's own DynamoDB lock table**, reversing part of
  BR-D22's 2026-08-05 amendment. `bedrock-lab-state-locks` has exactly one consumer (this
  repo) and retires under BR-D17 regardless, so the original amendment's coordination
  argument doesn't apply to it — only to the org's separate, shared `global-tofu-lock` table.
  **PR #47** cuts `environments/ai-lab` over to native S3 `use_lockfile` (live-verified
  against real AWS: init+plan succeeded, no locking error, no leftover lock-file object).
  **PR #48** removes the table from `bootstrap/`, HCL-only, gated on #47 being confirmed live
  from CI before a human applies it. The org-wide question is raised separately, not decided
  by this repo alone: **`glunk-works/global-bootstrap#7`**.
- `docs/hardening_roadmap.md`: **BR-D22 re-amended**, **F8** and **F12** corrected to match.

## Next

**No coder-executable action is unattended-safe right now.** Everything meaningful is gated
on a human decision — see "Open gates" below. At the next `/resume`:

1. Check whether PRs **#46**, **#47**, **#48** have merged.
2. If #47 is merged, confirm via a **real CI run** (not just this session's local
   verification) that `use_lockfile` works from CI before recommending #48's apply.
3. The `data_plane_principal_arns` CI-wiring gap (`deploy-ai-lab.yml` never sets
   `TF_VAR_data_plane_principal_arns`) is still open and still deliberately deferred — don't
   wire it unprompted, ask first.
4. If none of the above changed, the real next MW task is **Task 1** (`#37` restore-test,
   human-only), which unblocks Task 5.

## Open gates and blockers

**HITL Gate: OPEN — several, none silently resolvable:**

- **PRs #46 and #47** are independent, ordinary human review/merge.
- **PR #48 must not be applied** until #47 is merged **and** confirmed live from a real CI
  run — applying it first removes locking with nothing yet proven to replace it where CI
  actually needs it.
- **Task 1 (#37) is human-only** — the backup's location is deliberately unrecorded (BR-D4) —
  and blocks every part of Task 5.
- **The `bootstrap/` apply in Task 5** is human-only (BR-D1) regardless of #48.
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
  data point toward that list, not a substitute for regenerating it.
- **The trap that outlives ST:** an org-owned repo presents
  `repo:<owner>@<org_id>/<repo>@<repo_id>:<context>`; a plain glob does **not** match it. The
  comment block in `bootstrap/oidc-setup.tf` is the best writeup of it.
