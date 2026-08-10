# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`implementing` — `S2` (Identity, state reconciliation, and `bootstrap/` retirement).**
Tasks 0a and 0b are merged, applied, and verified. Task 0c is next.

## Just done

Resolved the prior session's three-item HITL gate, then executed **S2 Tasks 0a and 0b**
end-to-end against `glunk-works/global-bootstrap`, 2026-08-10:

- **Task 0a** (`global-bootstrap#8`, merged) — added `oidc_subject_prefix` and
  `extra_plan_oidc_subjects` to `var.projects`, threaded `locals.subject_prefix` through
  both roles, kept `StringLike` untouched. Proved `tofu plan` → `No changes.`
- **Task 0b** (`global-bootstrap#9`, merged **and applied**) — `StringLike` → `StringEquals`
  on the apply role (`F2`), consumed `extra_plan_oidc_subjects` on the plan role (`F56` gap
  a). Static pre-apply verification (no wildcards, subject arrays byte-identical) recorded
  in the PR body.
- **Active post-apply verification found the sprint plan's own assumption didn't fit two of
  the three siblings**: `tri-loop-dev`'s OIDC role has **never once** successfully
  authenticated in its entire 11-run history, superseded by `glunk-works/loop-orchestrator`
  — filed **`global-bootstrap#10`** recommending removal. `resume-optimizer` is alive but has
  no AWS/OIDC step in its CI at all — nothing to verify, not dead. Only `bounty-infra` had a
  live signal: a throwaway no-op PR (#91) confirmed `tofu-plan` still passes post-apply, then
  closed without merging.
- Also filed **`bedrock-serverless-rag#101`** — `BR-D21`'s "exactly one secret" claim is wrong
  (`BUDGET_NOTIFICATION_EMAIL` matches an address already public in this repo's commit
  history).
- Fixed a stale-credential 403 in `global-bootstrap`'s and `bounty-infra`'s local clones —
  see Pointers below.

## Next

**Execute `S2` Task 0c** — re-add `bedrock-serverless-rag`'s own upstream entry in
`global-bootstrap`'s `var.projects`, per `ST` Task 2b's **normative** spec. Four parts: the
subject/plan-role entry (+ the upstream KMS state-encryption key, confirmed design call), the
workload + permissions-boundary policy in `project_policies.tf` (**re-derive every
`Resource`** — do not copy `MW`'s flat `Resource = "*"` harvest), a `for_each`'d plan-role
read policy (`F56` gap b), and a standalone findings `Deny` covering `s3:` **and** `kms:`
(`F58` gap b). Full detail in `.ai/state.json`'s `next_action`. **Open the PR; do not apply**
— human apply upstream (2 of 3).

**Model: `sonnet` / coder.**

## Open gates and blockers

**HITL Gate: NONE OPEN.** Next gate expected at Task 0c's human apply upstream (2 of 3).

**`F61`** was deliberately **not** taken into S2 (deferred to `S3+S4`).

**Issue #100** (`BR-D22` cites an upstream key-provider issue that was never filed) is still
open — Task 0c's KMS key now depends on this being resolved before Task 2.

## Pointers

- `docs/hardening_roadmap.md` — reference of record and threat model. Unchanged this session.
- `sprints/S2_identity_least_privilege/sprint_plan.md` — Task 0c is lines ~288–355. Read
  `sprints/ST_org_transfer/sprint_plan.md` Task 2b (normative) first — a **superseded** body
  sits directly below it in the same file; do not implement that one.
- **Credential-helper gotcha**: any freshly-cloned sibling repo (`global-bootstrap`,
  `bounty-infra`, or a new one) may 403 on push as the wrong GitHub identity —
  `git`'s `github.com` credential helper defaults to Windows Credential Manager, which
  caches whichever account last authenticated there, independent of `gh auth status`. Fix:
  add a local `credential.https://github.com.helper` override to `!gh auth git-credential`
  (empty-string reset entry first, then the real one) — `bedrock-serverless-rag` already has
  it; `global-bootstrap` and `bounty-infra` got it this session.
