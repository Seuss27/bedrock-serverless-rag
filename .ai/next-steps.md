# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`implementing` — `S2` (Identity, state reconciliation, and `bootstrap/` retirement).**
Task 1 is merged. Task 2 (native state encryption) is next.

## Just done

Executed **S2 Task 1** end-to-end, 2026-08-10, merged as **`35290c5`** (PR #104):

- Verified `global-bootstrap#11` (Task 0c) was actually **applied** live, not just merged —
  the PR had merged upstream but the human apply hadn't happened yet at `/resume` time;
  caught the gap with a direct AWS check (role, boundary policy, both roles' attachments,
  by name only, BR-D4) rather than trusting the merge.
- Threaded a `permissions_boundary_name` variable through `modules/aws-bedrock-rag/` and
  `environments/ai-lab/`; built the boundary ARN from `data.aws_caller_identity.current`
  (never a literal); attached it to `bedrock_kb_role`; added an `ArnLike aws:SourceArn`
  condition (`knowledge-base/*` pattern, avoiding the KB-resource dependency cycle) alongside
  the role's existing `aws:SourceAccount` check — the F4/#6 confused-deputy fix. Added the
  module's previously-missing `terraform{}` block opportunistically.
- Validated: `tofu fmt`/`validate` clean (both roots), a real `tofu plan` under admin SSO
  showing **12 to add / 0 to change / 0 to destroy**, no cycle error, correct boundary ARN
  rendered (plan output summarized only, BR-D4).
- Ran an independent `architect` + `security-critic` pass before shipping (`review.ci_gate`
  is `null` — this was the only critic look the diff got). Both cleared it for
  correctness/security and converged on the same cheap fixes, applied in the same commit:
  dropped a triple-duplicated variable default, hoisted `/bedrock-rag/` into one `local`,
  reworded a comment that overstated an enforced invariant, deleted a stale comment, and
  re-enabled `tflint`'s `terraform_required_providers` rule (clean repo-wide now).
- Caught and resolved a live operational hazard before merging: two already-merged
  docs-only PRs (#102, #103) had `deploy.yml` runs queued on the production Environment
  approval that would have rebuilt `bedrock_kb_role` from the pre-boundary code if approved
  first. Both were declined (confirmed via job-level check) before PR #104 opened; #104's
  own apply was **also declined** by the human afterward — the lab stays deliberately torn
  down, so this change is live in `main`'s HCL but **not yet live in AWS**.

## Next

**Implement S2 Task 2** (`sprints/S2_identity_least_privilege/sprint_plan.md` lines
~395–429): edit `bootstrap/`'s policy to grant `kms:Decrypt`/`GenerateDataKey`/`DescribeKey`
on the upstream BR-D22 state-encryption key to both this project's roles, plus the read-only
org-bucket bridge policy Task 3 needs (both grants ride one `bootstrap/` apply). Validate
with `tofu fmt`/`validate`.

**Then wait for a human to apply `bootstrap/` by hand under admin SSO** — it is never
applied by CI — before adding the `terraform { encryption { ... } }` block to
`environments/ai-lab/providers.tf`. Do not add that block or merge it before the apply is
confirmed live: `tofu init` needs `kms:Decrypt` to plan once the block exists, and nothing
grants it yet.

**Model: `sonnet` / coder** (unchanged from this session).

## Open gates and blockers

**HITL Gate: NONE OPEN.** Next gate opens once Task 2's code edit is implemented and
validated — a human must then apply `bootstrap/` by hand before the encryption block can be
added.

**Not filed this session**, worth a tracked issue before S2-T2: the boundary's S3/region
grants depend on an upstream variable (`bedrock_rag_source_bucket_name`) typed independently
of this repo's own bucket-name variable, with no automated cross-check — a mismatch would
surface only at Bedrock's first ingestion job, not at plan. Also: the boundary ARN is
constructed via string interpolation rather than looked up via `data "aws_iam_policy"`
(deferred on purpose — today's CI role doesn't grant the reads that lookup needs).

## Pointers

- `docs/hardening_roadmap.md` — reference of record and threat model. Unchanged this session.
- `sprints/S2_identity_least_privilege/sprint_plan.md` — Task 1 (done, lines ~360–391);
  Task 2 (next, lines ~395–429).
