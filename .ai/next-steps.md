# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`implementing` — `MW` ("make it work"): the first successful `destroy → apply → verify` cycle.**

Read the banner under the sprint plan's title before any task body. **The task numbers
moved:** what the roadmap and older docs call `MW-T0/T1/T2/T3` are now Tasks **5/6/4/3**.
Tasks 3 and 2 are **done**; Task 4 is next.

## Just done

- **Task 3 (F46, F31) and Task 2 landed together** in PR **#43**, merged at **`ccc76e6`**.
- **F46:** `create_index.py`'s retry loop no longer retries an `AuthorizationException` —
  it's F5 (a permanent principal/policy misconfiguration), not IAM eventual consistency, so
  it now fails in under a minute naming the real cause instead of burning ~12 minutes.
- **F31:** no exception text reaches the log anywhere in that file — including two residual
  paths (`SerializationError`, opensearchpy's own request-failure logger) a `security-critic`
  pass caught before merge; both fixed in the same PR.
- **CI's lint gate is unblocked:** `ruff`/`bandit` are now pinned (`0.16.2`/`1.9.4`) with an
  explicit minimal rule set in `environments/ai-lab/ruff.toml`, so a future linter release
  can't fail the pipeline with no repo change — which is what had already happened
  (`I001`/`BLE001`, run `31110724740`). The 5 resulting errors are fixed.
- **Not yet verified:** whether `opentofu-pipeline` (job 2) actually runs green now — this
  session only confirmed job 1 passes locally with the pinned tools. `MW`'s Definition of
  Done needs a real CI run reaching the plan step, not just a clean local check.

## Next

**Implement `MW` Task 4 (F5). Model: `sonnet` (coder).**

- Make the AOSS data-plane principal explicit: remove `data.aws_arn.current_identity` from
  `modules/aws-bedrock-rag`, add the `data_plane_principal_arns` variable exactly as the
  sprint plan specifies (validated to IAM role ARNs, never `sts` assumed-role ARNs), and
  change the data-access policy's `Principal` to
  `concat([aws_iam_role.bedrock_kb_role.arn], var.data_plane_principal_arns)`.
- In `environments/ai-lab`, pass **this repo's own `github-actions-deploy-role`** ARN (the
  one `vars.AWS_OIDC_ROLE_ARN` names today) plus the human operator's SSO role — **not** an
  upstream `global-bootstrap` role, which doesn't exist for this project until S2-T0.
- **HCL authoring only** — run the local green gate, do **not** `tofu plan`/`apply` against
  real AWS. Do **not** add `aoss:APIAccessAll` here; that's already on the KB role and is
  Task 5's item, not Task 4's.

## Open gates and blockers

**HITL Gate: NONE OPEN** for Task 4 — pure HCL authoring, no AWS call. **Three gates are
still ahead inside `MW`:**

- **Task 1 (#37) is human-only** — the backup's location is deliberately unrecorded (BR-D4).
- **The `bootstrap/` apply in Task 5** — BR-D1; the most consequential act in the sprint,
  running against the unbacked-up state file that holds the org-shared OIDC provider.
- **Deleting the orphan role** (Task 5 step 1) — cheap and reversible, but confirm it is
  still policy-less and still out of state **against a fresh measurement**, never a document.

## Pointers

- `sprints/MW_make_it_work/sprint_plan.md` — **the active sprint.** Banner first.
- `docs/hardening_roadmap.md` — reference of record **and** threat model.
- **Regenerate the verb list from CloudTrail in Task 5** — not from F55, and not from the
  sprint plan's own table. Every list ever written here came from a *create* path, while the
  acceptance test is `destroy → apply → verify`.
- **The trap that outlives ST:** an org-owned repo presents
  `repo:<owner>@<org_id>/<repo>@<repo_id>:<context>`; a plain glob does **not** match it. The
  comment block in `bootstrap/oidc-setup.tf` is the best writeup of it.
- **`/way-of-working:resume`'s drift check has a known limitation** with squash-merge
  (upstream `claude-workbench#6`, reopened this session with a live repro) when a handoff
  runs alongside a second open PR. Not the case this time — this is a single docs-only
  commit with nothing else in flight — so the next `/resume` should see no drift. If it
  does anyway, check `merge-base --is-ancestor` before assuming something broke.
