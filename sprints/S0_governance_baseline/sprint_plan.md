### FILEPATH: /sprints/S0_governance_baseline/sprint_plan.md

# S0 — Governance and repository baseline

> **⚠ Reshaped 2026-08-05 by BR-D23 — this sprint GAINS two items pulled forward.** Both are
> cheap, both were scheduled far too late, and neither touches identity.
>
> - **Task 7 (new): delete the Infisical scaffolding** — the *deletion* half of **S3-T8** /
>   **F53**. The commented-out provider block, the `infisical_secrets` data source, the
>   Cloudflare provider it fed, `var.infisical_workspace_id`, and the three `README.md` lines
>   that tell a reader to provision `INFISICAL_CLIENT_ID`/`_SECRET` — i.e. **exactly the
>   credential F52 says to revoke**. Pure deletion, zero apply risk, and it closes the actively
>   harmful half of F53 seven sprints early. *(The SSM canary half did NOT come with it — that
>   moved upstream to `glunk-works/global-bootstrap`; see roadmap § 9.5.)*
> - **Task 8 (new): the budget** — was **S6-T3**, scheduled ninth despite that task stating in
>   its own words that an environment left running is *"the most likely real-world loss this
>   project will ever produce — larger in expectation than any finding in § 3.4."* Take the
>   `aws_budgets_budget` with 50/80/100 % notifications driven by a variable, plus
>   `docs/cost.md`. **Do NOT take the AOSS capacity-limit half** —
>   `aws_opensearchserverless_account_settings` **does not exist under any spelling** (provider
>   issue `hashicorp/terraform-provider-aws#41245`, open since 2025-02-05); a capacity limit is
>   console/CLI-only. **The notification email is a variable and is never committed** — an
>   address in a public repo is spam bait and PII.
> - **F54's one-line `.gitignore` fix belongs in Task 5** and should not wait: `.env` → `.env*`
>   plus `!.env.example`, and add `tfplan`, `plan.json` (S1-T4 creates both by those exact
>   names) and `.venv/` (`venv/` does not match it — `environments/ai-lab/.venv/` is ignored
>   today only because `python -m venv` writes its own `.gitignore` inside it).
>
> **Neither new task changes this sprint's "no `.tf`, no AWS resource" claim in spirit, but the
> budget breaks it in fact** — it is the first AWS resource S0 creates. Say so in the PR body
> rather than letting the header quietly become false.

**Sprint Goal:** Make every subsequent control enforceable. Install branch protection on
`main`, fix the merge settings that would render the PR-title gate decorative, and align the
issue/label taxonomy with the Global Conventions. **No `.tf` file and no AWS resource is
touched in this sprint.**

**Closes:** F17 (Critical), F33, F34, F35, F36, F37, F38.

**Dependencies:** None. S0 is the entry point — every later sprint's gates are advisory
until F17 is closed.

**Security Considerations:** This sprint changes *who may merge what*, which is the control
plane for every other change in the repo. Two failure modes dominate and both are addressed
below: a ruleset that requires a non-existent check permanently deadlocks the repo (BR-D9),
and a ruleset that requires an approving review deadlocks a **solo-owner** repo, because
GitHub forbids approving your own pull request. No task here grants any new AWS permission.

**Risks & Blockers:**
- Tasks 1, 2 and 3 change **live GitHub state** via `gh api`, not files. They are not
  revertible by `git revert`; each task below states its own undo command.
- The `gh` token must carry `repo` and `admin:repo_hooks` scope. Verify with
  `gh auth status` before starting; if the ruleset POST returns 403, stop and report — do
  not retry with a broader token you minted yourself.
- Once Task 1 lands, **direct pushes to `main` stop working for the owner too.** That is the
  intent. Every subsequent sprint must go through a PR.

---

## Tasks

- **Task 1: Install the `protected-integration-branches` ruleset**
  - **Description:** Create a repository ruleset on `main` with exactly four rule types —
    `deletion`, `non_fast_forward`, `pull_request`, `required_status_checks` — and exactly
    **one** required check: `pr-title` (created by Task 4). Run Task 4 **first** and merge
    its workflow before executing this task, or the required check will not exist and every
    PR will hang (BR-D9).
    Use this payload verbatim, written to a file and posted with `gh api`:
    ```json
    {
      "name": "protected-integration-branches",
      "target": "branch",
      "enforcement": "active",
      "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
      "bypass_actors": [],
      "rules": [
        { "type": "deletion" },
        { "type": "non_fast_forward" },
        { "type": "pull_request",
          "parameters": {
            "required_approving_review_count": 0,
            "dismiss_stale_reviews_on_push": true,
            "require_code_owner_review": false,
            "require_last_push_approval": false,
            "required_review_thread_resolution": false
          } },
        { "type": "required_status_checks",
          "parameters": {
            "strict_required_status_checks_policy": true,
            "required_status_checks": [ { "context": "pr-title" } ]
          } }
      ]
    }
    ```
    ```bash
    gh api -X POST repos/Seuss27/bedrock-serverless-rag/rulesets --input ruleset.json
    ```
    `required_approving_review_count` is **0 and must stay 0**: this is a solo-owner repo and
    GitHub forbids approving your own PR, so any value ≥ 1 makes every PR unmergeable
    forever. `bypass_actors` is empty on purpose — a ruleset the owner can bypass is a
    suggestion. Then update `.ai/project.yml`'s `ruleset` block **in this same PR** to the
    live values: `name: protected-integration-branches`, the four `rule_types`,
    `required_checks: [pr-title]`.
  - **Target Files:** `.ai/project.yml` (live GitHub state is changed via `gh api`; the JSON
    payload is a scratch file and must **not** be committed).
  - **Acceptance Criteria:** `gh api repos/Seuss27/bedrock-serverless-rag/rules/branches/main`
    returns exactly the four rule types above and exactly one required context, `pr-title`.
    `.ai/project.yml`'s `ruleset` block matches that output key for key, with no `null`
    remaining. A `git push` directly to `main` is rejected.
  - **Undo:** `gh api -X DELETE repos/Seuss27/bedrock-serverless-rag/rulesets/<id>`.

- **Task 2: Correct the merge settings**
  - **Description:** Set the squash-commit title source to the **PR title** and enable
    automatic head-branch deletion:
    ```bash
    gh api -X PATCH repos/Seuss27/bedrock-serverless-rag \
      -f squash_merge_commit_title=PR_TITLE \
      -f squash_merge_commit_message=COMMIT_MESSAGES \
      -F delete_branch_on_merge=true \
      -F allow_merge_commit=true \
      -F allow_rebase_merge=false
    ```
    The title source is the load-bearing half: with GitHub's default
    (`COMMIT_OR_PR_TITLE`), a **single-commit PR silently uses the commit subject** instead
    of the PR title, bypassing the `pr-title` check entirely — so that gate is decorative
    until this is set. `COMMIT_MESSAGES` for the body keeps per-task rationale and the
    `Sprint:`/`Finding:` trailers greppable. Merge commits stay allowed for the one
    deliberate exception in the conventions (an integration branch into `main`); rebase
    merges are turned off as a third path nobody here uses.
  - **Target Files:** none (live GitHub state).
  - **Acceptance Criteria:**
    `gh repo view Seuss27/bedrock-serverless-rag --json squashMergeCommitTitle,deleteBranchOnMerge,rebaseMergeAllowed`
    returns `PR_TITLE`, `true`, `false`.

- **Task 3: Migrate the label and issue-template taxonomy**
  - **Description:** Bring labels onto the three orthogonal axes in
    `docs/hardening_roadmap.md` § 7, keeping the two documented local axes.
    1. **Rename** (preserves existing assignments — use `gh label edit --name`, never
       delete-and-create): `type/bug`→`bug`, `type/feature`→`feature`,
       `type/docs`→`docs`, `type/security`→`security`, `type/access`→`chore`,
       `scope/iam`→`area/bootstrap`, `scope/pipeline`→`area/ci`,
       `scope/bedrock`→`area/rag`.
    2. **Create:** `area/module`, `area/env`, `area/docs`, `status/needs-human`,
       `env/ai-lab`, and the machine namespace `bedrock-serverless-rag/needs-human`
       (description: "applied by an automated writer — never by a human").
    3. **Delete** the labels naming infrastructure this repo does not have:
       `type/drift`, `type/sync-failure`, `env/prod`, `env/staging`, `env/dev`. Before
       deleting each, run `gh issue list --label <name>` and re-label any hits onto the new
       taxonomy; a delete that silently drops a label off an open issue is not acceptable.
    4. **Issue templates:** delete `.github/ISSUE_TEMPLATE/drift_sync.yml` (it asks for "the
       ArgoCD app, Flux Kustomization, or Helm Release" — none of which exist here). In the
       remaining three, remove the `title:` key entirely (F35 — no title prefixes), and
       update every `labels:` array to the new names. In `bug_report.yml` and
       `feature_request.yml`, replace the Production/Staging/Development dropdown options
       with `ai-lab` and `global`.
    5. Re-title the two open issues to drop their prefixes: **#8** → `revise README to
       match the module layout and current models`; **#6** → `add aws:SourceArn to the
       Bedrock knowledge base trust policy`.
  - **Target Files:** `.github/ISSUE_TEMPLATE/bug_report.yml`,
    `.github/ISSUE_TEMPLATE/feature_request.yml`, `.github/ISSUE_TEMPLATE/access_request.yml`,
    `.github/ISSUE_TEMPLATE/drift_sync.yml` (deleted).
  - **Acceptance Criteria:** `gh label list` shows no `type/*` and no `scope/*` label; shows
    `area/bootstrap`, `area/module`, `area/env`, `area/ci`, `area/rag`, `area/docs`; shows
    `bedrock-serverless-rag/needs-human`. No open issue has zero labels. No file under
    `.github/ISSUE_TEMPLATE/` contains a `title:` key or the string `ArgoCD`. Issues #6 and
    #8 have no `[` in their titles.

- **Task 4: Add the `pr-title` workflow**
  - **Description:** Create `.github/workflows/pr-title.yml` enforcing the Conventional
    Commits grammar on the PR title. Port it from `glunk-works/bounty-infra`'s file of the
    same name and keep the reasoning comments — in particular **why it is its own workflow
    and not a job in the deploy workflow**: a title check needs `edited` to fire, but
    `edited` inside a heavy workflow under a cancelling concurrency group can cancel an
    in-flight run, and a cancelled-then-replaced run can report `skipped` — which *satisfies*
    a required check instead of failing it.
    Required properties:
    - `on: pull_request: types: [opened, edited, reopened, synchronize]`
    - `permissions: {}` (reads the title off the event payload; no checkout, no API call)
    - a `concurrency` group keyed on workflow + ref, `cancel-in-progress: true`
    - job id **`pr-title`** with **no `name:` override** (the job id is the check context)
    - the title arrives via `env: TITLE: ${{ github.event.pull_request.title }}` and is
      **never** interpolated into the `run:` script — a PR title is attacker-controlled text
    - `set -euo pipefail`
    - grammar:
      `^(feat|fix|docs|test|refactor|perf|chore|ci|revert)(\([a-z0-9._/-]+\))?!?: [a-z].*[^.]$`
      — note the **absence of `style`** is deliberate (F36)
    - length limit **72**, with `dependabot[bot]`, `dependabot-preview[bot]` and
      `github-actions[bot]` exempt from the **length** check only (they compose their own
      titles and cannot shorten them; without the exemption every Dependabot PR becomes
      permanently unmergeable). The bot-name `case` patterns must be **quoted** — unquoted,
      `[bot]` is a glob character class matching a single `b`, `o`, or `t`.
  - **Target Files:** `.github/workflows/pr-title.yml`
  - **Acceptance Criteria:** The workflow file contains no `${{` inside any `run:` block.
    The check reports on this sprint's own PR and passes. Locally verified against the
    regex: `chore(ci): add pr-title workflow` passes; `style(bootstrap): apply linting
    fixes` fails; `chore(ci): Add workflow` fails (capital); `chore(ci): add workflow.`
    fails (trailing period).

- **Task 5: Repository baseline files**
  - **Description:** Add the five files the repo lacks (F37):
    0. **`.gitignore`** — widen `.env` to `.env*` and add `!.env.example` (F54). Today only
       the exact name `.env` is ignored, so `.env.local`, `.env.bak`, `.env.prod` and every
       per-directory variant are committable — verified with `git check-ignore`. The trigger
       is mundane: backing up a secrets file before editing it. Also add
       `*.tfstate.backup`-adjacent hygiene if `git status` shows anything else stray.
    1. **`.gitattributes`** — `* text=auto eol=lf`. Non-cosmetic: this repo is authored on
       Windows and its scripts are executed by a Linux runner; a CRLF in a future shell
       script fails as `bad interpreter: /bin/bash^M`.
    2. **`.github/CODEOWNERS`** — `* @Seuss27`, plus explicit lines for `/bootstrap/` and
       `/.github/workflows/` so those two directories stay visible as high-consequence even
       when ownership later widens.
    3. **`.github/PULL_REQUEST_TEMPLATE.md`** — sections: *What and why*; *Sprint / Finding*
       (`Sprint: S<N>`, `Finding: F<N>`); *Green gate* (paste the `gates.green` result);
       *Blast radius* — a required checklist line **"this PR does / does not change what CI
       may do in AWS"**; *Plan summary* if a `.tf` file changed (change counts + resource
       addresses only — **never** raw plan output, BR-D4).
    4. **`SECURITY.md`** — private-reporting instructions via GitHub Security Advisories,
       an explicit statement that this is a personal lab with no SLA, and the BR-D4 rule
       that a reporter must not paste account identifiers into a public issue.
    5. **`.github/dependabot.yml`** — one ecosystem only: `github-actions`, `directory: "/"`,
       `schedule: weekly`, grouped into a single PR
       (`groups: {actions: {patterns: ["*"]}}`). **Do not add the `pip` ecosystem in this
       sprint** — `environments/ai-lab/requirements.txt` is unpinned and BOM-prefixed
       (F29), so Dependabot would open noise against a file S5 is about to replace.
  - **Target Files:** `.gitattributes`, `.github/CODEOWNERS`,
    `.github/PULL_REQUEST_TEMPLATE.md`, `SECURITY.md`, `.github/dependabot.yml`
  - **Acceptance Criteria:** All five files exist, and `git check-ignore -q .env.local .env.bak` succeeds for both (F54). `.gitattributes` addition does not alter
    any existing tracked file's content — verify with `git add --renormalize . && git status`
    and report any file it rewrites **before** committing. The Dependabot config lists
    exactly one ecosystem entry. `gh api repos/Seuss27/bedrock-serverless-rag/codeowners/errors`
    returns an empty `errors` array.

- **Task 6: Add the ruleset-drift detector**
  - **Description:** Create `.github/workflows/ruleset-drift.yml`, ported from
    `glunk-works/bounty-infra`. It re-reads
    `gh api repos/${REPO}/rules/branches/main` on a daily `schedule` **plus**
    `workflow_dispatch` (a cron-only trigger cannot be tested without waiting for the cron),
    and fails loudly if any of the four rule types or any required context from
    `ruleset.required_checks` is missing. `permissions: contents: read`;
    `GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}`; `set -euo pipefail`.
    **This workflow is never itself a required check** — a required check is required only
    because the ruleset says so, so requiring the drift detector would un-require it at the
    instant the ruleset is deleted, silently, on the exact failure it exists to catch. Say
    that in a comment in the file.
    The check list in the script is `pr-title` only for now; **every later sprint that
    appends a required check updates this list in the same PR.** Put that instruction in a
    comment directly above the list.
  - **Target Files:** `.github/workflows/ruleset-drift.yml`
  - **Acceptance Criteria:** `gh workflow run ruleset-drift.yml` succeeds after Task 1. Then
    verify it actually detects drift: temporarily delete the ruleset, re-run, confirm the
    job **fails** naming the missing rule types, re-create the ruleset from the Task 1
    payload, re-run, confirm it passes. A drift detector that has never been observed to go
    red has not been tested.

---

## Definition of Done

`gates.green` from `.ai/project.yml` passes (this sprint changes no `.tf`, so both
`tofu validate` runs must still exit 0 — a regression here means something unrelated
broke). `.ai/project.yml`'s `ruleset` block reflects live state. `/critic-gate` has run —
propose `docs-consistency` (this sprint edits load-bearing prose and `.ai/project.yml`) and
`architect` (the ruleset ordering is the kind of logic error that only shows up as a
deadlock). The PR title itself passes the gate the sprint installs.

---

## Critical review

Objections raised against this plan during planning, and their resolution. Findings that
survived review are folded into the tasks above.

**Security**

- *Zero required approvals means a ruleset that does not require review.* Correct, and
  accepted with a stated reason: on a solo-owner repo, GitHub forbids self-approval, so any
  count ≥ 1 makes every PR permanently unmergeable — the rule would not be strict, it would
  be a denial of service against the only maintainer. What the `pull_request` rule still
  buys at count 0 is real: no direct push to `main`, a PR and a diff for every change, and a
  surface for required status checks to attach to. When a second maintainer exists, raising
  the count is a one-line ruleset edit; recorded in BR-D13's orbit, not deferred silently.
- *Empty `bypass_actors` could lock the owner out during an incident.* Accepted knowingly. A
  repo admin can always delete the ruleset through the UI, so this is recoverable in
  seconds; a standing bypass entry, by contrast, is permanent and invisible in the check
  output. The undo command is recorded in Task 1.
- *Task 3 deletes labels, which destroys information.* Mitigated by ordering: renames are
  done with `gh label edit` (assignments survive), and every delete is preceded by a
  `gh issue list --label` sweep. The acceptance criterion "no open issue has zero labels"
  is what makes that checkable rather than promised.
- *No new AWS permission is granted anywhere in S0.* Verified: no task touches `bootstrap/`,
  and `pr-title`/`ruleset-drift` declare `permissions: {}` and `contents: read`
  respectively. The `GITHUB_TOKEN` in Task 6 is read-only against the rules API.

**Logic**

- **The deadlock.** The first draft of Task 1 required the full target check list. That
  bricks the repo: a required check whose workflow does not exist never reports, so every PR
  hangs — *including the PR that would add the workflow*, which cannot be merged to fix it.
  Resolved by BR-D9 (monotonic ruleset growth, one check per PR) and by an explicit ordering
  constraint inside Task 1: **Task 4 merges first**.
- **A second, subtler deadlock** was caught in Task 4: had `pr-title` been added as a *job*
  in `deploy-ai-lab.yml` instead of its own workflow, the `edited` trigger under a cancelling
  concurrency group could cancel an in-flight run of the heavy jobs — and a cancelled,
  replaced run can report `skipped`, which **satisfies** a required check rather than
  failing it. The gate would then pass on a PR whose real checks never ran. This is why the
  separate-workflow decision is stated as a requirement with its reason, not a preference.
- *`strict_required_status_checks_policy: true` requires branches to be up to date before
  merging.* Kept: with one maintainer the rebase cost is near zero, and it removes the
  semantic-conflict class where two independently-green PRs break `main` together.
- *Does Task 1's ruleset break the sprint's own PR?* No — it is created from a branch, and
  `pr-title` exists by then (Task 4 merged first). But the ruleset takes effect immediately
  on creation, so **Task 1 must not be the first commit of a long-running branch**; it goes
  in last, or in its own follow-up PR.

**Execution**

- *Tasks 1, 2, 3 change state that `git revert` cannot undo.* Each now carries its own undo
  command or a rename-not-delete instruction. The coder must report the ruleset id emitted
  by the POST — without it the undo requires a lookup the coder may no longer be able to do.
- *`gh api -F delete_branch_on_merge=true` vs `-f`.* `-F` sends a typed JSON boolean; `-f`
  sends the string `"true"`, which the API rejects for a boolean field. The exact flags are
  spelled out in Task 2 because this is a recurring silent failure — the request 422s with a
  message that reads like a permissions problem.
- *`.gitattributes` can rewrite the working tree.* Task 5's acceptance criterion forces
  `git add --renormalize .` **before** committing and requires reporting anything it
  rewrites, so a line-ending normalization does not arrive disguised as a functional diff.
- *Task 6's drift detector is untested if it only ever passes.* Acceptance criterion now
  requires observing it go **red** against a deliberately deleted ruleset and green again
  after restore. Discovered as a real gap: the sibling repo's detector sat green for weeks
  over a ruleset that did not exist at all.
