# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`implementing` — the three operator decisions are ANSWERED and the design amendments are
committed. PR #18 is still unmerged. One commit of mechanical doc fixes remains.**

The cold-context review returned **SEND BACK**. The blockers it named are fixed; what is left
is cross-reference repair, which was deliberately sequenced *after* the reshape so it is not
done twice.

## What landed in the design commit

- **BR-D23 — the proportionality reshape.** New **`MW` ("make it work")** sprint immediately
  after ST, carrying the teardown-and-rebuild (ex-S2-T1), the AOSS data-plane fix (ex-S2-T6)
  and the retry fix (ex-S4-T4). S0 gains the Infisical deletion and the budget. S3+S4 merge and
  lose ~half their tasks. S5 → four items. S6 → two runbooks. **SD deferred** on a stated Docker
  precondition. Every cut is in roadmap **§ 5.1** with the premise that would bring it back.
- **BR-D24 — one severity rule, no `Blocker` tier.** F45 → Critical, F47 → Critical, F13 → High.
  **Five Criticals: F1, F17, F41, F45, F47.** Totals recounted from the tables:
  **5 · 18 · 21 · 14 = 58**.
- **BR-D22 — native client-side state encryption**, folded into S2-T4. **`use_lockfile` is NOT
  adopted; the DynamoDB lock table stays** (the org's `global-tofu-lock` is shared with three
  sibling pipelines).
- **Four new findings, F55–F58** (§ 3.1d), all properties of live code. Defects that lived only
  *in the plan* were fixed by amending sprint plans and deliberately not recorded as findings.
- **The advisory amendments:** ST gains **T2a** (module `path`/`permissions_boundary`), **T2b**
  (the boundary construction, corrected — the original was escapable three ways while claiming
  to be "structurally impossible"), and **T2c** (prove the deploy identity can rebuild). ST-T0
  gains a blocking out-of-band state-backup criterion. ST-T3's narrow becomes blocking, with the
  username-reclamation reason stated.

## Next — ONE commit of mechanical fixes, Sonnet/coder

Against a written list, from the review comment on PR #18 (`gh pr view 18 --comments`):

- **The stale ID ranges** — four files give four answers. `.ai/project.yml:42` first (it is the
  `decisions.log` schema key). Ranges are now **F1–F58** and **BR-D1–BR-D24**.
- **The five surviving "reconcile by import" instructions** against BR-D19's reversal, including
  in `CLAUDE.md`. *(The roadmap's own copy in § 5's ordering hazards is already fixed.)*
- **The orphaned `Closes:` lines**, the dangling section references (S6-T5 cites "§ 8", which
  does not exist), and the stale `file:line` citations after PR #17.
- **S0's token prerequisite names `admin:repo_hooks`** — that is the *webhooks* scope. A literal
  coder stops at instruction one.
- **`[M2]` items 3 and 7 — two direct file edits, not doc fixes.** `.claude/settings.json`'s deny
  list fails open on `tofu state`/`import`/`init -migrate-state` and on `gh api -X DELETE`;
  **verify the `PowerShell(...)` entries are a real tool name or delete them — a placebo control
  is worse than a known gap.** *(The `Invoke-Tofu.ps1` gap in that item is **already closed** —
  the wrapper was deleted 2026-08-05, which removes the subprocess surface rather than adding a
  deny rule for it. Do not add `Bash(*Invoke-Tofu*)`; there is nothing to deny.)*
  `.gitignore` needs F54's one-liner plus `tfplan`, `plan.json`, `.venv/`.
- **`CLAUDE.md`'s Actions rules are missing four** (`[M2]` § 4), and one of them is what makes F3
  a code-execution bug rather than a least-privilege smell: *a `pull_request`-triggered job runs
  the workflow file from the PR branch.* Also: `workflow_run` and `issue_comment` are unbanned,
  and `actions/github-script`'s `script:` block is `run:`-equivalent for injection but is not
  covered by the current wording — **S1-T6's acceptance grep would pass it.**

**Amend #18 in place — do not merge-then-fix.**

## Sprint order (BR-D23)

`S0` → `ST` → **`MW`** → `S1` → `S2` → `S3+S4` → `S5` → `S6`. **`SD` is deferred**, not parallel.

- **ST's internal order is not its numbering:** `T0` → ~~`T1`~~ (**already DONE**, PR #17) →
  `T2a` → `T2b` → `T2` → `T3` → `T4` → `T5`, with `T2c` gating **`MW`**.
- **S0's internal order is not its numbering:** T4 → T5 → T3 → T2 → T1 → T6, plus the two new
  tasks. `required_approving_review_count` stays 0 while this is a solo-owner repo — which stops
  being true the moment ST transfers it; ST-T4 is where to revisit.
- **⚠️ The most expensive available mistake** is `MW`'s teardown before **F55** is closed: the
  rebuild needs verbs the current policy does not grant, they have never been exercised, and by
  then the working-but-orphaned system is gone. Sufficiency is a precondition, never a discovery.

## Still-open operator gates (a coder cannot do these)

- `tofu apply` in `bootstrap/` — human, admin SSO, never CI (BR-D1). **ST needs three** (T0, and
  T3 twice). **Back the state file up out-of-band first** — now ST-T0's second acceptance
  criterion, not a suggestion.
- A `tofu apply` of `glunk-works/global-bootstrap` — ST-T2, S2-T3.
- The repository transfer itself — org-owner permission, irreversible in practice (ST-T3).
- Creating the `production` Environment with a required reviewer (S1-T5).
- ~~Docker on the workstation~~ — no longer blocking anything; SD is deferred.

## Pointers

- `docs/hardening_roadmap.md` — reference of record **and** threat model: F1–F58,
  BR-D1–BR-D24, § 3 the severity rule, § 5 the sprint sequence, **§ 5.1 what BR-D23 cut and
  why**, § 6 the required-check ordering rule, § 9.4 the upstream issue list, § 9.5 the secrets
  pilot, § 10 the status log.
- `sprints/MW_make_it_work/sprint_plan.md` — the new sprint, and the one with the blocking gate.
- `sprints/ST_org_transfer/sprint_plan.md` — the ordering constraint that matters most.
- **PR #18** — the plan, unmerged, with the review comment on it.
- **This repo's security advisories** — the 7 private findings, and the only place the exploit
  chains are written down. Not reachable from the PR.
- `.ai/project.yml` — this repo's parameterization; two `null`s are decisions, not gaps.
