# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**SHIPPED, NOT MERGED — awaiting an adversarial review pass (see the section below).**

**S0 (governance and repository baseline) is the active frontier** — `planning`. The plan is
**written and critically reviewed**; nothing in it has been executed. The next pass is
**implementation**, and it changes live GitHub state (a ruleset, merge settings, labels), so
it wants **Sonnet / coder** — with the human present for the three tasks `git revert` cannot
undo.

⚠️ **Sequencing fact that must not be lost:** S0-T4 (`pr-title` workflow) must **merge
before** S0-T1 (the ruleset) executes. Requiring a check whose workflow does not exist leaves
every PR permanently pending — including the PR that would add the workflow. BR-D9,
roadmap § 6.

**Sprint order is now:** `S0` → `ST` (org transfer) → `S1` → `S2` → `S3` → `S4` → `S5` → `S6`,
with `SD` (devcontainer) in parallel from any point after S0.


## ⚠ READ FIRST IF YOU ARE THE ADVERSARIAL REVIEWER

This PR is **shipped but deliberately NOT merged**. The operator is running a cold-context
critic pass over the *plan itself* before merge. Adopt **Opus / architect**.

**What is under review is not a code diff.** It is a plan: 54 findings, 21 decisions, nine
sprint plans, ~3 000 lines of prose that a Sonnet coder is expected to execute
unambiguously. `/critic-gate` will propose thin critics because `code_paths` are barely
touched — **override that.** The useful angles here are `architect` (ordering, logic,
proportionality), `security-critic` (the IAM constructions and trust boundaries), and
`docs-consistency` (this document set was surgically edited four times and contradictions are
likely).

### Where the author believes this plan is most likely WRONG

Written by the session that produced it, on the way out. Treat as leads, not as a scope
limit — the value of a cold read is finding what this list does not contain.

1. **Unverified AWS API surface.** Several sprint tasks name resources, fields and enum
   values that were **never validated against a provider schema or live API**:
   `aws_bedrock_guardrail`'s `content_policy_config` / `PROMPT_ATTACK` /
   `sensitive_information_policy_config`, `aws_bedrock_guardrail_version`,
   `aws_bedrock_model_invocation_logging_configuration`,
   `vector_ingestion_configuration.chunking_configuration`,
   `s3_configuration.inclusion_prefixes`, and — flagged as uncertain in the text itself —
   `aws_opensearchserverless_account_settings` ("or equivalent"). A Sonnet coder will type
   these verbatim. **Highest-value target: check each against the AWS provider docs.**
2. **The escalation-proof claim (ST-T2 / the F41 issue).** The plan asserts that a
   permissions boundary + role-path scope + `iam:PermissionsBoundary` condition + a named
   `Deny` list makes privilege escalation structurally impossible. That is exactly the kind
   of claim that is wrong in one unlisted verb. Specifically probe: `iam:CreatePolicy` (only
   `CreatePolicyVersion` is denied), `iam:UpdateRole`/`UpdateAssumeRolePolicy` on an
   in-path role, `iam:TagRole` where any ABAC condition exists, `sts:AssumeRole` chaining,
   service-linked-role creation, and whether the boundary policy itself is reachable.
3. **Proportionality.** BR-D20 says this is a disposable personal lab with an empty corpus.
   The plan is nine sprints and 54 findings. **Is that defensible, or is it the failure mode
   where a thorough audit becomes its own justification?** A credible critic should be
   willing to argue for deleting sprints, not only for tightening them. Which of S3–S6 would
   actually change the risk picture, and which are ceremony?
4. **Ordering claims stated with more confidence than they were verified.** "ST must precede
   S1 because repository variables do not survive a transfer" — the plan *asserts* this in a
   dependency line and then *tells the coder to verify it* in ST-T4. Those cannot both be
   right. Same pattern for what else survives a transfer (rulesets, environments, labels).
5. **Copy-paste commands.** The S0-T1 ruleset JSON (`~DEFAULT_BRANCH`, `bypass_actors: []`,
   the `pull_request` parameter set), the S1-T5 environments `PUT` payload, and the
   `gh api -X PATCH` merge-settings flags were written from knowledge, **not executed**.
   Any one being wrong strands a coder in a 422 that reads like a permissions problem.
6. **Severity calibration after two re-rankings.** Findings were re-scored twice (BR-D20,
   then the pilot decision). Is F47 (shared-account blast radius) really *below* F1, when it
   is the reason F1 matters? Is F51 (the project cannot do its one job) really only High?
7. **Residual contradictions.** The reversals were applied by targeted text replacement
   across ten files. `docs-consistency` should assume something was missed — particularly
   between a sprint's *header* (goal, dependencies, closes-list) and its *task bodies*, which
   were edited separately.
8. **`required_approving_review_count: 0`.** Justified as unavoidable on a solo-owner repo.
   Is it? Challenge whether CODEOWNERS, a bypass actor, or simply accepting the friction
   would be better, and whether "0 approvals" quietly makes the `pull_request` rule weaker
   than the plan implies.

### What is solid, and should not be re-litigated without new evidence

Verified against live systems this session, not inferred:

- **F17** — no ruleset (`[]`) *and* `branches/main/protection` 404, read as repo admin.
- **F33** — `squash_merge_commit_title` is `COMMIT_OR_PR_TITLE`; `delete_branch_on_merge` false.
- **F39 / F51** — **14 workflow runs total, zero successful `push`-to-`main` runs, ever.**
  Read from the API with `total_count`, not sampled.
- **F5 / F46** — run `26788807269`: six consecutive `AuthorizationException(403)` from
  `create_index.py`, and `EntityAlreadyExists` on the KB role.
- **F40** — guard merged (PR #17) and *observed* refusing a targeted destroy plan.
- **F50** — `tofu plan` in `bootstrap/` reports `1 to change`, removing
  `iam:ListAttachedRolePolicies`.
- **F52** — the Infisical secret was verified absent from all of `git log --all
  --full-history`, including a content search; identity since revoked.

## What this session established

- **Adopted the `way-of-working` plugin.** `.claude/settings.json` pins
  `glunk-works/claude-workbench@v0.3.0`; `.ai/project.yml` parameterizes it against this repo
  **as it actually is**, including two deliberate `null`s (`ruleset`, `review.ci_gate`) and no
  Python entry in `gates.green`, because none of those exist yet. All three gate entries
  verified green on a clean checkout.
- **`CLAUDE.md`** as a lean routing layer — local truth only.
- **`docs/hardening_roadmap.md`** — the evaluation: **54 findings** (4 Critical, 17 High,
  19 Medium, 15 Low; two closed), a threat model with five trust boundaries,
  **BR-D1..BR-D21**, and a full cross-repo analysis of `glunk-works/global-bootstrap` (§ 9),
  including § 9.5 — this repo as the org's secrets-migration pilot.
- **Nine sprint plans** (S0–S6, SD, ST), each carrying its own **Critical review** section.

**Almost nothing has been implemented, deliberately.** The two exceptions are both out-of-band
safety work, not sprint work: **PR #17** (merged, `1ad5aa7`) added `prevent_destroy` to the
org-shared OIDC provider, and the Infisical machine identity was **revoked** with its keys
stripped from `.env` (F52). No sprint has started; no other `.tf` file, workflow, or GitHub
setting has changed.

## The findings that set the priority

**Confirmed by evidence, not inferred** — CI run `26788807269` (the last push to `main`):

1. **F39 (Medium — downgraded by BR-D20; the *evidence* is unchanged, the *stakes* are not)**
   — **the state CI reads does not describe the deployed system.** The run
   fails `EntityAlreadyExists: Role with name personal-bedrock-kb-execution-role already
   exists` and a stalled S3 bucket create. The resources exist in AWS, created out-of-band
   with human credentials; CI's state does not contain them. **No CI apply has ever
   succeeded.** Consequence: `tofu plan` output is not a description of reality, which
   invalidates the plan-reads-as-acceptance-criterion used throughout S3 and S4 until
   **S2-T1** reconciles by import (BR-D19).
2. **F5 (High, confirmed)** — the same run shows `create_index.py` failing
   `AuthorizationException(403, '')` six times. The AOSS data-access policy names
   `data.aws_arn.current_identity.arn`, which resolved to a **human SSO session** at apply
   time, so the CI role has no data-plane access at all. This is *why* the pipeline has never
   worked. → **S2-T6**.
3. **F46 (Medium)** — that 403 can never resolve by waiting, but the retry loop treats it as
   propagation delay, and commit `0aa56dc` raised the delay to 45 s — so CI spends ~12 minutes
   failing. **The most recent work on this repo tuned the wrong variable.** → S4-T4.

**Structural, still true:**

4. **F17 (Critical)** — `main` has no branch protection at all; every gate is advisory. → S0.
5. **F13 (Critical)** — `tofu apply -auto-approve` on every push, no approval. → S1-T5.
6. **F1 (Critical) + F47 (High)** — the CI role can create IAM roles/policies on
   `Resource: "*"`, **in an account shared with the whole organization** — one that also holds
   bounty-infra's KMS-encrypted findings archive. → S2-T2, and upstream.

## The two answers given, and what they changed

The operator confirmed **one shared AWS account** and **the repo transfers to `glunk-works`**.

- **BR-D17 resolved:** `global-bootstrap` owns identity and state; this repo owns its workload
  and nothing else. **S2 was re-scoped from hardening `bootstrap/` to retiring it.** The
  permissions-boundary construction did not vanish — it moved upstream, into ST-T2 and the
  F41 issue.
- **New sprint ST**, between S0 and S1, performs the transfer. It exists as its own sprint
  because of **F45**: the moment the repo becomes `glunk-works/bedrock-serverless-rag`, the
  dormant `github-actions-bedrock-serverless-rag` role becomes assumable — and it carries
  `lambda:*`, `apigateway:*` and `iam:CreateRole` on `*`. **A settings change, with no IaC
  diff anywhere, would open a new path to account administrator.** ST-T2 (the upstream policy
  fix) must therefore land *before* ST-T3 (the transfer).
- **BR-D18:** the OIDC provider moves to `global-bootstrap`'s ownership. Today this repo
  *creates* what the org's foundation *reads*, so a `tofu destroy` here is an org-wide CI
  outage (F40). **ST-T1 is the one-line `prevent_destroy` stopgap and depends on nothing —
  it is the highest value-per-line change in the whole roadmap.**
- **S3-T3 superseded** by S2-T4 (state migrates to the org backend). **S6-T4 shrinks** to a
  confirmation pass.

## Next — execute S0

Order within the sprint, which is **not** the order the tasks are numbered in:

1. **T4** — `pr-title` workflow. **Merge this first.**
2. **T5** — baseline files (`.gitattributes`, CODEOWNERS, PR template, SECURITY.md,
   dependabot).
3. **T3** — label + issue-template taxonomy migration (rename, never delete-and-recreate).
4. **T2** — merge settings (`squash_merge_commit_title=PR_TITLE` is the load-bearing one).
5. **T1** — the ruleset, requiring `pr-title` **only**, plus the matching `.ai/project.yml`
   update in the same PR.
6. **T6** — ruleset-drift detector, and **observe it go red** against a deliberately deleted
   ruleset before calling it done.

Then **ST**, whose own internal order is: T1 (`prevent_destroy`) → T2 (upstream policy fix,
applied) → T3 (widen, transfer, narrow) → T4 (restore settings) → T5 (record).

## Open — worth doing out of band

**ST-T1's `prevent_destroy` on the OIDC provider does not need to wait for its sprint.** One
line, human-applied, against a standing organization-wide outage risk. Everything else can
proceed at sprint pace.

## Still-open operator gates (a coder cannot do these)

- `tofu apply` in `bootstrap/` — human, admin SSO, never CI (BR-D1). ST and S2 both need it.
- A `tofu apply` of **`glunk-works/global-bootstrap`** — ST-T2, S2-T3.
- The **repository transfer** itself — org-owner permission, irreversible in practice (ST-T3).
- Creating the `production` Environment with a required reviewer (S1-T5).
- Docker on the workstation, without which SD can only be written, not verified.

## Pointers

- `docs/hardening_roadmap.md` — reference of record **and** threat model: F1–F47,
  BR-D1–BR-D19, the sprint sequence, the required-check ordering rule (§ 6), the nomenclature
  and label taxonomy (§ 7), the `global-bootstrap` coupling (§ 9).
- `sprints/S0_governance_baseline/sprint_plan.md` — the sprint to execute next.
- `sprints/ST_org_transfer/sprint_plan.md` — the one with the ordering constraint that
  matters.
- `.ai/project.yml` — this repo's parameterization; two `null`s are decisions, not gaps.
