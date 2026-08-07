# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`implementing` — `MW` ("make it work"): the first successful `destroy → apply → verify` cycle.**

Read the banner under the sprint plan's title before any task body. **The task numbers
moved:** what the roadmap and older docs call `MW-T0/T1/T2/T3` are now Tasks **5/6/4/3**.
Tasks 2, 3, 4 are **done**. Task 1 is **done** (`#37` closed 2026-08-07). **Task 5 is next.**

## Just done

- **Task 1 (`#37`) closed.** Restore-test of the `bootstrap/` state backup performed and
  recorded 2026-08-07, entirely outside any session tool call (BR-D4 — the backup's location
  and contents never entered a transcript). Result, recorded as a comment on the issue: the
  scratch-path copy parsed as valid JSON tfstate; `tofu state list` (resource addresses only,
  no ARN/account id) confirmed `aws_iam_openid_connect_provider.github_actions` present; the
  backup's timestamp predates PR #48 (it still lists `aws_dynamodb_table.tofu_locks`, which no
  longer exists live), consistent with it being the copy re-taken immediately before ST-T3's
  narrow rather than the older ST-T0 copy; the scratch copy was deleted after verification.
  **Task 5's own PR must still quote this result** — the sprint plan's acceptance criteria
  treat the issue comment as necessary, not sufficient.
- Prior session's work (Task 4 / PR #45, the CI-hang fixes / PR #46, the DynamoDB-locking
  migration / PRs #47–48) is unchanged and already on `main` — see git log and
  `sprint_plan.md`'s "Update, later the same day" subsection, not repeated here.

## Next

**MW Task 5 (F55, F39): establish identity sufficiency, and delete the orphan.** Human-only
through the CloudTrail harvest:

1. Under AWS admin SSO, **re-confirm under a fresh measurement** (don't trust any prior
   document) that `personal-bedrock-kb-execution-role` still has path `/` and zero attached
   policies, then **delete it**.
2. **`tofu apply` `bootstrap/` from scratch** under those same credentials (BR-D1).
3. **Harvest the verb list from CloudTrail** for that apply window — not from F55's text, not
   from the sprint plan's own regenerated-list table (see "Pointers" below).
4. Hand the verb list to the coder, who drafts the **`state_access_policy` widen PR**: one PR,
   quoting Task 1's restore-test result, stating the OIDC provider was untouched, and recording
   the grant as temporary with its removal written into `S2-T2` step 3 **in the same PR**.

## Open gates and blockers

**HITL Gate: OPEN.** Task 5 steps 1–2 need a human operator with AWS admin SSO credentials
(BR-D1) — `/resume` must not auto-start them. Once the human has applied and harvested the
verb list, the coder's drafting step (step 4) has no further gate of its own.

- **`data_plane_principal_arns` CI-wiring gap** — still open, still deliberately deferred; ask
  before wiring it. Blocks Task 6 regardless of Task 5's progress.
- **`glunk-works/global-bootstrap#7`** (org-wide lock-table question) — awaits a response;
  informational, not blocking this repo's work.

## Pointers

- `sprints/MW_make_it_work/sprint_plan.md` — the active sprint. Read the banner, then Task 5's
  full step list before executing it.
- `docs/hardening_roadmap.md` — reference of record and threat model.
- **Regenerate Task 5's verb list from CloudTrail on the real apply** — not from F55, not from
  the sprint plan's own table. `dynamodb:*` verbs are no longer needed on `state_access_policy`
  at all — don't re-add them.
- An org-owned repo presents `repo:<owner>@<org_id>/<repo>@<repo_id>:<context>`; a plain
  `repo:<owner>/<repo>:*` glob does not match it — see `bootstrap/oidc-setup.tf`'s comment
  block. Binds S2-T0/S2-T2, not Task 5.
