# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`implementing` — `S1b` (the pipeline rewrite).** `T2`, `T1` done. Three tasks left:
`T3 → T6 → T7`.

## Just done

**`S1b`-T1 shipped as PR #78 (`928a088`).** Every `uses:` in `ci.yml`/`deploy.yml` pinned
from a mutable tag to a commit SHA (`owner/repo@<40-char-sha> # <tag>`).

- Four pins reused as-is from `glunk-works/bounty-infra` (`actions/checkout`,
  `actions/setup-python`, `opentofu/setup-opentofu`, `terraform-linters/setup-tflint`);
  `aws-actions/configure-aws-credentials` resolved fresh via `gh api` (dereferenced the
  annotated `v6` tag to its commit).
- Added `persist-credentials: false` to `destroy-ai-lab`'s checkout — the one T2 left
  unpinned since that job had to carry byte-identical, and the most destructive job in the
  repo (it was writing `GITHUB_TOKEN` to `.git/config` while holding the admin-capable OIDC
  credential during a destroy apply).
- `/critic-gate` ran `security-critic` (chosen over `architect`/both — diff was narrow and
  mechanical). It independently re-resolved all five SHAs against upstream (no drift),
  confirmed 7/7 checkouts carry `persist-credentials: false`, and confirmed no collateral
  change to `destroy-ai-lab`'s `if:`. One finding, fixed: the `configure-aws-credentials`
  comment named the mutable `v6` tag instead of the immutable release it resolves to —
  corrected to `# v6.2.3` to match the other four pins' precision.
- Local green gate and `zizmor` both clean (no `unpinned-uses`, no `artipacked`; one
  pre-existing, unrelated `excessive-permissions` finding on `deploy.yml`'s workflow-level
  `id-token: write`, out of scope for `T1`).

## Next

**`S1b`-T3 — full-coverage IaC and workflow scanning.**

- Add three scanner jobs to `ci.yml`: `checkov` (`directory: .`, `framework: terraform`,
  `soft_fail: false`, covering `bootstrap/` + `modules/` + `environments/` — the coverage
  gap is the finding, F19), `secrets-scan` (`gitleaks/gitleaks-action`, `fetch-depth: 0`, a
  committed `.gitleaks.toml`, `secrets.GITLEAKS_LICENSE` — already inherited org-wide from
  `glunk-works`, no new secret needed), `zizmor` (`zizmorcore/zizmor-action`, job-scoped
  `permissions: {contents: read, security-events: write}`, not hoisted to workflow level).
- Pin all three new actions' `uses:` lines to a commit SHA, same `T1` pattern.
- Do **not** add `iac-diff-guard` (cut by BR-D23, already covered by the PR template's
  `Blast radius` section). Do **not** make `checkov` required (`S3`'s job).

**Model: `sonnet` / coder.**

## Open gates and blockers

**HITL Gate: NONE OPEN for `T3`.** Nothing blocks starting it unattended.

`glunk-works/global-bootstrap#7` (org-wide lock-table question) still awaits a response —
informational, not blocking.

**Worth noting, not yet acting on:** a pre-existing `zizmor` `excessive-permissions` finding
on `deploy.yml`'s workflow-level `id-token: write` (surfaced during `T1`'s session, not
introduced by it). It's a structural property of `T2`'s job design, not something `T3`'s
scanner-job addition touches — don't fold a fix for it into `T3` without a deliberate scope
decision.

## Pointers

- `docs/hardening_roadmap.md` — reference of record and threat model.
- `sprints/S1_pipeline_hardening/sprint_plan.md` — **top banner first.** Task 3's body has
  the full scanner-job spec and the `GITLEAKS_LICENSE` deadlock analysis (already resolved).
