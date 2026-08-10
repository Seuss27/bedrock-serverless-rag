# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`implementing` — `S2` (Identity, state reconciliation, and `bootstrap/` retirement).**
The plan is written, critiqued, fixed and merged (**PR #97**, `079b40d`). Nothing executed yet.

## Just done

`S2` **planned** 2026-08-09/10. Every load-bearing claim was measured against live GitHub,
live AWS and `glunk-works/global-bootstrap` rather than read off prose — which found six
things the plan had wrong, three of them changing the task order:

- **`BR-D27`** — the ID-qualified OIDC subject is a **per-repository** fact, not a
  consequence of org ownership (`bounty-infra` is equally org-owned and presents the plain
  form). `global-bootstrap` could not express this repo's subject **for any project**, so the
  old Task 0 would have minted two roles this repo cannot assume. `BR-D13` and `F44` corrected.
- **Ordering hazard 9** — the upstream and local roles have **disjoint state-bucket access**,
  so identity switchover and backend migration cannot be ordered independently. Resolved with
  a read-only bridge; the old Task 2's own acceptance criterion was unsatisfiable in its slot.
- **Ordering hazard 11** — the old Task 4 migrated *before* encrypting, against a **versioned**
  bucket, leaking plaintext state permanently. Split into Tasks 2 and 3.
- A `docs-consistency` pass then caught **three defects in the plan itself**, two of which
  would have broken `main` on merge — `deploy.yml`'s real `||` fallback, `F56` gap (a) dropped
  while still claimed closed, and a KMS key provider with no key and no grant. All fixed in
  #97's second commit.

Result: **6 tasks (0–5) plus one optional**, 3 upstream applies, 3 local applies, 1 manual
state migration. Full detail in the sprint plan's **fourth banner** and `.ai/state.json`.

## Next

**Execute `S2` Task 0a** — the upstream schema PR against `glunk-works/global-bootstrap`.
Add `oidc_subject_prefix` **and** `extra_plan_oidc_subjects` to `var.projects`, add
`locals.subject_prefix`, thread it through **both** role constructions, and add the
`repo:`-prefix and no-`*`/`?` validations. **Keep `StringLike`; do not consume
`extra_plan_oidc_subjects` yet** — both belong to Task 0b.
**Acceptance: `tofu plan` upstream reports `No changes.`** That clean plan *is* the safety
proof; record it in the PR body as change counts only (BR-D4). **No apply.**

**Model: `sonnet` / coder.**

## Open gates and blockers

**HITL Gate: OPEN — three items, all cheap, none blocking each other.**

1. **Confirm or override a design call** made inside #97's second commit: the state-encryption
   KMS key is created **upstream**, beside the org state bucket (Task 0c step 1b). Follows from
   `BR-D17`; the alternative is fatal, since a key in `environments/ai-lab` would be destroyed
   by `destroy-ai-lab` along with the state it decrypts. May also deserve a line in `BR-D22`.
2. **Verify `R1`** — does `BUDGET_NOTIFICATION_EMAIL` match the personal `@gmail.com` already
   in this public repo's commit history? If yes, the residual is near zero **and `BR-D21`'s
   "exactly one secret" claim is wrong**. Not checkable from the repo; the value is
   shell-supplied.
3. **Task 0a needs a working copy of `glunk-works/global-bootstrap` plus admin SSO** — its
   acceptance criterion is a live `No changes.` plan against that repo.

**`F61`** was deliberately **not** taken into S2 (deferred to `S3+S4`) — recorded in the plan.

**`BR-D22` says the key-provider choice is "filed as an issue" upstream — no such issue is
open.** File it or drop the clause.

## Pointers

- `docs/hardening_roadmap.md` — reference of record and threat model. **New:** `BR-D27`, a
  fourth `BR-D22` amendment, hazards 9/10/11, and an **`S2-T<n>` routing note** — the task ids
  were remapped, and `S2-T1`/`S2-T6` now **collide** with different tasks.
- `sprints/S2_identity_least_privilege/sprint_plan.md` — read the **fourth banner** first: the
  eight facts measured live and the six decisions taken. Carries a **residual register (R1–R7)**.
- `sprints/ST_org_transfer/sprint_plan.md` **Task 2b** — normative for Task 0c's boundary.
