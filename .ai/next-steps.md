# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`implementing` — `S1b` (the pipeline rewrite).** `T2`, `T1`, `T3` done. One task left:
`T6 → T7`.

## Just done

**`S1b`-T3 merged as PR #80** (`578db4e`); its cursor sync merged as PR #81 (`5495bf2`).

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
  check pass. `checkov` failed exactly on **S3**'s already-tracked findings (13 failures, all
  mapping to F7/F8/F9 — nothing new). `zizmor` failed exactly on **F60**'s two findings
  (`deploy.yml:27` excessive-permissions, plus a previously-unknown `dependabot-cooldown` on
  `.github/dependabot.yml:3`, folded into F60), and its SARIF-upload step correctly showed
  `outcome=skipped`, confirming the `advanced-security: false` fix works.

## Next

**`S1b`-T6 — purge every raw-output path.**

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

**HITL Gate: NONE OPEN for T6.** Nothing blocks starting it unattended.

**Separately, not a `T6` blocker:** both merges (#80, #81) each queued `deploy.yml`'s
push-triggered `tofu-plan-main` → `tofu-apply`, per this repo's by-design
every-merge-consumes-an-approval trade (`S1a`-T5). At least one is sitting in the
`production` Environment's `waiting` state as of this cursor. That approval is the human's
to give or decline and is unrelated to `S1b`'s remaining work.

**`S1b`-T7 cannot require `secrets-scan` or `zizmor` as currently planned** without
resolving or knowingly accepting **F59** (secrets-scan can never pass on a fork PR — not
fixable from this repo) and **F60** (zizmor was red on `deploy.yml`'s `id-token: write`
plus a `dependabot-cooldown` warning, both measured live). `T7`'s task body in
`sprint_plan.md` carries the blocking note and the options.

`glunk-works/global-bootstrap#7` (org-wide lock-table question) still awaits a response —
informational, not blocking.

## Pointers

- `docs/hardening_roadmap.md` — reference of record and threat model. F59/F60 added in
  § 3.2 Pipeline.
- `sprints/S1_pipeline_hardening/sprint_plan.md` — **top banner first.** Task 7's body now
  carries a blocking note about F59/F60.
