# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`implementing` — `MW` ("make it work"): the first successful `destroy → apply → verify` cycle.**

Tasks 1–5 are **done** (F55 closed). **Task 6 — the sprint's last task — is in progress**,
much closer than at the start of this session but not there yet: CI can now reach a real
plan (two blockers fixed), and a third, newly-measured permissions gap is what's next.

## Just done

- **`TF_VAR_data_plane_principal_arns` wired into `deploy-ai-lab.yml`** (PR #53) — CI's plan
  had never once reached a real plan step before this; it always failed "No value for
  required variable" first.
- **`bedrock:ListTagsForResource` granted** (PR #54, human-applied) — the first real error CI
  hit once unblocked: the AWS provider calls it refreshing the Knowledge Base, and MW-T5's
  harvest never happened to exercise that path.
- **A real BR-D4 disclosure found and fixed** (PR #55) — unblocking the plan step exposed
  that GitHub Actions dumps every `vars.*` value into the auto-generated preamble of *every*
  step in a job, `uses:` steps included, before any script runs — no ordering fix works.
  `AWS_OIDC_ROLE_ARN`, `DATA_SOURCE_BUCKET_NAME`, `SSO_ADMIN_ROLE_ARN` now ride GitHub
  **secrets** instead (the only mechanism proven to mask everywhere), recorded as a BR-D4/BR-D21
  exception in both `CLAUDE.md` and `docs/hardening_roadmap.md` (which outranks it). Took two
  rounds of `/critic-gate`: the first fix attempt (early `::add-mask::` registration) was
  verified, against the real leaked log, to still leak — never made it to `main`. Verified
  live afterward via two CI runs on PR #56: all four restricted values render as `***`
  everywhere now, and `ListTagsForResource` is gone.
- **Leaked run log deleted** (31226198865); the three now-superseded GitHub *variables* of
  the same names deleted after the secrets were confirmed set.

## Next

**Add `s3:ListBucket` to `state_access_policy`** in `bootstrap/state-backend.tf`, flat on the
existing `Resource = "*"` statement (matching `GetBucket*`/`CreateBucket`/`DeleteBucket`'s
style there — this is read-only, not the destructive verb the note below is about).

**Root cause, measured twice, not guessed:** S3's `HeadBucket` API returns `403` for *both*
"no permission" and "bucket doesn't exist" — a deliberate AWS anti-enumeration measure — and
OpenTofu's AWS provider reads that `403` as "no longer exists" during refresh.
`state_access_policy`'s `s3:ListBucket` grant is scoped only to the *state* bucket, not flat
like the rest of the CI role's S3 permissions, so CI's refresh of the source bucket
misreports it as deleted and plans to recreate it (plus a forced replace on its encryption
config, and unrelated in-place updates to the budget and the KB's S3 IAM policy riding along
in the same plan). **Confirmed not a data problem:** a local admin-SSO plan is clean
(`No changes.`); two separate CI runs — before and after correcting the
`DATA_SOURCE_BUCKET_NAME` secret — show the identical drift.

After the `bootstrap/` apply, re-verify with `gh run rerun 31229605693` (or push a fresh
no-op to PR #56's branch, `ci/verify-secrets-and-list-tags-fix`, still open) — the bar is the
plan reaching exactly `No changes.`, not just "no error."

**Then, still Task 6:**
1. Fix the resource-name hazard (opportunistic): `opensearch.tf` writes
   `collection/bedrock-rag-store` as a literal inside both AOSS security policies while the
   collection resource declares the same name separately.
2. `destroy → apply` under the CI role, **in CI**, followed by an end-to-end
   `RetrieveAndGenerate` query. A passing plan does not close this — the round trip does.
3. Harvest Task 6's own verb list from CloudTrail when the destroy runs — Task 5's harvest
   covered the create path only. `s3:DeleteObject` specifically must stay scoped to the
   source bucket (not flattened to `*`) given `force_destroy = true` there — don't conflate
   this with the `s3:ListBucket` fix above, which is a different verb with a different risk
   profile.

## Open gates and blockers

**HITL Gate: OPEN.**
- The `s3:ListBucket` fix above needs a human `bootstrap/` apply under admin SSO — not
  coder-executable. Re-verifying afterward (a CI rerun) has no further gate of its own.
- Task 6's actual destroy step, once the plan is clean, is the first-ever real destroy under
  the CI role — a human should watch it run rather than let it fire unattended.
- `glunk-works/global-bootstrap#7` (org-wide lock-table question) still awaits a response —
  informational, not blocking.

**Known follow-up, not blocking:** `sprints/S1`, `S3`, `S4` (and `S2`'s own risk section)
still restate F39's old pre-`MW`-T5 "split-brain" premise in their own text — correct
opportunistically if touching those files. PR #56 (`ci/verify-secrets-and-list-tags-fix`) is
still open, kept alive deliberately as a place to re-trigger verification runs — merge or
close it once Task 6's plan is confirmed clean, whichever fits.

## Pointers

- `sprints/MW_make_it_work/sprint_plan.md` — the active sprint. Read the banner, then Task 6's
  full step list and Definition of Done before continuing it.
- `docs/hardening_roadmap.md` — reference of record and threat model. F55 closed; F39 half
  closed; F5/F46 confirmed under a human principal only, not yet under CI; BR-D21's tier-2
  rule now carries the GitHub-Actions-secrets exception (see `Local: secrets come from AWS`
  in `CLAUDE.md` for the short version).
- An org-owned repo presents `repo:<owner>@<org_id>/<repo>@<repo_id>:<context>`; a plain
  `repo:<owner>/<repo>:*` glob does not match it — see `bootstrap/oidc-setup.tf`'s comment
  block. Binds S2-T0/S2-T2, not Task 6.
