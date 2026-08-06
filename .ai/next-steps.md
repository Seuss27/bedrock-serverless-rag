# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`review` — the amendment pass is COMPLETE. Both commits are pushed. PR #18 is still `OPEN`
and unmerged, awaiting your review.**

The cold-context review returned **SEND BACK**. Every blocker it named is fixed, the three
operator decisions are recorded as **BR-D22/23/24**, and the cross-reference repair ran *after*
the reshape so it did not have to be done twice. **The merge is yours** — nothing here merged
anything.

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

## Next — the amendment pass is COMPLETE. PR #18 is ready for your review.

Both commits are on `chore/adopt-way-of-working` and pushed. **Nothing is merged** — #18 is
still `OPEN`, and the merge is yours.

**What the mechanical pass fixed**, against the review comment on #18
(`gh pr view 18 --comments`):

- **All five "reconcile by import" survivals** — `CLAUDE.md`, the roadmap's ordering hazards,
  § 9.3, this file, and S3's dependency block. BR-D19 was reversed by BR-D20; reconciliation is
  teardown-and-rebuild, and it happens in `MW`.
- **Every stale ID range** — `CLAUDE.md` (×3), `.ai/project.yml`'s `decisions.log` key, this
  file. Ground truth is **F1–F58** and **BR-D1–BR-D24**, verified by counting.
- **The three blockers a coder would have hit hardest.** S3-T2's `force_destroy` acceptance
  criterion said `default = false` and reversed its own body — it would have re-wedged
  `tofu destroy`, which is the exact cycle F51 exists to fix. S0's token prerequisite named
  `admin:repo_hooks`, the *webhooks* scope, and would have halted the sprint at instruction one.
  ST-T1's body told a coder to re-implement work merged in PR #17 — now `DONE, VERIFY ONLY`.
- **The gitleaks deadlock** (S1-T3/T7): the licence exemption was true when written and false by
  the time S1 runs, because ST transfers the repo first. Left unfixed it makes a required,
  unbypassable `secrets-scan` fail on a licence error and **every PR unmergeable**. Two
  sanctioned resolutions are now written into the task, plus the BR-D21 consequence — this
  becomes the repo's first genuine secret.
- **S6-T4's retained transfer checklist — deleted, not annotated.** S6 runs long after ST, so a
  coder following it would attempt the transfer a second time.
- Stale `file:line` citations (**re-verified against the live files, not copied from the
  review**), dangling `§ 8` / `S2-T2` / `S31` cross-references, the orphaned `Closes:` lines,
  and the `gh label edit` / `gh issue list --state all` command forms.

**The two agent-governing files are now done too** (`[M2]` §§ 3 and 7), in their own commit —
they change what an agent may *do*, not what a document says, which is why they were not bundled
into a docs commit.

- **`.claude/settings.json`** now denies the destructive `tofu state` subcommands (`rm`, `mv`,
  `push`, `replace-provider`), `tofu import`, `tofu init -migrate-state`, and `gh api` DELETE in
  both spellings — each for **both** the `Bash` and `PowerShell` tools. **`PowerShell(...)` was
  verified as a real tool name**, not a placebo, so the pre-existing entries do bind.
  **Deliberately not denied:** `tofu state list`/`show` (read-only, wanted for `MW`'s inventory)
  and `gh api` PUT/PATCH (S0-T2 and ST-T4 need them, and a deny is a hard block).
  **⚠️ Known partial coverage:** the patterns are prefix matches, so
  `tofu init -backend-config=… -migrate-state` is **not** caught — blanket-denying `tofu init`
  was rejected because `tofu init -backend=false` is the green gate.
- **`.gitignore`** — **F54 is CLOSED early**, plus `tfplan`, `plan.json` and `.venv/`. Verified
  with `git check-ignore` **once per path**: that command exits 0 if *any* argument is ignored,
  so the multi-path form could not have proven what it claimed.

**`CLAUDE.md`'s Actions rules are now complete** (`[M2]` § 4) — the last outstanding review
item. The load-bearing addition: *a `pull_request`-triggered job runs the workflow file **from
the PR branch***, which is what makes **F3** arbitrary code execution with
account-admin-capable credentials rather than a least-privilege smell. F3 is sharpened to say so
(severity unchanged — it was already right). Also banned `workflow_run` and `issue_comment`
alongside `pull_request_target`; covered `actions/github-script`'s `script:` block; and noted
that `${{ }}` in an `if:` is injectable when the expression embeds attacker-controlled text.
**S1-T6's acceptance grep was exploitable as written and now carries a second check** — a
`github-script` payload sits under `with:` → `script:`, so the original criterion *passed* a
step containing `${{ github.event.pull_request.body }}`.

**Every item from the review is now closed.** The one thing carried forward as a task rather
than a fix: S1-T3 must confirm whether `zizmor` catches the `github-script` case **against a
deliberately-planted test case**, and record which control is the real one — the grep or the
scanner. It is not assumed.

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
