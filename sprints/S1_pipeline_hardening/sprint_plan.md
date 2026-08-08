### FILEPATH: /sprints/S1_pipeline_hardening/sprint_plan.md

# S1 — Pipeline hardening

> **⚠ REASSESSED 2026-08-08 after `S1a` shipped — the pause this plan mandated was taken, and
> it produced changes. This banner outranks the re-planning banner below it and every task
> body.** **`S1b` is now FIVE tasks: `T2 → T1 → T3 → T6 → T7`.** Both changes below were
> measured against the shipped `deploy-ai-lab.yml`, not reasoned from this plan.
>
> **First, the question the pause was called to ask is answered NO.** The reassessment was
> scoped to "is the approval-on-every-merge trade still acceptable now that `paths:` is gone."
> It is. Measured on `S1a`'s own merge (run `31272226259`): `tofu-plan-main` 32s → `tofu-apply`
> paused in `waiting` → approved → applied green in 40s. A no-op merge costs one click and
> about four minutes, and it exercises the gate every single time. **Unchanged, and the "known
> and accepted consequence" paragraph in T5 stands as written.** *(Do not "fix" this later with
> a `plan shows 0 changes → skip the apply` short-circuit. It would reduce how often the gate
> is exercised, which is the opposite of what `S1b` needs while it rewrites the pipeline
> underneath that gate.)*
>
> ## 1. ⚠️ `T4` IS DEFERRED TO `S2` — and it closes nothing on the way out
>
> **`T4` is not descoped work; it is work that had stopped paying for itself.** Two measured
> facts, in the order they matter:
>
> - **F16 IS ALREADY CLOSED — by `S1a`-T5, not by T4.** F16 is *"`tofu plan -no-color` dumps
>   the full plan into a world-readable log."* The shipped file has **no `pull_request`-triggered
>   plan step at all**, and **all three** plan steps that do exist redirect to `/dev/null` —
>   `tofu-plan-main` (`deploy-ai-lab.yml:186`) and `tofu-apply` (`:283`) emit the jq
>   address-and-count summary; `destroy-ai-lab` (`:369`) emits a `grep`-filtered `Plan:`/address
>   extract. There is no remaining path by which a plan render reaches a log.
>   **The finding inventory still attributes F16 to `S1-T4`; that row is corrected to `S1a`-T5
>   in this PR.** So T4's entire remaining product is *PR-time plan visibility* — a convenience,
>   not a finding.
> - **T4 would re-open the exposure `T2` is about to close, and `T7` would then weld it to the
>   merge path.** Exactly **one** credentialed `pull_request` job exists today:
>   `security-and-linting` (`deploy-ai-lab.yml:104-107`) assumes `secrets.AWS_OIDC_ROLE_ARN` —
>   the admin-capable deploy role — and `pip install`s from the PR branch while holding it. That
>   is **F3 read the way `CLAUDE.md` reads it**: arbitrary command execution with
>   account-admin-capable credentials, available to anyone who can push a branch. **`T2` deletes
>   it** — `ci.yml` is uncredentialed by construction, so after T2 this repo has **zero
>   credentialed `pull_request` jobs for the first time in its history.** T4 puts one back, on
>   the *same* apply-capable role (no plan role exists until `S2`-T0), and T7 then makes it
>   **required** — which this plan already conceded in T7's own footnote: it *"makes F2
>   load-bearing for merging."*
>
> **Where it lands:** `S2`-T0 mints the read-only plan role and `S2`-T2 narrows the trust policy,
> **in the same sprint**. `S2`-T2 already assumes a PR plan job exists (its step 1 says "drop
> S1's `||` fallback", its step 2 verifies "a PR plan job green on the plan role"). Deferring
> means `S2` **authors** that job once, with the correct role, instead of repointing one written
> around a fallback. The intake is recorded in `sprints/S2_identity_least_privilege/sprint_plan.md`
> — per `ST`'s rule that a task moved out of a sprint and not written into where it landed is a
> task **dropped**.
>
> **What is given up, stated plainly rather than minimised:** a `.tf` change gets no plan summary
> until after merge. BR-D2 is untouched — `tofu-plan-main` plus the `production` Environment *is*
> the plan-a-human-read control, and it is now proven end to end rather than asserted. The real
> residual is that the approver can decline a post-merge apply, which leaves `main` describing an
> unapplied world until the next merge. Mild, self-healing, **accepted**.
>
> **One accepted cost evaporates with it:** the Risks bullet *"making `tofu-plan` a required
> check means a fork PR can never go green"* no longer applies to this sprint — every check
> `S1b` requires is credential-free.
>
> ## 2. ⚠️ `checkov` IS RUN BY `T3` BUT NOT REQUIRED BY `T7`
>
> This plan's **own Execution review** says checkov at `directory: .` *"will almost certainly
> fail the first run"* on F7's missing public-access block and F6's public network policy —
> **which are `S3`'s findings, not `S1`'s.** T7 would make it required with `bypass_actors: []`.
> The result is that `S1b` must either close `S3`'s work or write suppressions for it, in-sprint,
> **or every PR in the repo becomes unmergeable with the fix living outside the PR.** That is the
> BR-D9 deadlock class, arriving by the same route the `GITLEAKS_LICENSE` warning below caught it.
>
> The repo has already made this call twice, on the same reasoning: BR-D23 on `dependency-audit`
> (*"Run it; do not gate on it"*) and T2's own `python-lint` (*"requiring a check whose config
> does not exist yet is the S0 deadlock in miniature"*). **Run checkov on every PR from `T3`;
> add it to `required_checks` in `S3`, in the change that closes the findings it fires on.**
>
> **`T7`'s required list is therefore FIVE, not seven** — `tofu-fmt`, `tofu-validate`, `tflint`,
> `secrets-scan`, `zizmor` — i.e. **six contexts** with `pr-title`. T7's body and acceptance
> criterion are corrected in place below, because those are copy-pasteable literals and a banner
> does not save someone who pastes a stale count.

> **⚠ RE-PLANNED 2026-08-08 against live post-`MW` state, then CRITIQUED AND REVISED the same
> day. This banner outranks the 2026-08-05 banner below it and every task body.** `MW` closed
> 2026-08-08 and four of this plan's premises died with it.
>
> **⚠️ What was measured, and when — stated precisely, because the first draft of this banner
> got it wrong.** Measured *before* the first draft: `gh secret list`, `gh secret list --org`,
> `gh variable list --json name`, `gh api .../environments`, `gh api user`,
> `.github/PULL_REQUEST_TEMPLATE.md`, and the live `deploy-ai-lab.yml`. Measured *only after*
> the critique, having been **asserted from prose in the first draft**: the `paths:` filter's
> effect on S1's own merges, and the OIDC trust policy's subject glob. That first draft opened
> "Measured, not assumed" while resting on two unverified claims — one of which was **wrong**
> and reversed the execution order (see slice S1a below). Recorded rather than quietly fixed:
> this is the repo's own `record-is-not-evidence` failure, committed inside the sentence
> claiming immunity from it.
>
> ## ⚠️ THIS SPRINT IS SPLIT INTO TWO SHIPPING SLICES (owner decision, 2026-08-08)
>
> Task **ids are unchanged** — `T1..T7` mean what they always meant. Only grouping and order
> change. **Stop and reassess between the slices**; S1b may be reshaped by what S1a teaches.
>
> **`S1a` — the gate. Task `T5` ALONE.** Lands against the existing `deploy-ai-lab.yml`;
> `deploy.yml` does not exist yet. Closes **F13, F14, F20**, and the **`paths:`/`name:` half of
> F18** (moved here from T2 — see below). This slice is the sprint's entire prize: F13 is the
> only thing standing between a merge and an admin-capable apply, and T5 closes it in one
> reviewable diff over code `MW` proved, months before the rest of the hardening is written.
>
> **`S1b` — the rewrite. ~~`T2 → T1 → T4 → T3 → T6 → T7`~~ `T2 → T1 → T3 → T6 → T7`.** *(`T4`
> deferred to `S2` by the 2026-08-08 post-`S1a` reassessment — top banner.)* Closes F15,
> ~~F16,~~ F19, F21 and the rest of F18. **F16 was already closed by `S1a`-T5**, not by T4.
> **`T1` now runs AFTER `T2`, reversing the first draft** — `T1` SHA-pins actions,
> and `T2` *deletes the file those actions live in*. Pinning `deploy-ai-lab.yml` and then
> deleting it is wasted work whose only product is a merge conflict; `T2` may simply author the
> new files pre-pinned and leave `T1` to verify. `T7` is still last (requiring a check before
> its job exists is the S0 deadlock).
>
> **Three decisions taken in the planning pass (owner, 2026-08-08):**
>
> 1. **The gate lands first — but NOT for the reason the first draft gave, and the difference
>    matters.** ~~It lands as the smallest possible diff over code `MW` just proved works.~~
>    **That rationale was unsound and is withdrawn.** Adding `environment: production` *changes
>    the job's OIDC subject*, which is **exactly** the risk decision 2 below refuses to take on
>    the destroy job — the first draft applied opposite risk logic to the same mechanism, in the
>    same file, in the same plan. **The real reason T5 goes first: it is the sprint's only
>    genuine security outcome, and the six remaining tasks are hardening around a control that
>    does not exist yet.** Ship the prize, then reassess. The subject change is not "small"; it
>    is *accepted*, and it is now verified rather than assumed (see decision 2).
> 2. **The `destroy-ai-lab` job stays phrase-gated and is carried byte-identical** into
>    `deploy.yml` by T2 — **not** put behind `environment: production`.
>    ~~Recorded as an accepted residual: the typed confirm phrase is a self-confirmation rather
>    than a second pair of eyes, but…~~ **That framing was wrong and is withdrawn: it implies an
>    Environment would supply a second pair of eyes. It would not.** GitHub permits
>    **self-approval on Environments** (unlike PR reviews), and this repo has one maintainer —
>    so `environment: production` on destroy buys **zero** independent review. **The real trade
>    is an audit trail plus a uniform "no AWS mutation without an Environment approval"
>    invariant, against changing the credential path of the one destroy mechanism `MW`
>    measured.** Declined for now on that basis. **Revisit the moment a second maintainer
>    exists — at which point the trade genuinely does become about eyes.**
>    *(Trust-policy claim now VERIFIED, not assumed: `bootstrap/oidc-setup.tf:143` renders
>    `"${prefix}:*"` into a `StringLike` on `:sub`, and `:74` records that in IAM `StringLike`
>    a `*` matches `:` as well — so `…:environment:production` does match, and an Environment
>    on either job authenticates. The claim was right; asserting it unverified was not.)*
> 3. **`MW`'s `destroy → apply → verify` cycle is a DoD criterion of `S1b`, run ONCE at the end
>    of that slice.** Not optional polish: T2 deletes the file `MW` proved, so **`MW`'s proof
>    does not cover the shipped workflow** until this re-run. **`S1a` does not need it** — T5
>    edits that file in place rather than replacing it, and T5 has its own, stronger
>    verification (an *observed* pause; see the task body).
>
> **📌 OWED TO THE ROADMAP, NOT THIS FILE — decision 2 must become `BR-D25`.** It is a residual
> **risk acceptance about a trust boundary** ("the most destructive path in the repo is gated by
> self-confirmation alone, accepted, revisit on a second maintainer"), and `CLAUDE.md` makes
> `docs/hardening_roadmap.md` both the decisions log **and** the threat model. Left only here, it
> is archived out of sight when this sprint closes. **Record it in the roadmap in `S1a`'s PR.**
>
> **Four dead premises, corrected in the task bodies below (not just here, because these are
> copy-pasteable literals — a banner does not save someone who pastes a broken command):**
>
> - **⚠️ `vars.*` NO LONGER EXISTS IN THIS REPO.** `gh variable list` returns **nothing**;
>   `AWS_OIDC_ROLE_ARN`, `DATA_SOURCE_BUCKET_NAME`, `SSO_ADMIN_ROLE_ARN` and
>   `BUDGET_NOTIFICATION_EMAIL` are all **`secrets.*`**, moved there by `MW`-T6's BR-D21
>   correction (GitHub dumps every `vars.*` value into the auto-generated step preamble of
>   *every* step; only `secrets.*` is masked). Every `vars.X` in this plan is **dead syntax
>   that resolves to an empty string rather than erroring** — the exact silent-failure class
>   this sprint exists to remove. All occurrences below are corrected to `secrets.*`. The
>   `AWS_PLAN_ROLE_ARN || AWS_OIDC_ROLE_ARN` **fallback shape is kept** — its whole point is
>   that S2 flips it by creating the missing value with no workflow edit; only the namespace
>   changed.
> - **F39 is CLOSED (2026-08-08).** The Risks bullet claiming *"`tofu plan` output cannot be
>   trusted as a description of reality … the state CI reads does not contain the deployed
>   resources"* is struck below. `MW`-T5 reconciled state and `MW`-T6 proved a CI-driven
>   `destroy → apply` cycle. Plan output from `environments/ai-lab` is now trustworthy.
> - **`GITLEAKS_LICENSE` — T3's deadlock risk is resolved by measurement, option (a).**
>   `gh secret list --org glunk-works` shows it present with visibility `ALL`, so this repo
>   already inherits it. No new secret, no BR-D21 exception to record, no unmergeable-PR
>   scenario. The long warning in T3 is retained as the reasoning that made someone check.
> - **`Seuss27/bedrock-serverless-rag` in T5's and T7's `gh` commands is WRONG and would
>   404.** Those are **operative commands**, not the historical strings ST-T4 exempted by
>   name — corrected to `glunk-works/` in place. **`gh api users/Seuss27` is correct and
>   stays**: the *repo* moved to the org, the *user* did not. Verified live 2026-08-08 —
>   `gh api user` returns `{"id":22668449,"login":"Seuss27"}`, matching T5's hardcoded id, and
>   `glunk-works` has **no teams**, so a User reviewer is the only option.
>
> **Two live controls that this plan does not mention at all, and T2 must carry forward.**
> Both arrived with `MW`, after this plan was written, and a rewrite that forgets them is a
> silent regression of proven work:
> - the **`destroy-ai-lab` job** (decision 2 above);
> - the **`Register bare account id for log masking` step**, present in **all three**
>   credentialed jobs — it derives the bare account id from the role ARN and registers it as
>   a mask so BR-D4 holds even when a tool prints it incidentally.
>
> **One thing already done that T3 still asks for:** `iac-diff-guard` was CUT by BR-D23 with
> its requirement moved to the PR template — and `.github/PULL_REQUEST_TEMPLATE.md` **already
> carries a `Blast radius` section**. T3 is **three** scanner jobs, not four, with nothing new
> to write.

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
>   job **can never assume it**. ~~ST-T2 step 4 decides~~ **S2-T0 decides** between adding an
>   `extra_oidc_subjects` equivalent upstream and dropping `tofu-plan-main` entirely.
>   > **⚠️ Corrected 2026-08-07 by ST-T5, and the correction matters more here than elsewhere.**
>   > ST made no such decision: `ST-T2′` **deleted** this project's upstream entry, so **no plan
>   > role exists for it at all** when S1 runs, and F56 does not arise until S2-T0 re-creates
>   > one. This file's Risks section already said so at the "What is deferred, not broken"
>   > bullet — but `CLAUDE.md` establishes that **the banner wins** over a task body, so the
>   > repo's own precedence rule was selecting the *false* version. A banner that outranks the
>   > text must be corrected first, not last.
>   **Do not point it at
>   `secrets.AWS_OIDC_ROLE_ARN`** *(was `vars.` — namespace corrected 2026-08-08; **the
>   prohibition is about the ROLE, not the namespace**, and must not be read as spent because
>   the prefix changed)* — that is an apply-capable role on push to `main` with no
>   `environment:` gate, i.e. **F13 restored in the sprint that closes it**.
> - **F13 is now rated High, not Critical** (BR-D24) — on double-counting alone. That is a
>   severity correction, **not** a licence to deprioritise T5.

**Sprint Goal:** Stop `main` from applying to AWS unreviewed, make what applies be what was
planned, and turn the advisory scanners into real gates. At the end of this sprint, an
infrastructure change reaches AWS only after a PR, a plan a human read, and an explicit
Environment approval (BR-D2).

**Closes:** F13 (**High** — lowered from Critical by BR-D24 on double-counting; corrected here
2026-08-07 to match the inventory and this file's own banner, and it is **not** a licence to
deprioritise T5), F14, F15, F16, F18, F19, F20, F21.

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
- **`secrets.AWS_PLAN_ROLE_ARN` does not exist, and neither does the role it would name.**
  *(Was `vars.` — corrected 2026-08-08. **Both** the variable namespace and this specific
  value are absent now: `gh variable list` returns nothing at all, and the four values this
  repo does hold are secrets.)*
  ~~ST-T2 opts this project into `plan_role = true` upstream, so the *role* exists once ST is
  applied~~ — **false; corrected 2026-08-07 by ST-T5.** `ST-T2′` **deleted** this project's
  upstream entry, so after ST there is **no upstream role and no plan role for this project**;
  **S2-T0** re-creates both, two sprints after this one, and **S2-T2** sets the repository
  variable and switches over. *(This bullet contradicted the "Cross-repo dependency" bullet
  below it, which was corrected in the 2026-08-06 reshape while this one was missed.)*
  Until then Task 4's plan job uses the
  `secrets.AWS_PLAN_ROLE_ARN || secrets.AWS_OIDC_ROLE_ARN` fallback *(namespace corrected
  2026-08-08 — see banner)* with a `# S2-T2: drop the
  fallback` marker. **Do not invent a role ARN**, and do not create a role from this sprint —
  `bootstrap/` is out of scope here (BR-D1).
- The `production` Environment (Task 5) must be created in repo settings **with the owner as
  a required reviewer** before the first merge to `main` after this sprint, or the apply job
  will run without pausing and the sprint's main control is absent while appearing present.
  Confirmed absent as of 2026-08-05: `gh api repos/…/environments` returns `total_count: 0`.
- **~~Cross-repo dependency — now settled, and already handled upstream.~~ — FALSE AFTER ST's
  2026-08-06 RESHAPE. Corrected below; do not rely on the struck text.** It read: *"ST-T2
  already added `extra_oidc_subjects = ["environment:production"]` and `plan_role = true` to
  `global-bootstrap`'s `var.projects` entry for this repo, and a human applied it."*
  **None of that happens.** `ST-T2′` **deletes** this project's upstream entry outright (closing
  F45 by removing the dormant role rather than correcting it); **S2-T0 re-creates it, two
  sprints after this one.** So when S1 runs there is no upstream entry, no
  `extra_oidc_subjects`, and no plan role.
  - **What still works, and why — this is the load-bearing part.** Adding
    `environment: production` to the apply job changes its OIDC subject to
    `repo:…:environment:production` (the Environment takes precedence over the branch ref).
    This repo's **own** `github-actions-deploy-role` trusts, via `StringLike`, every entry in
    `var.github_oidc_subject_prefixes` rendered as `"${prefix}:*"` — a **glob**, which matches
    that subject just as it matches every other. So the gated apply **does** authenticate, on
    the local role. *(The variable was `var.github_repo_path` until **ST-T3** replaced it; the
    conclusion is unchanged, since every prefix still ends `:*`. But note the prefixes are now
    **ID-qualified** — `repo:<owner>@<org_id>/<repo>@<repo_id>` — so an `environment:production`
    subject must be reasoned about in that form, not the plain one.)*
    ⚠️ **S1 therefore depends on F2 — a finding — remaining open.** That is not a reason to
    close F2 early, and it is not a reason to relax about it: it means the sprint that narrows
    the trust policy to enumerated subjects (**S2**) must add `environment:production` in the
    *same* change, or the gated apply breaks at that moment instead of this one.
  - **What is deferred, not broken.** `secrets.AWS_PLAN_ROLE_ARN` still does not exist, so Task 4
    keeps the `secrets.AWS_PLAN_ROLE_ARN || secrets.AWS_OIDC_ROLE_ARN` fallback *(namespace corrected
  2026-08-08 — see banner)* and its
    `# S2-T2: drop the fallback` marker — unchanged, just for one sprint longer than planned.
    **F56 does not arise in S1** (it is a property of a plan role that does not exist yet), so
    `tofu-plan-main`'s blocked/unblocked decision moves to **S2-T0** with the rest of it.
    **The prohibition is unchanged and absolute: do not point any plan job at
    `secrets.AWS_OIDC_ROLE_ARN`** — that is F13 restored in the sprint that closes it. *(The
    namespace was corrected from `vars.` on 2026-08-08. **The prohibition names a ROLE, not a
    namespace** — it is not satisfied by moving the same apply-capable ARN to a different
    prefix.)*
- **The role ARNs this sprint references are still this repo's own**
  (`github-actions-deploy-role`) until **S2-T2** switches them to the upstream roles. Keep the
  `secrets.AWS_PLAN_ROLE_ARN || secrets.AWS_OIDC_ROLE_ARN` fallback *(namespace corrected
  2026-08-08 — see banner)* in Task 4 for exactly that
  reason; S2 removes it.
- ~~**`tofu plan` output cannot be trusted as a description of reality until S2-T1.** The state
  CI reads does not contain the deployed resources (**F39** — confirmed: no CI apply has ever
  succeeded). A plan job that goes green here proves the *job* works, not that the plan is
  accurate.~~ **STRUCK 2026-08-08 — F39 is CLOSED and this is now backwards.** `MW`-T5
  reconciled state (a from-scratch apply put all 12 declared resources into the state CI
  reads) and `MW`-T6 proved a full CI-driven `destroy → apply` cycle under the CI role. Plan
  output from `environments/ai-lab` **is** a description of reality, which is precisely what
  makes T4's and T5's summaries worth reading and T5's approval gate worth pausing for. This
  bullet was the single largest argument for sequencing `MW` ahead of S1; it has been paid.
- ~~Making `tofu-plan` a required check means **a fork PR can never go green** (forks get no
  OIDC token). Accepted — the alternative is a credentialed job reachable from fork-authored
  code.~~ **MOOT for `S1b` as of 2026-08-08** — `T4` is deferred to `S2`, so no required check
  here holds a credential and every one of them is satisfiable from a fork. **The trade is not
  resolved, only postponed**: it re-arms in `S2` the moment `tofu-plan` becomes required there,
  and the reasoning above is the reason it stays accepted when it does.

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
    > **⚠️ F18's `paths:`/`name:` removal on the DEPLOY workflow already happened in `S1a`
    > (T5).** Do not re-do it, and do not read its absence here as an oversight. What remains
    > for T2 is that **the two NEW files must be authored without either** — the rules below
    > are unchanged; only their status changed, from "a fix T2 performs" to "an invariant T2
    > must not regress."

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
    - `python-lint` — **added 2026-08-08; not a regression-free omission.** The live
      `deploy-ai-lab.yml` **already runs `ruff` and `bandit`** inside `security-and-linting`,
      and this plan's job list never mentioned them, so a literal reading of T2 would
      **delete a working control**. Carry the steps across as their own uncredentialed job.
      It is **not** in T7's required list: `.ai/project.yml` has no Python entry in
      `gates.green` and this repo still has no `pyproject.toml` or ruff config — S5 owns the
      toolchain, and requiring a check whose config does not exist yet is the S0 deadlock in
      miniature. Run it, do not gate on it.
    **`deploy.yml`** — ~~`on: pull_request:` (plan, Task 4),~~ `on: push: branches: [main]`
    (plan + apply, Task 5) **and `on: workflow_dispatch:` (destroy — see below)**.
    ~~No `paths:` filter on the `pull_request` trigger, for the same reason.~~
    `permissions: id-token: write, contents: read` at the workflow level.
    Nothing in either file may use `pull_request_target`.
    > 🛑 **CORRECTED 2026-08-08 by the post-`S1a` reassessment, and this is the line the whole
    > reshape turns on. `deploy.yml` GETS NO `pull_request` TRIGGER.** With `T4` deferred to
    > `S2`, nothing in `deploy.yml` runs on a PR — so this file's two triggers are `push` and
    > `workflow_dispatch`, full stop. **That is the point of doing `T2` at all this sprint:**
    > `ci.yml` is uncredentialed by construction, so the moment `deploy-ai-lab.yml` is deleted
    > this repo has **zero credentialed `pull_request` jobs for the first time in its history**
    > — retiring the `security-and-linting` surface that hands an admin-capable role to a
    > `pip install` from a PR branch. Adding the trigger back "for T4" while T4 lives in `S2`
    > un-does the sprint's largest single security gain in its first task. **`S2` adds the
    > trigger together with the read-only plan role that makes it safe** — the two arrive in the
    > same change, or neither does.

    ⚠️ **Two live controls this plan predates. Carrying them is a requirement of this task,
    not a nicety — both arrived with `MW` and both are proven.**
    - **`destroy-ai-lab`** — move it into `deploy.yml` **byte-identical**, including its
      `workflow_dispatch` input, its confirm-phrase `if:` (matched **entirely inside the
      `if:`**, never in a `run:`), and its `github.ref` check. **Do not add
      `environment: production` to it** — planning decision 2, see the banner. This is the
      job `MW` used to prove the destroy half of BR-D20's acceptance test.
    - **`Register bare account id for log masking`** — present in ~~all three~~ **all four**
      credentialed
      jobs today *(count corrected 2026-08-08: `S1a`-T5 split the fused job, so the live file
      carries it in `security-and-linting`, `tofu-plan-main`, `tofu-apply` and
      `destroy-ai-lab` — `security-and-linting` is the one `T2` deletes)*. It derives the bare
      12-digit account id from the role ARN and registers it
      as a log mask, so BR-D4 holds even when a tool prints it incidentally. **Every
      credentialed job in `deploy.yml` keeps it, and it must stay the first step after
      checkout** — a mask registered late does not retroactively scrub earlier output.
      ⚠️ **It must derive the account id from the SAME expression that job passes to
      `role-to-assume` — not from a hardcoded `secrets.AWS_OIDC_ROLE_ARN`.** ~~T4's plan job
      assumes `secrets.AWS_PLAN_ROLE_ARN || secrets.AWS_OIDC_ROLE_ARN`; the day S2-T2 creates
      the plan-role secret, a mask still pinned to the apply role masks **the wrong account**.~~
      **Rule unchanged; its example moved with `T4` (2026-08-08).** No job `T2` writes uses the
      `||` fallback any more — `tofu-plan-main` already carries the correct shape at
      `deploy-ai-lab.yml:154-164`, and **carrying that job across verbatim satisfies this
      bullet.** The hazard the struck example described is now **`S2`'s to avoid**, at the
      moment it creates the plan job *and* the plan-role secret: a mask still pinned to the
      apply role would mask **the wrong account**.
      There is no error and no failing check — the account id simply starts appearing in a
      world-readable log on a public repo. Keep the expression in one job-level `env:` var and
      reference it from both places.
  - **Target Files:** `.github/workflows/ci.yml`, `.github/workflows/deploy.yml`,
    `.github/workflows/deploy-ai-lab.yml` (deleted), `.tflint.hcl`
  - **Acceptance Criteria:** `deploy-ai-lab.yml` no longer exists. No workflow file contains
    a `paths:` key. ~~No job in `ci.yml` or `deploy.yml` has a `name:` key.~~ **Corrected
    2026-08-08 — as written this contradicts the "carry `destroy-ai-lab` byte-identical"
    requirement above, and one of the two had to yield.** The live `destroy-ai-lab` job DOES
    carry `name: Destroy AI Lab Infrastructure (manual)` (`deploy-ai-lab.yml:323`), which is
    **correct and stays**: F18's rule is that a `name:` override silently un-requires a *gated*
    job by renaming its check run, and `destroy-ai-lab` is `workflow_dispatch`-only — it can
    never be a required check, so the rule does not bind it and the human-readable name is worth
    having in the dispatch UI. **Criterion, restated: no job that is or could become a required
    check carries a `name:` key** — i.e. every job in `ci.yml`, and `tofu-plan-main`/`tofu-apply`
    in `deploy.yml`. `destroy-ai-lab` is the one deliberate exception; **`T7` must not add it to
    `required_checks`.** `deploy.yml` has **no `pull_request` trigger** (see the corrected
    trigger list above). Every job id is
    lower-case-hyphenated and unique across both files. `tflint --recursive` exits 0 locally.
    **`deploy.yml` contains a `destroy-ai-lab` job whose `if:` is byte-identical to the
    pre-split version — diff it, do not eyeball it.** Every credentialed job in `deploy.yml`
    registers the account-id mask immediately after checkout. `ruff` and `bandit` still run
    on a PR.

- **Task 3: Full-coverage IaC and workflow scanning**
  - **Description:** Add ~~four~~ **three** scanner jobs to `ci.yml` — `checkov`,
    `secrets-scan`, `zizmor`. *(The count said four until 2026-08-08 and contradicted this
    task's own closing line; `iac-diff-guard` was CUT by BR-D23 and its replacement is already
    shipped in the PR template. **Separately: `checkov` is RUN here but NOT made required by
    `T7`** — it fires on `S3`'s F6/F7, so `S3` requires it in the change that closes them. See
    the top banner.)* The coverage gap is the finding
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
      > **✅ RESOLVED 2026-08-08 by measurement — take option (a), and nothing further is
      > owed.** `gh secret list --org glunk-works` returns `GITLEAKS_LICENSE` with visibility
      > `ALL`, so this repo **already inherits it**; reference it as `secrets.GITLEAKS_LICENSE`
      > and no repo-level secret is created. **The second-order paragraph below is therefore
      > void** — this repo acquires no new secret, so there is no BR-D21 exception to record.
      > *(Separately, its premise expired anyway: `MW`-T6 established that this repo already
      > holds four `secrets.*` values, so `GITLEAKS_LICENSE` would not have been "the first."
      > The warning is retained because it is the reasoning that made someone run the check,
      > and the deadlock it describes was real until that command returned.)*
      ~~**Second-order, and it needs recording:** this makes `GITLEAKS_LICENSE` **this repo's
      first genuine secret**, and BR-D21's SSM pattern cannot serve a workflow `env:` value
      without an AWS round-trip inside CI. **Record the BR-D21 exception for
      Actions-consumed secrets** — § 9.5 names `GITLEAKS_LICENSE` as one of bounty-infra's
      genuinely-secret values and never noticed this repo was about to acquire one.~~
      Do not add a
      `pull-requests: write` permission for its comment feature; the action logs a warning
      and continues without it, and the check's verdict comes from the scan.
    - `zizmor` — `zizmorcore/zizmor-action`, job-scoped
      `permissions: {contents: read, security-events: write}`. Do **not** hoist
      `security-events: write` to the workflow level; it is the only job that needs it.
    - ~~`iac-diff-guard` — a plain `run:` step that fails the PR if the diff touches
      `bootstrap/` without the PR body containing the line
      `Blast radius: changes what CI may do in AWS`. `bootstrap/` defines the OIDC trust
      policy and the deploy role's permissions; a change there must be a deliberate,
      declared act. Read the body from `env:`, never inline `${{ }}` into the script.~~
      **CUT by BR-D23 (2026-08-05), and its replacement is ALREADY SHIPPED — verified
      2026-08-08: `.github/PULL_REQUEST_TEMPLATE.md` carries a `Blast radius` section.
      There is nothing to write for this bullet. Do not add the job.** This task is
      **three** scanner jobs.
  - **Target Files:** `.github/workflows/ci.yml`, `.gitleaks.toml`, `.checkov.yml` (only if
    a suppression is genuinely needed)
  - **Acceptance Criteria:** Checkov's log shows it scanned files under `bootstrap/`,
    `modules/` **and** `environments/`. ~~All four jobs~~ **All three jobs** report on this
    sprint's PR — **reporting, not gating: only `secrets-scan` and `zizmor` of these three
    become required checks in `T7`.** If Checkov
    fails on a real finding, **do not suppress it** — record it as a new `F` row in
    `docs/hardening_roadmap.md` mapped to the sprint that owns it (most will already be
    F6–F12, owned by S3) and add a justified `.checkov.yml` skip citing that row.

- **Task 4: PR plan — read-only, summarized, never dumped**
  - > ## 🛑 DEFERRED TO `S2` (2026-08-08 reassessment — see the top banner). DO NOT EXECUTE FROM HERE.
    >
    > **The body below is retained verbatim as the normative specification `S2` inherits**, in
    > the same shape `ST` Task 2b is retained for `S2`-T0: the design is correct, its
    > *precondition* is not met yet. Executing it in `S1b` would put an **apply-capable**
    > credential back on a `pull_request` trigger — the exact surface `T2` deletes two tasks
    > earlier — because `secrets.AWS_PLAN_ROLE_ARN` and the role behind it do not exist until
    > `S2`-T0. **F16 is already closed by `S1a`-T5**, so nothing open is left uncovered by
    > waiting. When `S2` runs this, the `secrets.AWS_PLAN_ROLE_ARN || secrets.AWS_OIDC_ROLE_ARN`
    > fallback in step 2 is **written as the plan role outright** — the fallback existed only to
    > let S1 ship before the role did, and that reason is gone.
  - **Description:** In `deploy.yml`, a `tofu-plan` job on `pull_request`:
    1. `actions/checkout` with `persist-credentials: false`
    2. `aws-actions/configure-aws-credentials` with
       `role-to-assume: ${{ secrets.AWS_PLAN_ROLE_ARN || secrets.AWS_OIDC_ROLE_ARN }}` and a
       comment `# S2-T2: drop the fallback once the upstream plan role is adopted`
       *(**corrected 2026-08-08**: was `vars.*`, which no longer exists in this repo — see the
       re-planning banner. `secrets.AWS_PLAN_ROLE_ARN` is not set today, so the `||` falls
       through to the apply-capable role exactly as the original design intended; S2-T2 flips
       it by **creating the secret**, with no workflow edit.)*
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
    ⚠️ **This task IS slice `S1a`, and it ships alone** (see the re-planning banner). It lands
    against the existing `deploy-ai-lab.yml` — `deploy.yml` does not exist yet. T2 later moves
    these jobs into `deploy.yml` unchanged.

    **Two things must happen inside this task that the original plan assigned elsewhere. Both
    are prerequisites for the gate meaning anything, not tidying.**

    1. **Split `opentofu-pipeline` into `tofu-plan-main` → `tofu-apply`.** Today it plans *and*
       applies in **one** job, and **an Environment approval fires when a job STARTS** — so
       bolting `environment: production` onto the fused job requests approval **before any plan
       has run**, leaving the approver nothing to read. The split is what converts the gate from
       a pause into a decision.
    2. **🔴 Delete the `paths:` filter and both `name:` overrides NOW — moved here from T2.**
       This is the finding that reversed the sprint order, and it is measured, not reasoned:
       `deploy-ai-lab.yml` filters on `paths: ['environments/ai-lab/**', 'modules/**']`, and
       **every S1 task edits only `.github/workflows/`, `.tflint.hcl` and `.ai/project.yml`** —
       none of which match. **So merging T5 would not trigger the workflow T5 just modified.**
       The gate would land, claim to exist, and never once run. **Proof from this repo's own
       history:** commit `8f51501` — *"ci(ai-lab): touch to trigger MW-T6 rebuild apply"* — had
       to touch `environments/ai-lab/main.tf` for exactly this reason during `MW`.
       Leaving the filter for T2 would mean the sprint's central control sits **unexercised for
       its longest window**, which is precisely the failure the Critical review warns of: *a
       missing Environment produces no error, just no pause.*
       *(The `name:` overrides come off in the same change under the same F18 rule — the
       check-run name is the job id, and both job ids change here anyway.)*

    **Known and accepted consequence:** with `paths:` gone, **every** later merge — including
    docs-only and workflow-only ones — triggers `tofu-plan-main` + `tofu-apply` and queues an
    approval (`cancel-in-progress: false` means they queue, never cancel). Across `S1b` that is
    roughly six extra approvals, nearly all of them no-op applies. **This is a feature, not a
    tax:** it exercises the gate on every single merge instead of once at the end.

    - **`tofu-apply`** — `needs: [tofu-plan-main]`, `environment: production`. Assumes
      `secrets.AWS_OIDC_ROLE_ARN` *(**corrected 2026-08-08** from `vars.` — see banner)*.
      Runs `tofu init`, then
      `tofu plan -input=false -lock-timeout=5m -out=tfplan`, prints the same jq summary, then
      `tofu apply -input=false -auto-approve tfplan` — **applying the saved plan file, not
      re-planning** (F14). `-auto-approve` is permitted here and only here, because the
      Environment approval already happened (BR-D2).
    Then create the Environment in repo settings:
    ```bash
    gh api -X PUT repos/glunk-works/bedrock-serverless-rag/environments/production \
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
  - **Acceptance Criteria:** `gh api repos/glunk-works/bedrock-serverless-rag/environments/production`
    shows a `required_reviewers` protection rule naming a real user and
    `deployment_branch_policy.protected_branches: true`. On the merge of this sprint's PR,
    the `tofu-apply` job reports `waiting` for approval, and the `tofu-plan-main` summary is
    readable before approving. `grep -c 'auto-approve' .github/workflows/deploy-ai-lab.yml`
    returns exactly 1, on the line that applies a plan file. *(**File name corrected
    2026-08-08**: this criterion said `deploy.yml`, which is right for the original ordering
    and **wrong now that T5 ships first** — `deploy.yml` does not exist during `S1a`. T2
    re-points it when it moves these jobs.)*
    **Added, and this is the criterion that actually matters:** the `paths:` key is gone from
    both triggers, neither job carries a `name:`, and **the pause was observed on this task's
    own merge** — not inferred from the YAML. A workflow-only merge must be sufficient to
    trigger it; if it is not, the `paths:` removal did not land and the gate is decorative.

- **Task 6: Purge every raw-output path**
  - **Description:** Sweep both workflow files for BR-D4 violations beyond Task 4's plan
    step: no `set -x`, no `env` dump, no `aws sts get-caller-identity` echo, no
    `tofu output` without `-json | jq` selecting named fields, no `tofu show` of state. Add
    `set -euo pipefail` to the top of every multi-line `run:` block. Confirm no `${{ }}`
    appears inside any `run:` block **or any `actions/github-script` `script:` block** anywhere
    in the repo — pass values through `env:` and read them as `process.env.X`.
  - **Target Files:** `.github/workflows/ci.yml`, `.github/workflows/deploy.yml`
  - **Acceptance Criteria:** `grep -n '\${{' .github/workflows/*.yml` shows matches only in
    `env:`, `with:`, `if:`, `uses:` and `concurrency:` positions — never inside a `run:`
    block. Every `run: |` block's first line is `set -euo pipefail`.
    **⚠️ That grep is NOT sufficient on its own, and the gap is exploitable.** A
    `actions/github-script` step's payload sits under `with:` → `script:`, so the criterion as
    written **passes** a step containing `${{ github.event.pull_request.body }}` — an attacker
    -controlled string interpolated straight into a JavaScript context, which is
    `run:`-equivalent for injection. **Add a second, explicit check:**
    `grep -n -A20 'uses:.*actions/github-script' .github/workflows/*.yml` must show **no
    `${{ }}` inside any `script:` body**. Also treat `${{ }}` in an `if:` as suspect rather
    than safe-by-position whenever the expression embeds attacker-controlled text (a PR title,
    a branch name, an issue body) — the rule is about the value's provenance, not its position.
    **Whether `zizmor` (S1-T3) catches the `github-script` case is not assumed here** —
    confirm it against a deliberately-planted test case before relying on it instead of the
    grep, and record which one is the control.

- **Task 7: Update the drift detector and the schema**
  - **Description:** Append this sprint's new gating checks to the ruleset, to
    `ruleset.required_checks` in `.ai/project.yml`, and to the check list inside
    `.github/workflows/ruleset-drift.yml` — **all three in this PR** (BR-D9). ~~The checks
    added by S1 are: `tofu-fmt`, `tofu-validate`, `tflint`, `checkov`, `secrets-scan`,
    `zizmor`, `tofu-plan`.~~ **Corrected 2026-08-08 by the post-`S1a` reassessment — the checks
    added by `S1b` are FIVE:** `tofu-fmt`, `tofu-validate`, `tflint`, `secrets-scan`, `zizmor`.
    **`tofu-plan` is not among them because `T4` is deferred to `S2`**, and **`checkov` is not
    among them because it fires on `S3`'s findings** — `S3` adds it in the change that closes
    them. Both are in the top banner; the literal list is corrected here because this one gets
    pasted. Append to the existing ruleset with a `PUT`, never replace it:
    ```bash
    gh api repos/glunk-works/bedrock-serverless-rag/rulesets --jq '.[].id'
    gh api -X PUT repos/glunk-works/bedrock-serverless-rag/rulesets/<id> --input updated.json
    ```
    Read the current ruleset first and edit it; a `PUT` with a partial body drops the rules
    it omits, which would silently delete S0's work.
    Do **not** add `iac-diff-guard` as a required check — it is a policy assertion about the
    PR body, and a required check that a fork or a bot cannot satisfy strands PRs.
  - **Target Files:** `.ai/project.yml`, `.github/workflows/ruleset-drift.yml`
  - **Acceptance Criteria:** `gh api repos/glunk-works/bedrock-serverless-rag/rules/branches/main`
    lists ~~8~~ **6** contexts (`pr-title` + the ~~seven~~ **five** above) and still all four
    rule types. *(Count corrected 2026-08-08 with the list above — `tofu-plan` deferred to `S2`,
    `checkov` to `S3`.)*
    ~~`.ai/project.yml` lists the same 8 in the same order.~~ **Corrected 2026-08-08 — the
    three lists must be equal as SETS, not as ordered sequences.** GitHub returns ruleset
    contexts in its own order and does not preserve the order they were `PUT` in, so an
    order-sensitive criterion fails on a repo that is correctly configured and sends someone
    hunting a bug that is not there. Compare sorted: e.g.
    `diff <(… | jq -r '.[]' | sort) <(… | sort)`. `gh workflow run ruleset-drift.yml` passes.
    **Diff them, do not eyeball them** — that part stands.

    ✅ **VOID as of the 2026-08-08 reassessment — and it is void because the reshape was made
    to void it, so read it as the reasoning rather than as a live risk.** With `T4` deferred to
    `S2`, no required check runs on `pull_request` holding credentials of any kind, so F2 is
    **not** load-bearing for merging in `S1b`. The paragraph below is the argument that moved
    `T4`; it re-arms verbatim in `S2` **unless** `S2`-T2's narrowed trust policy lands in or
    before the same change that makes `tofu-plan` required. Keep it with `T4`.
    ~~⚠️ **One consequence of this task to record rather than discover: it makes F2 load-bearing
    for merging.**~~ `tofu-plan` runs on `pull_request` holding **apply-capable** credentials
    (no plan role exists until S2-T0), and F2 — the trust policy's trailing `:*` admitting
    `:pull_request` — stays open until S2-T2. Making that job **required** does not create new
    exposure, since it already runs on every PR; it makes the exposure **impossible to merge
    without**, so if S2 slips, switching it off costs a ruleset edit rather than a workflow
    edit. Accepted, consistent with the sprint's existing acceptance of F2 — but the original
    plan noted that S1 *depends* on F2 staying open without noting that S1 also raises the
    price of it staying open.

---

## Definition of Done

`gates.green` passes. Every check in `ruleset.required_checks` is green on the sprint's own
PR. The apply job has been observed **pausing** for approval at least once.
`/way-of-working:critic-gate` has run — propose `security-critic` (this diff is entirely trust-boundary and
credential-handling) and `architect` (the required-check ordering and the plan/apply job
split are where a logic error hides). The green gate and the CI checks are not the same
thing and both must pass.

**⚠️ Revised 2026-08-08 — there are now TWO Definitions of Done, one per slice. Do not apply
`S1b`'s to `S1a`; the whole point of the split is that `S1a` ships without waiting for them.**

**`S1a` (T5) is DONE when:** `gates.green` passes; `pr-title` is green on its PR; the
`production` Environment exists with a real required reviewer; and — the criterion that
carries the weight — **the `tofu-apply` job was OBSERVED pausing for approval on this task's
own merge**, with `tofu-plan-main`'s summary readable beforehand. Not "the YAML says
`environment:`": a missing or reviewer-less Environment produces **no error at all**, just no
pause, so only an observed pause distinguishes a working gate from a decorative one.
`/way-of-working:critic-gate` has run (this diff is `.github/workflows/`, i.e. `code_paths`).
**`S1a` does NOT require the `MW` re-run** — T5 edits `deploy-ai-lab.yml` in place rather than
replacing it, so `MW`'s proof still describes the shipped file, and the observed pause is
stronger evidence than a destroy/rebuild would be for this specific change. **Then stop and
reassess before `S1b`.**

**`S1b` (~~T2, T1, T4, T3, T6, T7~~ **T2, T1, T3, T6, T7** — `T4` deferred to `S2`,
2026-08-08 reassessment) is DONE when** everything in the paragraph above this one
holds, **plus `MW`'s acceptance test has been re-run ONCE at the end, against the final
shape:** dispatch `destroy-ai-lab` with the confirm phrase, let it complete, then merge a
trivial change to `main` and take the `tofu-apply` Environment approval — the full
`destroy → apply → verify` cycle of BR-D20, human-watched. **Why this is a DoD item and not
optional polish:** T2 **deletes the workflow file `MW` proved**, so from that commit until this
run, `MW`'s evidence describes a file that no longer exists and **nothing** demonstrates the
shipped pipeline can stand the system up. It runs last because the end state — split files,
Environment gate, saved-plan apply, ~~seven~~ **five** required checks *(corrected 2026-08-08 —
`tofu-plan` deferred to `S2`, `checkov` to `S3`; see the top banner)* — is the only configuration that
exercises the gate *and* the split together, which is where a logic error would hide.
*Expect the AOSS collection alone to take ~11 minutes on the rebuild; per the `MW` lesson,
**check which step is actually slow before reading elapsed time as stuck** — that misread
caused a premature cancellation during `MW`-T6.*

**⚠️ `/way-of-working:critic-gate` is not optional on this sprint, and the reason is
specific.** No critic-gate pass ran on **any** of `MW`'s four PRs, two of which widened
`bootstrap/` IAM permissions. This repo has **no CI review gate** (`review.ci_gate` is `null`
by BR-D14), so critic-gate is the *only* critic look a diff gets before the merge click — and
every task here touches `code_paths`.

---

## Critical review

**Security**

- *The apply role is still the F1 escalation-capable role at the end of this sprint.* True,
  and it is why the Environment gate is not optional dressing: for the duration between S1
  and S2, a human approval is the **only** control between a merge and an admin-capable
  apply. Stated in Security Considerations so no one reads the split-role structure and
  assumes S2 already happened.
- *Task 4's plan job still holds credentials on a `pull_request` trigger.* **⚠️ This objection
  was ACCEPTED rather than answered, 2026-08-08 — it is why `T4` moved to `S2`.** The bullet
  below "bounds" the exposure and then keeps it; the reassessment found the bound was
  unnecessary, because `T2` removes the last credentialed PR job anyway and `T4` was the only
  thing putting one back. **It is retained unstruck because every word of it re-arms in `S2`,
  where the job actually gets built** — and there the second sentence finally becomes false in
  the right direction: the credentials will be the *read-only plan role*, not the mutating one.
  *(Original:)* Yes, and until
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
- *Ordering inside the sprint.* ~~Task 2 deletes the file Tasks 4 and 5 write into, so it must
  land first;~~ Task 7 must land **last**, because requiring a check before its job exists is
  the S0 deadlock again, one sprint later. ~~Tasks 1, 3, 6 are order-independent.~~
  > **⚠️ REVISED THREE TIMES ON 2026-08-08. Final: the sprint is SPLIT — `S1a` = T5 alone,
  > then `S1b` = ~~T2 → T1 → T4 → T3 → T6 → T7~~ **T2 → T1 → T3 → T6 → T7**.** *(The third
  > revision is the post-`S1a` reassessment in the top banner, and unlike the first two it was
  > found by **execution** rather than by critique: shipping `S1a` is what made it visible that
  > `T2` leaves the repo with zero credentialed `pull_request` jobs and `T4` puts one back.)* *(The intermediate revision read
  > "T5 → T1 → T2 → T4 → T3 → T6 → T7" as one sprint. Two defects, both found by critique
  > rather than by execution: **(a)** it put **T1 before T2**, i.e. SHA-pinned the actions in
  > `deploy-ai-lab.yml` and then had T2 delete that very file — wasted work whose only product
  > is a merge conflict; **(b)** it left the `paths:` filter with T2, which would have made
  > T5's gate **untriggerable by any S1 merge** and so unverifiable for the whole sprint. The
  > `paths:` removal moved into T5.)* The struck clause below had it backwards for a reason
  > that did not exist when it was written.** The premise was "T2 deletes the file T4 and T5
  > write into." True —
  > but **T5 does not have to write into `deploy.yml`; it can write into
  > `deploy-ai-lab.yml`**, which is the file `MW` proved works. Landing the Environment gate
  > there **first** closes F13 — the sprint's centrepiece and the only control between a merge
  > and an admin-capable apply — as a ~15-line diff over proven-working code, instead of
  > leaving it open until after a wholesale rewrite of the repo's only path to AWS. T2 then
  > moves two already-working jobs rather than authoring two new ones. **T4 still follows T2**
  > (its `tofu-plan` job is new and belongs in `deploy.yml`), and **T7 is still last**.
  > The cost is editing the deploy workflow twice; the benefit is that the sprint's highest-value
  > control is live from its first merge rather than its last. *(Note the ordering constraint
  > inside T5 itself, stated in its body: `opentofu-pipeline` currently plans **and** applies
  > in one job, and an Environment approval fires when a job **starts** — so T5 must split
  > that job in two, or the approver is asked to approve before any plan has run.)*
- *`tofu-validate` covering `bootstrap/` looks like it contradicts BR-D1.* It does not.
  BR-D1 says CI never **applies** `bootstrap/`. Validating and scanning it is the opposite
  of a violation — F1 and F2 have gone unscanned precisely because nothing looked.
- *`strict_required_status_checks_policy` (from S0) plus ~~seven~~ **five** new checks means more
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
