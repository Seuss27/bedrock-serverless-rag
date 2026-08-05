### FILEPATH: /sprints/S6_docs_operational_readiness/sprint_plan.md

# S6 — Documentation and operational readiness

**Sprint Goal:** Make the repo's prose true again, give the system the operational documents
it has never had (runbooks, cost control, teardown), and close the two open governance
questions.

**Closes:** issue #8, BR-D13. Adds README.md to `load_bearing_docs`.

**Dependencies:** **S1–S5 merged.** A README rewritten before the architecture stops changing
is a README that needs rewriting again — which is how #8 came to exist.

**Security Considerations:** Documentation is a disclosure surface. This repo is public, so
every runbook, every example, and every screenshot is world-readable. The account id, role
ARNs, the state bucket name, the collection endpoint, and any corpus content are BR-D4
restricted and must appear as placeholders (`<account-id>`, `<collection-endpoint>`) — never
as real values, including in a copied-and-pasted error message.

**Risks & Blockers:**
- Documentation drift is not detectable by CI here. `docs-consistency` is the control, and
  it only works if the audit set in `.ai/project.yml` is complete — which is Task 5's job.

---

## Tasks

- **Task 1: Rewrite the README (closes #8)**
  - **Description:** The current README describes a repository that no longer exists: a flat
    root-level layout (`bedrock.tf`, `iam.tf`, `create_index.py` at the repo root) that the
    module refactor retired, a **Titan Text Embeddings v1** model the code replaced with v2,
    an Infisical integration that is commented out in `providers.tf`, and a manual
    `tofu apply` workflow that S1 replaced with a gated pipeline. Every one of those is a
    reader following instructions into a failure.
    Rewrite around what is now true: the three OpenTofu roots and their different trust
    levels, the dataflow (S3 → Bedrock KB → AOSS → RetrieveAndGenerate), the pipeline
    (PR → plan → merge → approval → apply), the devcontainer as the supported development
    environment, and the security posture with a link to the roadmap. Include the **teardown**
    section — OpenSearch Serverless bills OCU-hours whether or not anyone queries, and the
    current README's teardown instructions no longer match the layout.
    Remove the `.env`-loading PowerShell snippet: it splits on `=` and breaks on any value
    containing one, and `Invoke-Tofu.ps1` already does it correctly.
  - **Target Files:** `README.md`
  - **Acceptance Criteria:** Every file path named in the README exists — verify each. No
    reference to Titan v1, to Infisical, or to a root-level `.tf` file. No 12-digit number, no
    `arn:aws:`, no `.aoss.amazonaws.com` host. `Closes: #8` in the PR body.

- **Task 2: Operational runbooks**
  - **Description:** Add `docs/runbooks/` covering the procedures this system needs and does
    not have. Each is a numbered procedure with a stated precondition, the commands, and a
    verification step — not prose:
    - **`ingest.md`** — add documents to the curated `corpus/` prefix (S4-T3), trigger a KB
      sync, verify the ingestion job succeeded, verify retrieval returns the new content.
    - **`reindex.md`** — the deliberate, destructive index-recreate path: the double guard
      from S4-T4, what is lost, the expected re-embedding cost, and the verification that the
      document count returned to its prior value. This runbook is the *only* sanctioned way
      that operation happens (BR-D10).
    - **`teardown.md`** — ⚠️ **promoted 2026-08-05 (BR-D20): this is the PRIMARY operating
      procedure, not a cost footnote.** The project exists to be stood up and torn down, so
      teardown is a first-class workflow and `destroy` → `apply` → verify is its acceptance
      test (F51). Document the full cycle in dependency order, what `prevent_destroy` refuses
      and why (the org-shared OIDC provider — never in scope for a teardown, BR-D18), and note
      that `force_destroy` stays `true` until a real corpus exists, precisely so `destroy`
      cannot wedge.
    - **`break-glass.md`** — CI has lost AWS access (a bad OIDC trust policy, S2's known
      hazard). Recovery is a local admin apply of `bootstrap/`; state the exact sequence and
      why it works (BR-D1: `bootstrap/` is deliberately not CI-managed).
    - **`incident-injection.md`** — a guardrail intervention alarm fired (S4-T2). How to find
      the invocation log, identify the source document from the retrieved references, remove
      it from `corpus/`, re-sync, and verify.
  - **Target Files:** `docs/runbooks/*.md`
  - **Acceptance Criteria:** Five runbooks exist. Every command in them has been executed at
    least once, except the destructive ones (`reindex`, `teardown`), whose **preconditions and
    guard behavior** have been verified without completing the destructive step. Every AWS
    identifier is a placeholder.

- **Task 3: Cost control**
  - **Description:** OpenSearch Serverless has a minimum OCU floor that bills continuously,
    and this is a personal lab whose most likely real-world failure is a surprise bill, not a
    breach. Add:
    - ⚠️ **Priority raised 2026-08-05 (BR-D20).** For an ephemeral lab whose data is
      worthless and whose OCUs bill hourly, **an environment left running is the most likely
      real-world loss this project will ever produce** — larger in expectation than any
      finding in § 3.4. Treat cost control as a primary control, not housekeeping.
    - An `aws_budgets_budget` with a monthly threshold and an email notification at 50 %,
      80 %, and 100 % of budget, driven by a variable so the amount is not hardcoded.
    - An explicit `capacity_limits` setting on the AOSS collection's account-level capacity
      configuration (`aws_opensearchserverless_account_settings` or equivalent), so a runaway
      ingestion cannot scale OCUs without bound.
    - A `docs/cost.md` recording the standing monthly floor, what drives it, and the teardown
      trigger (BR-D11's lab posture means "destroy it when idle" is a legitimate answer).
  - **Target Files:** new `modules/aws-bedrock-rag/budget.tf` or
    `environments/ai-lab/budget.tf`, `docs/cost.md`
  - **Acceptance Criteria:** `tofu plan` shows the budget and the capacity limit. The budget's
    notification address is passed as a variable and **not committed** — an email address in
    a public repo is spam bait and PII. `docs/cost.md` states an actual observed monthly
    figure, taken from Cost Explorer, not an estimate.

- **Task 4: Execute or confirm the BR-D13 outcome — where this repo lives**
  - **⚠️ The decision moved.** BR-D13 was **promoted out of this sprint on 2026-08-05** and is
    now answered by **BR-D13** and executed by the **ST** sprint, because the owner name is
    inside every OIDC subject
    (`repo:<org>/<repo>:…`) and `global-bootstrap` builds subjects from
    `github_organization=glunk-works` — so "where this repo lives" is a prerequisite for
    designing trust policies, not a closing tidy-up (F44, roadmap § 9). This task now
    **confirms** what ST executed, and closes out the `pr_base` half.
  - **Description:** **The transfer was decided (BR-D13) and executed by the ST sprint**, so
    this task is now a confirmation pass plus the `pr_base` half: verify no `Seuss27`
    reference survives, that the ruleset and merge settings still hold under the org, and that
    no org-level ruleset has since appeared that this repo cannot satisfy. The original
    transfer checklist is retained below for reference — repository variables (`AWS_OIDC_ROLE_ARN`,
    `AWS_PLAN_ROLE_ARN`) do **not** follow a transfer, the `production` Environment and its
    reviewers do not, the ruleset does not, and — critically — **every OIDC trust policy
    subject contains the owner name**, so a transfer breaks CI's AWS authentication until
    `bootstrap/` is re-applied by a human. Sequence it: enumerate new subjects, apply
    `bootstrap/` with **both** old and new subjects, transfer, verify, remove the old ones
    (the same widen-then-narrow discipline as S2-T2). If the answer is **stay**, say why and
    close the decision.
    Also revisit the `pr_base: main` deviation from the conventions' `develop` — the sibling
    repos both use `main`, so the likely outcome is confirming the deviation and recording it
    as intentional rather than as drift.
  - **Target Files:** `docs/hardening_roadmap.md`, possibly `.ai/project.yml`, `CLAUDE.md`
  - **Acceptance Criteria:** BR-D13 no longer says "open question." If transferring, the
    checklist above is executed and CI has authenticated to AWS after the move — observed,
    not assumed. If staying, the reason is one paragraph and `.ai/project.yml`'s `repo` value
    is confirmed correct.

- **Task 5: Close the documentation loop**
  - **Description:** Add `README.md` and `docs/runbooks/**` to `load_bearing_docs` in
    `.ai/project.yml` — the S6 half of the deferral recorded there when the README was
    excluded as known-stale. Then run the `docs-consistency` agent across the **full** audit
    set and fix every contradiction it finds. Update `CLAUDE.md`'s closing note, which
    currently says the README is not trusted — that statement becomes false the moment Task 1
    lands, and a stale warning about staleness is its own small joke at the repo's expense.
    Update the roadmap's § 8 status log with every sprint's completion date.
  - **Target Files:** `.ai/project.yml`, `CLAUDE.md`, `docs/hardening_roadmap.md`
  - **Acceptance Criteria:** `docs-consistency` returns no unresolved contradiction across
    the full audit set. `CLAUDE.md` contains no claim that the README is untrusted.
    `.ai/project.yml`'s `load_bearing_docs` includes `README.md`. Every sprint row in § 5 says
    `DONE` with a date, or states why it does not.

---

## Definition of Done

`gates.green` passes. Every required check green. `/critic-gate` has run with
`docs-consistency` — this is the sprint that agent exists for, and it is the one critic that
must not be skipped here. Every runbook command has been executed or its guard verified.
BR-D13 is closed.

---

## Critical review

**Security**

- *A runbook is an attacker's map.* `break-glass.md` in particular documents how to recover
  admin access to the AWS account. It is safe to publish only because it describes a
  procedure that requires credentials the reader does not have — but it must not include an
  account id, a role name that is not already in the committed IaC, or an SSO start URL.
  Reviewed against BR-D4 like any other artifact.
- *The budget notification email is PII and spam bait.* It goes in a variable sourced from
  `.env`/a repository variable, never committed. Easy to get wrong because it feels like
  configuration rather than data.
- *`incident-injection.md` will, in a real incident, be used while handling hostile content.*
  It must instruct the operator to record the **document key and the intervention id**, not
  to paste retrieved text into an issue. The natural instinct in an incident is to paste
  everything.

**Logic**

- **Task 4's transfer path is a trap that looks like a settings change.** A GitHub transfer
  redirects the repo URL and preserves issues and PRs, so it *feels* transparent — but every
  OIDC subject in the trust policy embeds the owner name, and repository variables, the
  Environment and its reviewers, and the ruleset do not survive. CI would break at the first
  post-transfer run, and the fix requires local admin access. The widen-then-narrow sequence
  from S2-T2 applies verbatim; the task states it rather than leaving it to be rediscovered.
- **Task 5 changes the meaning of `CLAUDE.md`'s trust note, and it must land in the same PR
  as Task 1.** If the README is rewritten and the note stays, the routing layer tells every
  future session to distrust an accurate document — which is a worse failure than the stale
  README, because it is self-referential.
- *The README rewrite is a real dependency on all prior sprints, not politeness.* It must
  describe the gated pipeline (S1), the split roles (S2), the hardened buckets (S3), the
  guardrail (S4), and the devcontainer (SD). Written earlier, it documents an intended state
  and re-creates #8 in a new form: prose describing a system that does not exist yet.
- *`docs/cost.md` requires an observed figure.* An estimate written from the pricing page is
  the kind of number that gets quoted for years. Cost Explorer, or state that no month of
  data exists yet.

**Execution**

- *"Every command has been executed" is the criterion, and it is expensive.* That is
  deliberate: an unexecuted runbook is a hypothesis, and the two places this repo will
  actually need one — break-glass and an injection incident — are exactly when discovering a
  wrong command is worst. The destructive runbooks are the stated exception, verified to
  their guard and no further.
- *`docs-consistency` will flag intentional historical prose.* The roadmap's § 8 status log
  and the finding inventory describe past states on purpose. The agent's own brief is to
  distinguish a genuine contradiction from deliberate historical or aspirational prose; if it
  flags those, the fix is to make the framing unmistakable, not to delete the history.
- *This sprint has no code paths*, so `/critic-gate` will propose few critics. Do not skip
  the pass on that basis — `docs-consistency` is the one that matters, and it is the only
  sprint where it is the primary rather than a secondary.
