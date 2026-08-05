# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`blocked` — the plan review is DONE. PR #18 is still unmerged, and three operator
decisions block the amendment pass.**

The cold-context adversarial review ran and returned **SEND BACK** — unanimously, from three
independent critics. The plan is not merged and must not be merged until amended.

## What the review found

Three critics (architect, security-critic, docs-consistency) plus a provider-surface
verification pass. **Six defects were found independently by two critics** — the four rounds
of surgical edits showing up exactly where the authoring session predicted.

- **7 draft security advisories** filed on this repo (5 high, 2 medium) — `[H1]`–`[H5]`,
  `[M1]`, `[M2]`. **Private to repo admins; deliberately NOT on the PR.** This repo is
  public, `main` has no branch protection, and several are working attack paths against the
  shared AWS account — posting them would be the BR-D4 violation the plan itself forbids.
  Convention matches `glunk-works/bounty-infra`'s advisory register.
- **The rest posted as a review comment on #18** — docs/consistency defects, the AWS
  provider surface, structural findings, proportionality, severity recalibration. Posted as
  `COMMENTED`, never an approval.
- One throwaway advisory titled `test` exists in `closed` state (API has no DELETE) — remove
  via the UI if you want the register clean.

**The three blockers a Sonnet coder would hit hardest:** `S3-T2`'s acceptance criterion
reverses its own body on `force_destroy` (ships `default = false`, re-wedging `tofu
destroy`); five surviving "reconcile by import" instructions against BR-D19's reversal,
including in `CLAUDE.md` and this file; and `S0`'s token prerequisite names
`admin:repo_hooks`, which is the *webhooks* scope — a literal coder stops at instruction one.

**Verified dead:** `aws_opensearchserverless_account_settings` does not exist under any
spelling (provider issue #41245, open since Feb 2025). **Verified dangerous:**
`aws_bedrock_model_invocation_logging_configuration` is a per-region singleton — S4-T2 would
take over Bedrock logging for the whole shared org account.

## Next — three operator decisions, then ONE amendment pass

⚠️ **Order matters. Decisions first, or the edits get done twice.** Much of the amendment
list is cross-reference repair; deciding afterwards to cut sprints would mean having
carefully fixed references into deleted sprints.

1. **Proportionality** — the review argues for **~5 sprints instead of 9**, blast-radius work
   untouched. Take it, take part, or reject. Highest-leverage call; everything else is
   downstream.
2. **Severity recalibration** — F45 → Critical, F13 → High, and whether to add a `Blocker`
   severity for functional defects (F51). Mechanical once decided.
3. **BR-D22** — decided 2026-08-05 but **not yet written into any file**: S3 state locking
   moves to `use_lockfile` (OpenTofu ≥ 1.10; `required_version` is `>= 1.8.0` today and
   `bootstrap/` declares none), and state confidentiality comes from **OpenTofu native
   client-side encryption**, not SSE. Owner: `glunk-works/global-bootstrap`, per BR-D17.
   This is the control that makes the BR-D21 secrets pilot honest — see advisory `[M2]` §2.

**Then one amendment pass, in two commits** (different kinds of work):

- **Design amendments — Opus/architect.** `[H1]`–`[H5]`, `[M1]`. These change what ST-T2 and
  S2 actually *do*: re-scoped IAM verbs, a new module task for `path`/`permissions_boundary`,
  a reordered S2.
- **Mechanical fixes — Sonnet/coder.** ~30 items: the arithmetic (`4+17+19+15 = 55`, not 54;
  real count is 4/16/20/14), the four stale ID ranges (`.ai/project.yml:42` first — it is the
  `decisions.log` schema key), the "import" purge, cross-refs, stale citations. Good fit for
  the `coder` subagent against a written list.

**Amend #18 in place — do not merge-then-fix.** It is unmerged precisely so this can happen;
merging a plan with three known blockers makes them the reference of record.

## Sprint order (unchanged pending decision 1)

`S0` → `ST` → `S1` → `S2` → `S3` → `S4` → `S5` → `S6`, with `SD` in parallel after S0 —
**though the review argues SD is not actually parallel** (three of its five tasks read values
out of files S1 creates) and should be cut or made optional.

**ST's internal order includes Task 0** — the blocking drift gate this file previously
dropped: `T0` (commit the `ListAttachedRolePolicies` drift) → `T1` (**already DONE**, PR #17)
→ `T2` → `T3` → `T4` → `T5`.

**S0's internal order is not its numbering:** T4 → T5 → T3 → T2 → T1 → T6. `required_
approving_review_count` must stay 0 while this is a solo-owner repo — but the review notes
that stops being true the moment ST transfers it, and ST-T4 is where to revisit.

## Still-open operator gates (a coder cannot do these)

- `tofu apply` in `bootstrap/` — human, admin SSO, never CI (BR-D1). ST and S2 both need it.
  **Back the state file up out-of-band first** — see advisory `[H4]`.
- A `tofu apply` of `glunk-works/global-bootstrap` — ST-T2, S2-T3.
- The repository transfer itself — org-owner permission, irreversible in practice (ST-T3).
- Creating the `production` Environment with a required reviewer (S1-T5).
- Docker on the workstation, without which SD can only be written, not verified.

## Pointers

- `docs/hardening_roadmap.md` — reference of record **and** threat model: F1–F54,
  BR-D1–BR-D21, § 5 sprint sequence, § 6 the required-check ordering rule, § 7 nomenclature,
  § 9 the `global-bootstrap` coupling, § 9.5 the secrets pilot, § 10 the status log.
- `sprints/S0_governance_baseline/sprint_plan.md` — the sprint to execute after the merge.
- `sprints/ST_org_transfer/sprint_plan.md` — the ordering constraint that matters most.
- **PR #18** — the plan, unmerged, with the review comment on it.
- **This repo's security advisories** — the 7 private findings. Not reachable from the PR.
- `.ai/project.yml` — this repo's parameterization; two `null`s are decisions, not gaps.
