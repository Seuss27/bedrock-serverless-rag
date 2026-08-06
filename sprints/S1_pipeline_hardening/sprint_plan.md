### FILEPATH: /sprints/S1_pipeline_hardening/sprint_plan.md

# S1 — Pipeline hardening

> **⚠ Reshaped 2026-08-05 by BR-D23 — thinned, and re-sequenced behind `MW`.**
>
> - **`MW` now runs before this sprint.** The original order had S1 building an Environment
>   gate, a saved-plan apply, seven required checks and a plan-summarizer **around an apply that
>   had never once succeeded** — and this sprint's own Risks section conceded it: *"a plan job
>   that goes green here proves the **job** works, not that the plan is accurate."* `MW` fixes
>   that first. Every criterion here that reads plan output is now meaningful.
> - **`iac-diff-guard` is CUT.** The plan itself declares it bypassable and forbids making it
>   required, so its entire value is a comment — bought at a CI minute on every PR, forever.
>   **The requirement moves to the PR template.**
> - **`dependency-audit` must not be added as a required check** when S5 lands (BR-D23). Run it;
>   do not gate on it. A new upstream CVE turning `main` red, on a repo designed to sit
>   destroyed with nobody on call, is the wrong trade.
> - **⚠️ `tofu-plan-main` is blocked on F56 and must not be unblocked the obvious way.** The
>   upstream plan role trusts **only** `repo:<org>/<repo>:pull_request`, so a `push`-triggered
>   job **can never assume it**. ST-T2 step 4 decides between adding an `extra_oidc_subjects`
>   equivalent upstream and dropping `tofu-plan-main` entirely. **Do not point it at
>   `vars.AWS_OIDC_ROLE_ARN`** — that is an apply-capable role on push to `main` with no
>   `environment:` gate, i.e. **F13 restored in the sprint that closes it**.
> - **F13 is now rated High, not Critical** (BR-D24) — on double-counting alone. That is a
>   severity correction, **not** a licence to deprioritise T5.

**Sprint Goal:** Stop `main` from applying to AWS unreviewed, make what applies be what was
planned, and turn the advisory scanners into real gates. At the end of this sprint, an
infrastructure change reaches AWS only after a PR, a plan a human read, and an explicit
Environment approval (BR-D2).

**Closes:** F13 (Critical), F14, F15, F16, F18, F19, F20, F21.

**Dependencies:** **S0 and ST must both be merged.** Without S0's ruleset everything below is
advisory. **ST (the org transfer) must precede this sprint**: repository variables do not
survive a transfer and the owner name is inside every OIDC subject, so running S1 first means
setting `AWS_PLAN_ROLE_ARN`, creating the `production` Environment, and introducing the
`environment:production` subject **twice** - the second time against a half-migrated
identity.

**Security Considerations:** This sprint rewrites the only path this repo has to production
AWS. Two properties must hold at every intermediate commit, not just at the end: **(a)** no
job that runs on a `pull_request` may hold credentials that can mutate AWS, and **(b)** no
step may emit a raw plan, an account id, a role ARN, or the collection endpoint into a
world-readable log (BR-D4). The apply role is not touched here — it is still the
over-privileged single role from F1/F3 until S2. That is why Task 5's Environment gate is
the sprint's centrepiece: it is the only control standing between a merge and an
admin-capable apply until S2 lands.

**Risks & Blockers:**
- **`vars.AWS_PLAN_ROLE_ARN` may not be set yet.** ST-T2 opts this project into
  `plan_role = true` upstream, so the *role* exists once ST is applied — but the repository
  **variable** pointing at it is set in **S2-T2**, which is also where the switch to the
  upstream roles happens. Until then Task 4's plan job uses the
  `vars.AWS_PLAN_ROLE_ARN || vars.AWS_OIDC_ROLE_ARN` fallback with a `# S2-T2: drop the
  fallback` marker. **Do not invent a role ARN**, and do not create a role from this sprint —
  `bootstrap/` is out of scope here (BR-D1).
- The `production` Environment (Task 5) must be created in repo settings **with the owner as
  a required reviewer** before the first merge to `main` after this sprint, or the apply job
  will run without pausing and the sprint's main control is absent while appearing present.
  Confirmed absent as of 2026-08-05: `gh api repos/…/environments` returns `total_count: 0`.
- **Cross-repo dependency — now settled, and already handled upstream.** Adding
  `environment: production` to the apply job changes that job's OIDC subject to
  `repo:…:environment:production` (Environment takes precedence over the branch ref).
  **ST-T2 already added `extra_oidc_subjects = ["environment:production"]` and
  `plan_role = true`** to `global-bootstrap`'s `var.projects` entry for this repo, and a human
  applied it. Verify that before relying on it — if ST-T2 was skipped or reverted, the gated
  apply fails to authenticate at exactly the moment the new control first engages, and the
  fix lives in another repository.
- **The role ARNs this sprint references are still this repo's own**
  (`github-actions-deploy-role`) until **S2-T2** switches them to the upstream roles. Keep the
  `vars.AWS_PLAN_ROLE_ARN || vars.AWS_OIDC_ROLE_ARN` fallback in Task 4 for exactly that
  reason; S2 removes it.
- **`tofu plan` output cannot be trusted as a description of reality until S2-T1.** The state
  CI reads does not contain the deployed resources (**F39** — confirmed: no CI apply has ever
  succeeded). A plan job that goes green here proves the *job* works, not that the plan is
  accurate.
- Making `tofu-plan` a required check means **a fork PR can never go green** (forks get no
  OIDC token). Accepted — the alternative is a credentialed job reachable from fork-authored
  code.

---

## Tasks

- **Task 1: Pin every action to a commit SHA and drop persisted credentials**
  - **Description:** Every `uses:` in this repo currently rides a mutable tag (F15). Replace
    each with `owner/repo@<40-char-sha> # <tag>`. Resolve a SHA with
    `gh api repos/<owner>/<repo>/git/ref/tags/<tag> --jq '.object.sha'` — and if that returns
    an annotated-tag object (`.object.type == "tag"`), dereference it with
    `gh api repos/<owner>/<repo>/git/tags/<sha> --jq '.object.sha'`. **Never** hand-copy a
    SHA from another file without re-resolving it.
    These four are already verified in `glunk-works/bounty-infra` and may be reused as-is:
    ```
    actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1          # v7.0.1
    actions/setup-python@5fda3b95a4ea91299a34e894583c3862153e4b97      # v7.0.0
    opentofu/setup-opentofu@a1320f892987e89d278cc92dc5adc984fb93aca4   # v2.0.2
    terraform-linters/setup-tflint@6e1e0642c0289bd619021bf6b34e3c08ed1e005a # v6.3.0
    gitleaks/gitleaks-action@e0c47f4f8be36e29cdc102c57e68cb5cbf0e8d1e  # v3.0.0
    zizmorcore/zizmor-action@6fc4b006235f201fdab3722e17240ab420d580e5  # v0.6.1
    ```
    Resolve `aws-actions/configure-aws-credentials` and `bridgecrewio/checkov-action`
    yourself with the command above and record the tag you resolved in the trailing comment.
    Add `with: persist-credentials: false` to **every** `actions/checkout` (F21).
  - **Target Files:** every file under `.github/workflows/`
  - **Acceptance Criteria:** `grep -rE 'uses: .*@v[0-9]' .github/workflows/` returns nothing.
    Every `uses:` line matches `@[0-9a-f]{40} #`. Every `actions/checkout` carries
    `persist-credentials: false`. `zizmor .github/workflows/` reports no `unpinned-uses` and
    no `artipacked` finding.

- **Task 2: Split the workflow — `ci.yml` (uncredentialed) and `deploy.yml` (credentialed)**
  - **Description:** Delete `.github/workflows/deploy-ai-lab.yml` and replace it with two
    files. This is the structural change the rest of the sprint depends on: it separates
    checks that need no AWS access at all from the two jobs that do.
    **`ci.yml`** — `on: pull_request:` with **no `paths:` filter** (F18: a required check on
    a path-filtered workflow leaves a docs-only PR pending forever, unmergeable, with no way
    to fix it from inside the PR). Workflow-level `permissions: contents: read`. Job ids
    only, **no `name:` overrides on any job** (F18: the check-run name is the job id;
    renaming silently un-requires the gate). Jobs, all unchained — no `needs:` — so each
    reports its own conclusion as fast as it can:
    - `tofu-fmt` — `tofu fmt -check -recursive` from the repo root.
    - `tofu-validate` — for **each** of `environments/ai-lab` and `bootstrap`:
      `tofu init -backend=false && tofu validate`. Credential-free by construction, so it
      runs on forks. Covering `bootstrap/` here is deliberate: BR-D1 keeps CI from
      *applying* it, not from *checking* it.
    - `tflint` — `tflint --recursive` from the repo root, with a committed `.tflint.hcl`
      enabling the `aws` ruleset.
    **`deploy.yml`** — `on: pull_request:` (plan, Task 4) and `on: push: branches: [main]`
    (plan + apply, Task 5). No `paths:` filter on the `pull_request` trigger, for the same
    reason. `permissions: id-token: write, contents: read` at the workflow level.
    Nothing in either file may use `pull_request_target`.
  - **Target Files:** `.github/workflows/ci.yml`, `.github/workflows/deploy.yml`,
    `.github/workflows/deploy-ai-lab.yml` (deleted), `.tflint.hcl`
  - **Acceptance Criteria:** `deploy-ai-lab.yml` no longer exists. No workflow file contains
    a `paths:` key. No job in `ci.yml` or `deploy.yml` has a `name:` key. Every job id is
    lower-case-hyphenated and unique across both files. `tflint --recursive` exits 0 locally.

- **Task 3: Full-coverage IaC and workflow scanning**
  - **Description:** Add four scanner jobs to `ci.yml`. The coverage gap is the finding
    (F19): Checkov currently scans `modules/` only, so `bootstrap/` — which holds F1 and F2,
    the two worst findings in the repo — has **never been scanned**.
    - `checkov` — `directory: .` (the whole repo, not `modules/`), `framework: terraform`,
      `soft_fail: false`. Suppressions, if any prove necessary, go in a committed
      `.checkov.yml` with a one-line justification per skipped check id; a bare `--skip-check`
      on the command line is not acceptable.
    - `secrets-scan` — `gitleaks/gitleaks-action` with `fetch-depth: 0` (it scans the
      `base^..head` commit range and needs history a shallow clone lacks) and a committed
      `.gitleaks.toml`.
      **⚠️ `GITLEAKS_LICENSE` IS required by the time this sprint runs — the exemption below is
      invalidated by the plan's own sprint order.** It used to read *"not required here — that
      requirement applies to organization-owned repos, and this repo is user-owned."* True
      today; **false when S1 executes**, because the order is S0 → **ST** → `MW` → S1, and
      **ST-T3 transfers this repo to `glunk-works`**. Combined with T7 making `secrets-scan` a
      **required check with `bypass_actors: []`**, the result is: the scan fails on a licence
      error, it is required, nobody can bypass, **every PR in the repo becomes unmergeable**,
      and the fix lives outside the repo entirely. That is the BR-D9 deadlock class arriving by
      a route BR-D9 does not model.
      **Do one of these, and say which in the PR body:** *(a)* reuse the **org-level
      `GITLEAKS_LICENSE` secret `glunk-works` already holds** — preferred; or *(b)* hold
      `secrets-scan` out of the required list until the licence is confirmed present.
      **Second-order, and it needs recording:** this makes `GITLEAKS_LICENSE` **this repo's
      first genuine secret**, and BR-D21's SSM pattern cannot serve a workflow `env:` value
      without an AWS round-trip inside CI. **Record the BR-D21 exception for
      Actions-consumed secrets** — § 9.5 names `GITLEAKS_LICENSE` as one of bounty-infra's
      genuinely-secret values and never noticed this repo was about to acquire one.
      Do not add a
      `pull-requests: write` permission for its comment feature; the action logs a warning
      and continues without it, and the check's verdict comes from the scan.
    - `zizmor` — `zizmorcore/zizmor-action`, job-scoped
      `permissions: {contents: read, security-events: write}`. Do **not** hoist
      `security-events: write` to the workflow level; it is the only job that needs it.
    - `iac-diff-guard` — a plain `run:` step that fails the PR if the diff touches
      `bootstrap/` without the PR body containing the line
      `Blast radius: changes what CI may do in AWS`. `bootstrap/` defines the OIDC trust
      policy and the deploy role's permissions; a change there must be a deliberate,
      declared act. Read the body from `env:`, never inline `${{ }}` into the script.
  - **Target Files:** `.github/workflows/ci.yml`, `.gitleaks.toml`, `.checkov.yml` (only if
    a suppression is genuinely needed)
  - **Acceptance Criteria:** Checkov's log shows it scanned files under `bootstrap/`,
    `modules/` **and** `environments/`. All four jobs report on this sprint's PR. If Checkov
    fails on a real finding, **do not suppress it** — record it as a new `F` row in
    `docs/hardening_roadmap.md` mapped to the sprint that owns it (most will already be
    F6–F12, owned by S3) and add a justified `.checkov.yml` skip citing that row.

- **Task 4: PR plan — read-only, summarized, never dumped**
  - **Description:** In `deploy.yml`, a `tofu-plan` job on `pull_request`:
    1. `actions/checkout` with `persist-credentials: false`
    2. `aws-actions/configure-aws-credentials` with
       `role-to-assume: ${{ vars.AWS_PLAN_ROLE_ARN || vars.AWS_OIDC_ROLE_ARN }}` and a
       comment `# S2-T2: drop the fallback once the upstream plan role is adopted`
    3. `tofu init` (real backend — the plan needs state), then
       `tofu plan -lock=false -input=false -out=tfplan` in `environments/ai-lab`.
       `-lock=false` because a read-only plan must never take the DynamoDB lock and block a
       concurrent apply.
    4. **Summarize, never dump** (F16, BR-D4):
       ```bash
       set -euo pipefail
       tofu show -json tfplan > plan.json
       jq -r '.resource_changes[]
              | select(.change.actions != ["no-op"])
              | "\(.change.actions | join(",")) \(.address)"' plan.json \
         | sort | tee -a "$GITHUB_STEP_SUMMARY"
       jq -r '[.resource_changes[] | select(.change.actions != ["no-op"])] | length
              | "total changes: \(.)"' plan.json >> "$GITHUB_STEP_SUMMARY"
       ```
       Actions and resource **addresses** only. Never `cat plan.json`, never
       `tofu show tfplan` without `-json | jq`, never `tofu plan -no-color` to stdout — the
       human-readable plan renders attribute *values*, which is exactly what BR-D4 forbids
       on a public repo.
    5. Delete `tfplan` and `plan.json` at the end of the job and **upload no artifact**. A
       plan file on a public repo's artifact store is world-readable and contains everything
       the summary was written to omit.
    - `continue-on-error: false`. The job must fail on a plan error — a plan that cannot run
      is not a plan that shows no changes.
  - **Target Files:** `.github/workflows/deploy.yml`
  - **Acceptance Criteria:** On a PR that changes a `.tf` file, the job summary lists
    resource addresses and a change count, and the full job log contains **no** 12-digit
    account id, no `arn:aws:iam::`, and no `.aoss.amazonaws.com` host. Verify by downloading
    the log and grepping for each. No artifact is produced by the run.

- **Task 5: Apply behind a protected Environment, applying the plan it just made**
  - **Description:** Two jobs in `deploy.yml` on `push: branches: [main]`:
    - **`tofu-plan-main`** — identical to Task 4's job (read-only role, `-lock=false`,
      summary only, no artifact). No `environment:`. Its job summary is the fresh evidence
      the approver reads.
    - **`tofu-apply`** — `needs: [tofu-plan-main]`, `environment: production`. Assumes
      `vars.AWS_OIDC_ROLE_ARN`. Runs `tofu init`, then
      `tofu plan -input=false -lock-timeout=5m -out=tfplan`, prints the same jq summary, then
      `tofu apply -input=false -auto-approve tfplan` — **applying the saved plan file, not
      re-planning** (F14). `-auto-approve` is permitted here and only here, because the
      Environment approval already happened (BR-D2).
    Then create the Environment in repo settings:
    ```bash
    gh api -X PUT repos/Seuss27/bedrock-serverless-rag/environments/production \
      --input - <<'JSON'
    { "reviewers": [ { "type": "User", "id": 22668449 } ],
      "deployment_branch_policy": { "protected_branches": true, "custom_branch_policies": false } }
    JSON
    ```
    (`22668449` is the numeric id behind `Seuss27` — confirm with
    `gh api users/Seuss27 --jq .id` before using it; a wrong id silently yields an
    environment with no reviewer, which pauses for nobody.)
    Add a `concurrency` group to `deploy.yml` (F20):
    `group: deploy-${{ github.ref }}`, `cancel-in-progress: false`. **`false` is
    load-bearing** — cancelling an in-flight `tofu apply` orphans the DynamoDB lock and
    leaves state describing a half-applied world.
  - **Target Files:** `.github/workflows/deploy.yml`
  - **Acceptance Criteria:** `gh api repos/Seuss27/bedrock-serverless-rag/environments/production`
    shows a `required_reviewers` protection rule naming a real user and
    `deployment_branch_policy.protected_branches: true`. On the merge of this sprint's PR,
    the `tofu-apply` job reports `waiting` for approval, and the `tofu-plan-main` summary is
    readable before approving. `grep -c 'auto-approve' .github/workflows/deploy.yml` returns
    exactly 1, on the line that applies a plan file.

- **Task 6: Purge every raw-output path**
  - **Description:** Sweep both workflow files for BR-D4 violations beyond Task 4's plan
    step: no `set -x`, no `env` dump, no `aws sts get-caller-identity` echo, no
    `tofu output` without `-json | jq` selecting named fields, no `tofu show` of state. Add
    `set -euo pipefail` to the top of every multi-line `run:` block. Confirm no `${{ }}`
    appears inside any `run:` block anywhere in the repo — pass values through `env:`.
  - **Target Files:** `.github/workflows/ci.yml`, `.github/workflows/deploy.yml`
  - **Acceptance Criteria:** `grep -n '\${{' .github/workflows/*.yml` shows matches only in
    `env:`, `with:`, `if:`, `uses:` and `concurrency:` positions — never inside a `run:`
    block. Every `run: |` block's first line is `set -euo pipefail`.

- **Task 7: Update the drift detector and the schema**
  - **Description:** Append this sprint's new gating checks to the ruleset, to
    `ruleset.required_checks` in `.ai/project.yml`, and to the check list inside
    `.github/workflows/ruleset-drift.yml` — **all three in this PR** (BR-D9). The checks
    added by S1 are: `tofu-fmt`, `tofu-validate`, `tflint`, `checkov`, `secrets-scan`,
    `zizmor`, `tofu-plan`. Append to the existing ruleset with a `PUT`, never replace it:
    ```bash
    gh api repos/Seuss27/bedrock-serverless-rag/rulesets --jq '.[].id'
    gh api -X PUT repos/Seuss27/bedrock-serverless-rag/rulesets/<id> --input updated.json
    ```
    Read the current ruleset first and edit it; a `PUT` with a partial body drops the rules
    it omits, which would silently delete S0's work.
    Do **not** add `iac-diff-guard` as a required check — it is a policy assertion about the
    PR body, and a required check that a fork or a bot cannot satisfy strands PRs.
  - **Target Files:** `.ai/project.yml`, `.github/workflows/ruleset-drift.yml`
  - **Acceptance Criteria:** `gh api repos/Seuss27/bedrock-serverless-rag/rules/branches/main`
    lists 8 contexts (`pr-title` + the seven above) and still all four rule types.
    `.ai/project.yml` lists the same 8 in the same order. `gh workflow run ruleset-drift.yml`
    passes. The three lists are identical — diff them, do not eyeball them.

---

## Definition of Done

`gates.green` passes. Every check in `ruleset.required_checks` is green on the sprint's own
PR. The apply job has been observed **pausing** for approval at least once.
`/critic-gate` has run — propose `security-critic` (this diff is entirely trust-boundary and
credential-handling) and `architect` (the required-check ordering and the plan/apply job
split are where a logic error hides). The green gate and the CI checks are not the same
thing and both must pass.

---

## Critical review

**Security**

- *The apply role is still the F1 escalation-capable role at the end of this sprint.* True,
  and it is why the Environment gate is not optional dressing: for the duration between S1
  and S2, a human approval is the **only** control between a merge and an admin-capable
  apply. Stated in Security Considerations so no one reads the split-role structure and
  assumes S2 already happened.
- *Task 4's plan job still holds credentials on a `pull_request` trigger.* Yes, and until
  S2-T2 adopts the upstream read-only plan role, they are the mutating credentials. Two things bound it: forks get no OIDC token at
  all, so this is reachable only by someone who can already push a branch here; and
  `-lock=false` plus plan-only means no state write. The `AWS_PLAN_ROLE_ARN ||` fallback is
  written so that S2 flips it by creating a variable, with no workflow edit needed — which
  is the shape least likely to be forgotten.
- *Summarizing the plan could hide a dangerous change.* The summary shows every non-no-op
  action **and its full resource address**, which is what a reviewer needs to spot a
  `delete` on the state bucket or a `replace` on the collection. What it omits is attribute
  values — the account ids, ARNs, and endpoints of BR-D4. A reviewer who needs values runs
  the plan locally against read-only credentials; that path exists and is not public.
- *Deleting `tfplan` at the end of the job is not a security control* — the runner is
  ephemeral. It is there so a later, well-meant `upload-artifact` has nothing to grab. The
  real control is "upload no artifact," stated as its own requirement.
- *`iac-diff-guard` is bypassable by typing the magic line.* Correct, and intended: it is a
  declaration mechanism, not an authorization one. Its value is that a `bootstrap/` change
  cannot arrive **unnoticed**. That is also exactly why it must not be a required check.

**Logic**

- **The plan/apply TOCTOU cannot be fully closed across runs, and pretending otherwise would
  be the worse error.** The Environment approval fires when the `tofu-apply` job *starts*,
  which is necessarily before that job's own plan. So the approver's evidence is
  `tofu-plan-main`'s summary from moments earlier, and what actually applies is
  `tofu-apply`'s own freshly-saved plan file. The residual window is between those two
  plans. This is a deliberate trade against the alternative — passing a `tfplan` artifact
  between jobs — which on a **public** repo publishes a world-readable file containing every
  value BR-D4 forbids. Recorded as an accepted residual; a private artifact store or a
  plan-hash comparison would close it and is a candidate follow-up issue, not S1 scope.
- **`cancel-in-progress` must be `false` on the deploy workflow** and `true` on `pr-title`.
  The reflex is to set it `true` everywhere for cost. Cancelling a running `tofu apply`
  leaves an orphaned DynamoDB lock and a state file that describes a half-applied world —
  strictly worse than a queued run. Called out inline because the default reads as harmless.
- *Ordering inside the sprint.* Task 2 deletes the file Tasks 4 and 5 write into, so it must
  land first; Task 7 must land **last**, because requiring a check before its job exists is
  the S0 deadlock again, one sprint later. Tasks 1, 3, 6 are order-independent.
- *`tofu-validate` covering `bootstrap/` looks like it contradicts BR-D1.* It does not.
  BR-D1 says CI never **applies** `bootstrap/`. Validating and scanning it is the opposite
  of a violation — F1 and F2 have gone unscanned precisely because nothing looked.
- *`strict_required_status_checks_policy` (from S0) plus seven new checks means more
  rebasing.* Accepted; one maintainer, near-zero cost.

**Execution**

- *Reusing SHAs from a sibling repo.* Permitted for the six listed because they were
  verified there, but Task 1 still requires re-resolving the two unknown actions through the
  API and requires the annotated-tag dereference step — `git/ref/tags/<tag>` returns the
  *tag object's* sha for annotated tags, not the commit's, and pinning to it fails with a
  message that reads like a network error.
- *The `production` Environment must exist before the first post-S1 merge.* If it does not,
  GitHub does not error — the job simply runs with no pause, and the sprint's central
  control is absent while the workflow file claims it. Task 5 therefore makes "observed
  pausing at least once" an acceptance criterion, not "the YAML says `environment:`."
- *A wrong numeric user id in the Environment payload yields an environment with no
  reviewer*, which also pauses for nobody. Task 5 requires confirming the id from
  `gh api users/Seuss27 --jq .id` first.
- *`gh api -X PUT` on a ruleset with a partial body deletes the omitted rules.* Task 7
  requires reading the current ruleset and editing it. Losing S0's four rule types while
  "adding" checks would be a silent, total regression of the previous sprint.
- *Checkov at `directory: .` will almost certainly fail the first run* — it will find F7's
  missing public-access block and F6's public network policy, among others. That is the
  scanner working. Task 3 forbids reflex suppression and routes each finding to the sprint
  that owns it, so S1 does not quietly absorb S3's work.
