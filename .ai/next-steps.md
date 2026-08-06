# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`implementing` — `S0` (governance and repository baseline). The hardening plan is
reviewed, amended and MERGED (PR #18, `30fdc14`). Execution starts here.**

## Just done

- **PR #18 merged** — the plan survived a cold-context adversarial review that returned
  **SEND BACK**, plus a five-commit amendment pass. It is now the reference of record.
- **Three operator decisions recorded as BR-D22/23/24** (`d413b37`). **BR-D23** reshaped the
  sprint sequence: new **`MW`** sprint after ST, S0 gains two pulled-forward tasks, S3+S4
  merge, S5 → four items, S6 → two runbooks, **SD deferred** on a Docker precondition.
  **BR-D24** fixed the severity rule (five Criticals: F1, F17, F41, F45, F47). **BR-D22**
  adopted native client-side state encryption — **`use_lockfile` NOT adopted; the org's
  shared DynamoDB lock table stays.**
- **Four findings added, F55–F58**, all properties of live code; totals recounted from the
  tables: **58 findings, 5/18/21/14**.
- **`Invoke-Tofu.ps1` deleted** (`428c941`) — native `tofu` + `TF_VAR_*`/`AWS_PROFILE` only.
- **Cross-reference repair** (`2038334`), **deny list + `.gitignore` hardened, F54 closed
  early** (`f7e4051`), **`CLAUDE.md`'s Actions rules completed and F3 sharpened** (`cd93475`).

## Next

**Execute `S0`** — `sprints/S0_governance_baseline/sprint_plan.md`. **Model: `sonnet`
(coder).** The plan is written and merged; this is implementation, not design.

⚠️ **Three things a literal reading gets wrong:**

1. **The internal order is NOT the numbering: `T4 → T5 → T3 → T2 → T1 → T6`, then the two
   new tasks.** `T1` installs the ruleset and **must come after `T4` creates the `pr-title`
   workflow** — a required check that does not yet exist deadlocks the repo permanently
   (BR-D9). Start at **T4**.
2. **`T1` is the point of no return for push access.** Once it lands, direct pushes to `main`
   stop working **for the owner too** — that is the intent, and every later sprint goes
   through a PR. It changes live GitHub state, is not revertible by `git revert`, and has its
   own stated undo. **Run it with the human present**; everything before it is file work.
   `required_approving_review_count` stays **0** while this is a solo-owner repo — GitHub
   forbids approving your own PR, so anything else deadlocks it.
3. **S0 now creates one AWS resource** (the budget, new `T8`), so the sprint header's "no
   `.tf`, no AWS resource" claim is no longer literally true — say so in the PR body rather
   than letting it quietly rot. `T7` is the Infisical deletion, pulled forward from S3-T8.

**HITL Gate: NONE OPEN.** The next gate is the human's merge of S0's PR, plus being present
for `T1`'s ruleset install.

## Sprint order (BR-D23)

`S0` → `ST` → **`MW`** → `S1` → `S2` → `S3+S4` → `S5` → `S6`. **`SD` is deferred**, not
parallel — its precondition is Docker on the workstation.

⚠️ **The most expensive mistake available in this roadmap** is `MW`'s teardown before **F55**
is closed: the rebuild needs verbs the current deploy policy does not grant, they have never
been exercised (the last run died before AOSS or Bedrock were reached), and by then the
working-but-orphaned system is gone. Sufficiency is a **precondition**, never a discovery.

## Still-open operator gates (a coder cannot do these)

- `tofu apply` in `bootstrap/` — human, admin SSO, never CI (BR-D1). **ST needs three** (T0,
  and T3 twice), and **ST-T0's second acceptance criterion is an out-of-band state backup** —
  blocking, not a suggestion.
- A `tofu apply` of `glunk-works/global-bootstrap` — ST-T2, S2-T3.
- The repository transfer itself — org-owner permission, irreversible in practice (ST-T3).
- Creating the `production` Environment with a required reviewer (S1-T5).

## Pointers

- `docs/hardening_roadmap.md` — reference of record **and** threat model: F1–F58,
  BR-D1–BR-D24, § 3 the severity rule, § 5 the sprint sequence, **§ 5.1 what BR-D23 cut and
  the premise that would bring each cut back**, § 6 the required-check ordering rule, § 9.4
  the upstream issue list, § 9.5 the secrets pilot, § 10 the status log.
- `sprints/S0_governance_baseline/sprint_plan.md` — **the active sprint.**
- `sprints/MW_make_it_work/sprint_plan.md` — the new sprint, and the one with the blocking
  F55 gate.
- **This repo's security advisories** — the 7 private findings, and the only place the
  exploit chains are written down. `gh api repos/<owner>/<repo>/security-advisories`.
- `.ai/project.yml` — this repo's parameterization; its two `null`s are decisions, not gaps.
  **`ruleset` stops being `null` in S0-T1 — update it in the same PR.**
