# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`implementing` — `S2` (Identity, state reconciliation, and `bootstrap/` retirement).**
Task 1 is merged. Task 2's code is shipped as **PR #106**, open, awaiting human review,
merge, and a `bootstrap/` hand apply.

## Just done

Implemented and shipped **S2 Task 2**'s `bootstrap/` policy edit, 2026-08-10, as
**PR #106** (`sprint/s2-t2-kms-bridge-grant`, commit `759aa37`):

- Added `bootstrap/state-migration.tf`: two new variables (`state_kms_key_arn`,
  `org_state_bucket_name` — both restricted-not-secret BR-D4, no committed default,
  `TF_VAR_`-sourced, mirroring `global-bootstrap`'s own no-default pattern for identical
  cross-repo values) and two new `aws_iam_role_policy` resources on the **local**
  `github-actions-deploy-role`:
  - `state_kms_access_policy` — `kms:Decrypt`/`GenerateDataKey`/`DescribeKey` on the
    upstream BR-D22 state-encryption key, mirroring Task 0c's identical statement already
    live on both upstream roles.
  - `state_migration_bridge` — Task 3's read-only org-bucket bridge (prefix-scoped
    `s3:ListBucket`/`s3:GetObject`, condition copied verbatim from upstream
    `pipeline_state_policy`), applied here so both grants ride the same `bootstrap/` apply.
- Validated: `tofu fmt`/`validate` clean (`bootstrap`, `-backend=false`).
- Ran `security-critic` (`review.ci_gate` is `null` — the only critic look this diff got).
  Fixed 2 of 4 findings: `state_kms_key_arn` had no wildcard-rejection validation despite
  rendering the **entire** IAM `Resource` string (added the guard + an ARN-prefix check);
  the bridge policy's comment misattributed which existing statement actually bounds S3
  enumeration exposure (corrected). Recorded 2 as an in-file residual for **Task 4** rather
  than an unverified fix: pairing this KMS grant with the local role's pre-existing,
  already-accepted-temporary flat S3 `"*"` grant composes into a theoretical cross-project
  state-decrypt path; and this grant sits on a role whose OIDC trust still admits
  `:pull_request` (F2, open) for the Task 2 → Task 4 window.
- Shipped as PR #106, labeled `chore` / `area/bootstrap` / `status/needs-human`.

## Next

**PR #106 needs human review and merge:** https://github.com/glunk-works/bedrock-serverless-rag/pull/106

**Then a human must apply `bootstrap/` by hand under admin SSO** — it is never applied by
CI — with `TF_VAR_state_kms_key_arn` and `TF_VAR_org_state_bucket_name` set (values from
`glunk-works/global-bootstrap`'s `state_kms_key_arn` / `state_bucket_name` outputs).

**Only once that apply is confirmed live**, add the `terraform { encryption { ... } }`
block (`aws_kms` key provider, pointed at the upstream key) to
`environments/ai-lab/providers.tf`. Do not add that block or merge it before the apply
lands: `tofu init` needs `kms:Decrypt` to plan once the block exists, and nothing grants
it until the `bootstrap/` apply runs.

**Model: `sonnet` / coder** (unchanged from this session).

## Open gates and blockers

**HITL Gate: OPEN.** PR #106 needs human review + merge, then a human must apply
`bootstrap/` by hand under admin SSO before the encryption block can be added to
`environments/ai-lab` — do not add that block or merge it before the apply is confirmed
live.

**Not filed this session**, worth a tracked issue before Task 4 executes: the two
security-critic residuals recorded in `bootstrap/state-migration.tf`'s header comment
(cross-project state-decrypt composition risk from the local role's pre-existing flat S3
grant plus this new KMS grant; the F2 `pull_request`-trust exposure window on that same
role for the Task 2 → Task 4 interval).

## Pointers

- `docs/hardening_roadmap.md` — reference of record and threat model. Unchanged this
  session.
- `sprints/S2_identity_least_privilege/sprint_plan.md` — Task 1 (done, lines ~360–391);
  Task 2 (code shipped as PR #106, lines ~395–429); the `bootstrap/` half of Task 3's
  read-only bridge (spec at lines ~433–479) rides the same apply, applied here per Task 2's
  own instruction.
