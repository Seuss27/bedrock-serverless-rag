### FILEPATH: /sprints/S6_docs_operational_readiness/sprint_plan.md

# S6 — Documentation and operational readiness

> **⚠ Reshaped 2026-08-05 by BR-D23.**
>
> - **T1 (README): keep.** Issue #8 is real, and the current README actively instructs a reader
>   to provision the exact credential F52 says to revoke. ⚠️ **S0 now deletes those three README
>   lines early** as part of the F53 deletion — this task is the full rewrite, not the first
>   time the file is touched.
> - **T2: cut to TWO runbooks** — `teardown.md` (BR-D20 makes teardown the primary operating
>   procedure) and `break-glass.md` (the one procedure where being wrong costs most). **Cut**
>   `ingest.md` and `reindex.md` (operations never performed, on a corpus that does not exist)
>   and `incident-injection.md` (it depends on S4-T2's alarm, which BR-D23 cut). This task's own
>   criterion — *"every command has been executed at least once"* — is expensive in exact
>   proportion to the runbook count, which is the argument for cutting three of five.
> - **T3 (cost control): MOVED EARLIER, to S0.** Nothing remains here. *(The AOSS capacity-limit
>   half is dead — `aws_opensearchserverless_account_settings` does not exist; see § 5.1.)*
> - **T4/T5: MERGE.** BR-D13 is resolved and ST executes the transfer, so T4 is now a
>   **confirmation pass**. Its body used to retain the full transfer checklist and an *"if
>   staying"* branch — **both deleted**, because S6 runs long after ST and a coder following that
>   checklist would attempt the transfer a second time.

**Sprint Goal:** Make the repo's prose true again, give the system the operational documents
it has never had (runbooks, cost control, teardown), and close the two open governance
questions.

**Closes:** issue #8, **F53** (the README half — S0 deletes the scaffolding half), **F49**
 (by documenting the `AWS_PROFILE` export, which is the only fix available while `bootstrap/`
 is being retired rather than hardened). Confirms **BR-D13**. Adds README.md to
 `load_bearing_docs`.

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
    an Infisical integration that ~~is commented out in `providers.tf`~~ **no longer exists
    anywhere** *(corrected 2026-08-07 by ST-T5: S0-T7 **deleted** the scaffolding rather than
    commenting it out — `grep -rni infisical` over `modules/`, `environments/`, `bootstrap/`
    and `.github/` returns nothing, so there is no commented block to point at; what survives
    is three lines of stale README prose, `:5`, `:13`, `:26`)*, and a manual
    `tofu apply` workflow that S1 replaced with a gated pipeline. Most of those are a
    reader following instructions into a failure; the Infisical lines are now merely a reader
    believing something untrue, which is why S0 took the actionable half early.
    Rewrite around what is now true: the three OpenTofu roots and their different trust
    levels, the dataflow (S3 → Bedrock KB → AOSS → RetrieveAndGenerate), the pipeline
    (PR → plan → merge → approval → apply), the devcontainer as the supported development
    environment, and the security posture with a link to the roadmap. Include the **teardown**
    section — OpenSearch Serverless bills OCU-hours whether or not anyone queries, and the
    current README's teardown instructions no longer match the layout.
    Remove the `.env`-loading PowerShell snippet: it splits on `=` and breaks on any value
    containing one. **Do not replace it with another wrapper.** `Invoke-Tofu.ps1`, which used to
    do the same job less badly, was **deleted 2026-08-05** — document the native invocation
    instead (`$env:AWS_PROFILE`, `TF_VAR_*`, then plain `tofu`), exactly as `CLAUDE.md`
    § Commands now does. **And state the `AWS_PROFILE` export explicitly** — with the wrapper
    gone, this README and the break-glass runbook are the only places F49's setup step is
    written down.
  - **Target Files:** `README.md`
  - **Acceptance Criteria:** Every file path named in the README exists — verify each. No
    reference to Titan v1, to Infisical, or to a root-level `.tf` file. No 12-digit number, no
    `arn:aws:`, no `.aoss.amazonaws.com` host. `Closes: #8` in the PR body.

- **Task 2: Operational runbooks**
  - **Description:** Add `docs/runbooks/` covering the procedures this system needs and does
    not have. Each is a numbered procedure with a stated precondition, the commands, and a
    verification step — not prose:
    ⚠️ **TWO runbooks, not five (BR-D23).** `ingest.md` and `reindex.md` are **cut** — they
    document operations never performed, on a corpus that does not exist, and `reindex.md`'s
    *"expected re-embedding cost"* and *"document count returned to its prior value"* are
    assertions about data there is none of. `incident-injection.md` is **cut** because it
    depends on S4-T2's alarm, which BR-D23 also cut. Write them when the operations become
    real; **`reindex.md` in particular becomes required the day BR-D10 stops being
    forward-looking**, since it is meant to be the only sanctioned path for that operation.
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
  - **Target Files:** `docs/runbooks/teardown.md`, `docs/runbooks/break-glass.md`
  - **Acceptance Criteria:** **Two** runbooks exist. Every command in them has been executed at
    least once, except `teardown`'s destructive step, whose **preconditions and guard
    behaviour** are verified without completing it. Every AWS identifier is a placeholder.
    **`break-glass.md` states the `AWS_PROFILE` export** — with `Invoke-Tofu.ps1` deleted, this
    and the README are the only places F49's setup step is written down, and a break-glass is
    exactly when nobody wants to debug a credential chain.

- **Task 3: ~~Cost control~~ — MOVED EARLIER, to S0**
  - **Moved 2026-08-05 (BR-D23).** This task stated in its own words that an environment left
    running is *"the most likely real-world loss this project will ever produce — larger in
    expectation than any finding in § 3.4"* — and was then scheduled **ninth**. That is the
    clearest severity/ordering mismatch in the roadmap, and it is fixed by moving the work, not
    by re-arguing the priority. The `aws_budgets_budget` (50/80/100 % notifications, amount
    driven by a variable, notification address a variable and **never committed**) and
    `docs/cost.md` are now **S0**. **Do not execute it from here.**
  - **⚠️ The capacity-limit half is DEAD, wherever it runs.**
    `aws_opensearchserverless_account_settings` **does not exist under any spelling** — provider
    issue `hashicorp/terraform-provider-aws#41245`, open since 2025-02-05. An AOSS capacity
    limit is console/CLI-only. Do not write it into a task; if it is wanted, it is a manual
    step recorded in `docs/cost.md`.

- **Task 4: Execute or confirm the BR-D13 outcome — where this repo lives**
  - **⚠️ The decision moved.** BR-D13 was **promoted out of this sprint on 2026-08-05** and is
    now answered by **BR-D13** and executed by the **ST** sprint, because the owner name is
    inside every OIDC subject
    (`repo:<org>/<repo>:…`) and `global-bootstrap` builds subjects from
    `github_organization=glunk-works` — so "where this repo lives" is a prerequisite for
    designing trust policies, not a closing tidy-up (F44, roadmap § 9). This task now
    **confirms** what ST executed, and closes out the `pr_base` half.
  - **Description:** **The transfer was decided (BR-D13) and executed by the ST sprint**, so
    this task is now a confirmation pass plus the `pr_base` half: verify no **operative**
    `Seuss27` reference survives (per ST Task 4's explicit file list — **not** a bare
    `grep -rn Seuss27`; see the acceptance criteria below), that the ruleset and merge settings
    still hold under the org, and that
    no org-level ruleset has since appeared that this repo cannot satisfy. The original
    ⚠️ **The transfer checklist that used to sit here has been DELETED, not retained.** It
    instructed the coder to *"apply `bootstrap/` with both old and new subjects, transfer,
    verify, remove the old ones"* and offered an *"if the answer is **stay**"* branch. **S6 is
    dependency-gated on S1–S5, so it runs long AFTER ST has already transferred the repo** — a
    coder executing that checklist would attempt the transfer **a second time**, against a repo
    that has already moved. There is no branch: the transfer is decided (BR-D13) and executed
    (ST-T3). *(The retained text also mis-cited the widen-then-narrow discipline as "S2-T2";
    widen-then-narrow is **ST-T3**. S2-T2 is role adoption and contains no such step — a
    dangling procedural cross-reference in the one procedure that is irreversible.)*
    **This task verifies; it does not transfer.**
    Also revisit the `pr_base: main` deviation from the conventions' `develop` — the sibling
    repos both use `main`, so the likely outcome is confirming the deviation and recording it
    as intentional rather than as drift.
  - **Target Files:** `docs/hardening_roadmap.md`, possibly `.ai/project.yml`, `CLAUDE.md`
  - **Acceptance Criteria:** ✅ BR-D13 records the transfer as **executed**, with the date
    *(done by ST-T5, 2026-08-07 — so verify it, do not re-write it)*. ~~No `Seuss27` reference
    survives anywhere.~~
    > **⚠️ That criterion CANNOT PASS and must not be attempted** *(rewritten 2026-08-07 by
    > ST-T5)*. It is the identical defect ST-T4 hit and diagnosed: `Seuss27` is **load-bearing
    > historical record** in five sprint plans, in the roadmap's **F17 evidence row** and status
    > log, and in `bootstrap/oidc-setup.tf`'s deliberate "never re-add this subject" warnings.
    > Scrubbing them rewrites history to satisfy a grep. **Use ST Task 4's operative-file list
    > instead** — it is exhaustive, grep-checkable, and exempts the historical record **by
    > name**. Every entry on it was closed by ST-T4 and ST-T5, so this is a *verification*, not
    > a hunt: `.ai/project.yml` (key **and** comment), `.github/CODEOWNERS`,
    > `.github/ISSUE_TEMPLATE/config.yml`, `README.md`, `CLAUDE.md`, and the **live AWS trust
    > policies** (checked with `aws iam get-role`, never against the HCL).
    > **The general rule, which is the reusable part:** an acceptance criterion nobody can pass
    > gets **waived wholesale**, taking the two references that genuinely rot silently down
    > with it.

    The ruleset and merge settings still hold under the
    org, and `gh api orgs/glunk-works/rulesets` has been read for any org-level rule this repo
    cannot satisfy (a BR-D9 deadlock by another route) — ⚠️ note that on the **Free** plan this
    returns **403 upgrade-required**, and that a missing `admin:org` scope returns **404**,
    which reads identically to "none exist"; record *verified absent* and *could not look* as
    different answers. `.ai/project.yml`'s `repo` is
    `glunk-works/bedrock-serverless-rag`. **No transfer is performed by this task.**

- **Task 5: Close the documentation loop**
  - **Description:** Add `README.md` and `docs/runbooks/**` to `load_bearing_docs` in
    `.ai/project.yml` — the S6 half of the deferral recorded there when the README was
    excluded as known-stale. Then run the `docs-consistency` agent across the **full** audit
    set and fix every contradiction it finds. Update `CLAUDE.md`'s closing note, which
    currently says the README is not trusted — that statement becomes false the moment Task 1
    lands, and a stale warning about staleness is its own small joke at the repo's expense.
    Update the roadmap's § 10 status log with every sprint's completion date.
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
- *`docs-consistency` will flag intentional historical prose.* The roadmap's § 10 status log
  and the finding inventory describe past states on purpose. The agent's own brief is to
  distinguish a genuine contradiction from deliberate historical or aspirational prose; if it
  flags those, the fix is to make the framing unmistakable, not to delete the history.
- *This sprint has no code paths*, so `/critic-gate` will propose few critics. Do not skip
  the pass on that basis — `docs-consistency` is the one that matters, and it is the only
  sprint where it is the primary rather than a secondary.
