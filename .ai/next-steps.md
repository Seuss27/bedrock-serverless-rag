# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`implementing` — `S1b` (the pipeline rewrite).** `T2`, `T1` done. `T3` shipped as an open
PR, awaiting merge. Two tasks left after it: `T6 → T7`.

## Just done

**`S1b`-T3 shipped as PR #80** (branch `ci/s1b-t3-scanner-jobs`), open and mergeable, not yet
merged.

- Added `checkov` (`directory: .` — closes **F19**'s coverage gap, now scans `bootstrap/` +
  `modules/` + `environments/` instead of `modules/` only), `secrets-scan` (gitleaks, new
  `.gitleaks.toml`), and `zizmor` to `ci.yml`, all SHA-pinned per `T1`'s convention.
- `/critic-gate` ran **both** `security-critic` and `architect` on the diff before commit.
  Both independently found the same fork-PR deadlock: `secrets-scan` and `zizmor` would both
  be red on a fork PR once `T7` makes them required. Recorded as **F59** and **F60**
  (roadmap totals **58 → 60**) and routed to `S1b`-T7 rather than fixed here.
- One fork-PR gap **was** fixed rather than merely recorded: `zizmor`'s default SARIF upload
  also failed on forks (needs `security-events: write`, which a fork token never gets) —
  closed with `advanced-security: false` / `annotations: true` instead (GitHub-native inline
  annotations, same on forks and same-repo PRs, no elevated permission needed).
- Also fixed: a wrong in-file comment (zizmor fails on **any** finding, not just
  High-confidence), and a `CLAUDE.md` parenthetical this same diff made stale (claimed
  `ci.yml` reads `GITHUB_TOKEN` for one step and nothing else — now two steps, plus the new
  `GITLEAKS_LICENSE` secret).
- **Live CI on PR #80 confirmed every prediction.** `secrets-scan` and every pre-existing
  check pass. `checkov` fails exactly on **S3**'s already-tracked findings (13 failures, all
  mapping to F7/F8/F9 — nothing new). `zizmor` fails exactly on **F60**'s two findings
  (`deploy.yml:27` excessive-permissions, plus a previously-unknown `dependabot-cooldown` on
  `.github/dependabot.yml:3`, folded into F60), and its SARIF-upload step correctly shows
  `outcome=skipped`, confirming the `advanced-security: false` fix works. Only `pr-title`
  (the sole currently-required check) needs to pass for mergeability, and it does.

## Next

**Merge PR #80.** Then **`S1b`-T6 — purge every raw-output path.**

- Sweep `ci.yml` and `deploy.yml` for BR-D4 violations: no `set -x`, no `env` dump, no
  `aws sts get-caller-identity` echo, no `tofu output` without `-json | jq`, no `tofu show`
  of state.
- Add `set -euo pipefail` to the top of every multi-line `run:` block.
- Confirm no `${{ }}` appears inside any `run:` block **or** any `actions/github-script`
  `script:` block anywhere in the repo — the basic grep alone passes an exploitable payload
  sitting under `with:` → `script:`; Task 6's acceptance criteria has the second explicit
  check.

**Model: `sonnet` / coder.**

## Open gates and blockers

**HITL Gate: OPEN — PR #80 awaiting human merge.** Do not auto-start `T6` before it lands;
`T6` edits the same two workflow files `T3` just changed.

**Separately, not blocking `T6`:** `S1b`-T7 cannot require `secrets-scan` or `zizmor` as
currently planned without resolving or knowingly accepting **F59** (secrets-scan can never
pass on a fork PR — not fixable from this repo) and **F60** (zizmor is red today on
`deploy.yml`'s `id-token: write` plus a `dependabot-cooldown` warning). `T7`'s task body in
`sprint_plan.md` carries the blocking note and the options.

`glunk-works/global-bootstrap#7` (org-wide lock-table question) still awaits a response —
informational, not blocking.

## Pointers

- `docs/hardening_roadmap.md` — reference of record and threat model. F59/F60 added in
  § 3.2 Pipeline.
- `sprints/S1_pipeline_hardening/sprint_plan.md` — **top banner first.** Task 7's body now
  carries a blocking note about F59/F60.
