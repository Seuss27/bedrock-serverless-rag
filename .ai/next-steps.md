# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`awaiting_review` — `S2` (Identity, state reconciliation, and `bootstrap/` retirement).**
Task 0c's PR is open upstream, awaiting human review and apply.

## Just done

Executed **S2 Task 0c** end-to-end, 2026-08-10 — entirely against
`glunk-works/global-bootstrap`; this repo's own working tree is unchanged (zero diff from
`main`):

- Read `ST` Task 2b's normative spec in full before writing anything (a superseded body sits
  directly below it in the same file).
- Re-derived every `Resource` in the new workload/plan/boundary policies from what
  `modules/aws-bedrock-rag/` actually declares — verified against the live OpenSearch
  Serverless and Bedrock service authorization references for which actions genuinely have no
  resource-level permission support in AWS's own implementation, rather than assumed.
- Added: the `bedrock-serverless-rag` entry to `var.projects` (ID-qualified
  `oidc_subject_prefix`, `plan_role`, both `extra_*_oidc_subjects`); the BR-D22
  state-encryption KMS key; a permissions-boundary policy document; the CI apply role's
  workload policy (Task 2b's 4 escalation fixes applied, allowlist-clean); a `for_each`'d
  plan-role read-only mirror (F56 gap b); a standalone findings `Deny` covering `s3:` **and**
  `kms:` (F58 gap b), attached to both roles and replicated inside the boundary.
- Validated locally (`tofu fmt`, `tofu validate` from a clean copy, a real `tofu plan` under
  admin SSO with a placeholder for the new BR-D4-restricted bucket-name variable — the real
  source bucket doesn't currently exist in AWS to look up). Confirmed via a baseline plan on
  unmodified `main` that this diff's marginal effect is **13 to add / 0 to change / 0 to
  destroy**, distinct from unrelated pre-existing drift already in `global-bootstrap`.
- Opened **`glunk-works/global-bootstrap#11`**, then ran an independent
  `way-of-working:security-critic` pass against it before leaving it for human apply. Verdict:
  no new path to account-admin. Fixed the 4 most actionable of its 11 findings in a follow-up
  commit (bucket-name variable validation, a corrected BR-D22 mechanism comment, a narrowed
  boundary-self-protection Deny, dropped an encrypt-side KMS verb from the read-only plan
  role); recorded 3 more as residuals in code comments; posted the full review as a PR
  comment.

## Next

**Wait for a human to review and apply `global-bootstrap#11`** (Task 0c's "human apply
upstream, 2 of 3"). Once applied, verify live AWS matches (role exists, boundary policy
exists, both roles carry the workload/plan and findings-deny attachments — quote resource
names only, never ARNs/account id, BR-D4).

**Then begin `S2` Task 1** (`sprints/S2_identity_least_privilege/sprint_plan.md` lines
~360–390): thread `permissions_boundary` onto every `aws_iam_role` in
`modules/aws-bedrock-rag/` (the boundary ARN PR #11 creates; `path` is already set), and add
`ArnLike aws:SourceArn` to `bedrock_kb_role`'s trust policy alongside its existing
`aws:SourceAccount` condition. **Run with the lab torn down** — attaching a boundary to an
*existing* role needs `iam:PutRolePermissionsBoundary`, which nothing grants yet.

**Model: `sonnet` / coder.**

## Open gates and blockers

**HITL Gate: OPEN.** `global-bootstrap#11` needs human review and apply before `S2` Task 1
can begin — Task 1's own acceptance criteria (no cycle error, path+boundary on every role)
can't be checked against a boundary policy that doesn't exist in AWS yet.

**Not filed this session**, flagged by the security-critic pass, left for a human call: the
DynamoDB lock table's `pipeline_state_policy` (`global-bootstrap/main.tf`) grants
`PutItem`/`DeleteItem` with no `dynamodb:LeadingKeys` condition — pre-existing, shared by
every project, not introduced by this PR, possibly worth an issue alongside `#6`.

**Issue #100** (`BR-D22` cites an upstream key-provider issue that was never filed) — the key
itself now exists (created this session), so this may be moot or may still need filing/closing
for the record; not resolved either way this session.

## Pointers

- `docs/hardening_roadmap.md` — reference of record and threat model. Unchanged this session.
- `sprints/S2_identity_least_privilege/sprint_plan.md` — Task 0c (done, lines ~288–355); Task 1
  (next, lines ~360–390).
- **Credential-helper gotcha**: any freshly-cloned sibling repo may 403 on push as the wrong
  GitHub identity — see `git config credential.https://github.com.helper`;
  `bedrock-serverless-rag`, `global-bootstrap`, and `bounty-infra` all already have the fix.
- **`-backend=false` on an already-initialized dir**: even `-reconfigure` can still fail if
  `.terraform/terraform.tfstate` names a real S3 backend (hit this in `global-bootstrap` this
  session). Validate from a clean copy of the `.tf` files instead of fighting `-reconfigure`.
