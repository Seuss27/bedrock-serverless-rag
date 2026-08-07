# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`planning` — `MW` ("make it work"): the first successful `destroy → apply → verify` cycle.**

`ST` is **complete and archived**. The repo lives at `glunk-works/bedrock-serverless-rag`.

`MW`'s plan **already exists** at `sprints/MW_make_it_work/sprint_plan.md` and has been
corrected twice. So the next action is a **pre-implementation plan review against live
state** — the same pass that found ST's plan to be the most defect-dense in the roadmap and
reshaped it *before* a single task ran — **not** a from-scratch write and **not**
implementation.

## Just done

- **`ST` COMPLETE and ARCHIVED**, closed at **`b9df242`** (PR **#36**, ST-T5). Final cursor
  snapshot at `.ai/archive/ST-next-steps.md` *(gitignored — this workstation only)*.
  - **BR-D13 executed**: transfer 2026-08-06/07 UTC, `widen → transfer → narrow` in one
    session, verified against **live AWS**, not the HCL.
  - **Closed:** **F44**, **F45**, **F50**, and **F57's `path` half**. ⚠️ **F45 closed BY
    REMOVAL, not correction** — the dormant upstream role was deleted, so **no boundary, no
    role-path scope and no findings `Deny` was built for this project**. S2-T0 builds them.
  - **F41 and F42 remain OPEN org-wide** (`glunk-works/global-bootstrap#6`). Deleting one
    project's entry removed an instance, not the pattern.
  - **Re-homed findings verified present in their destinations**, not merely recorded:
    **F55 → `MW-T0`**, **F56 / F58 / F57's boundary half → `S2-T0`**.
  - **ST-T0's backup criterion was met** — confirmed by the operator at the completion review,
    and recorded only then. Its **restore-test is attested, not proven**: **issue #37**,
    blocking before any `bootstrap/` apply.

## Next

**Plan-review `MW`. Model: `opus` (architect).** One question at a time — the planning
dialogue *is* the work. Do **not** auto-start implementation.

- **Read `MW`'s blocking gate first** — *"read this before deleting anything."* **MW-T0 (F55)
  must prove the deploy identity can rebuild from scratch BEFORE Task 1 deletes anything**, and
  **option 1 (*adopt the upstream role first*) is STRUCK** — there is no upstream role after
  `ST-T2′`, and re-adding one here without a boundary reopens **F41** to unblock a rebuild.
- **Verify against live AWS, not the plan text:**
  - re-confirm F55's four gaps are still absent from `bootstrap/state-backend.tf`'s
    `state_access_policy` (no `aoss:*AccessPolicy`, no `iam:PassRole`, no `s3:GetBucket*`,
    no `s3:PutEncryptionConfiguration`) — and **regenerate the verb list from a dry run**, not
    from F55's text, whose own confidence note says it may be incomplete;
  - inventory what exists in AWS vs. what is in state (**F39**'s split brain) before trusting
    any plan output;
  - confirm nothing **shared with the organization** is in teardown scope — the OIDC provider
    above all.
- **Before any `bootstrap/` apply: close out #37** (restore-test the state backup).

## Open gates and blockers

**HITL Gate: OPEN.** `MW` is in `planning`, and the planning dialogue is the human's work.
Nothing may be implemented until the review completes and the human approves.

- **Two human-only acts sit inside `MW`:** the **teardown of live AWS workload resources**
  (MW-T1 step 2) — the only irreversible act in this roadmap a coder could perform alone — and
  any `bootstrap/` apply if MW-T0 takes the widen-first path (**BR-D1**: `bootstrap/` is never
  applied by CI).
- **#37 blocks every `bootstrap/` apply.** The backup exists; its *restorability* does not yet.
  That file is the only record of the **org-shared OIDC provider**, and `prevent_destroy` is a
  plan-time guard over a *state entry* — it evaporates with the file.

## Pointers

- `docs/hardening_roadmap.md` — reference of record **and** threat model. § 10's 2026-08-07 row
  is ST's completion record; § 5's ordering hazards **1, 3, 4 and 7** all bind `MW`.
- `sprints/MW_make_it_work/sprint_plan.md` — **the next sprint.** Exists, reviewed twice, not
  executed.
- `sprints/S2_identity_least_privilege/sprint_plan.md` — where F56/F58/F57's boundary half
  landed, as blocking **Task 0**; carries the ID-qualified OIDC subject trap.
- **The trap that outlives ST:** an org-owned repo presents
  `repo:<owner>@<org_id>/<repo>@<repo_id>:<context>`; a plain glob does **not** match it. Do not
  trust `use_immutable_subject: false` — read `sub_claim_prefix`, confirm against CloudTrail.
- **A recurring failure worth watching for:** a corrected fact surviving in a **summary** while
  the detail beside it is fixed. It happened three times in ST-T5's own session.
