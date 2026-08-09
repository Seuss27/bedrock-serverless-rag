# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`implementing` — `S1b` (the pipeline rewrite).** All five tasks (`T2`, `T1`, `T3`, `T6`,
`T7`) are merged. The sprint is still not complete: its Definition of Done needs a
`destroy → apply → verify` cycle, human-watched, against the final shape. **The apply half
just succeeded** — read below before assuming the whole cycle is outstanding.

## Just done

`S1b`-T7 merged (F59/F60 closed at the cause — raw `gitleaks` CLI with no license gate;
job-scoped `deploy.yml` permissions + dependabot cooldown; new finding `F61` on floating
tool versions, unassigned). Then, working through the DoD's outstanding cycle:

- **The apply half of the cycle succeeded.** A no-op `.tf` comment touch (the repo's
  established pattern, PR #89 then #90) re-triggered `deploy.yml`'s `tofu-plan-main` →
  `tofu-apply`. First attempt: the human rejected/cancelled the approval (confirmed via the
  Actions API — zero steps ran, zero AWS mutation). Second attempt: approved, ran, and got
  through every resource except the vector index, which failed with
  `AuthorizationException` 1.6s after the very data-access-policy that grants it had itself
  finished creating. **Diagnosed live against AWS (read-only) rather than guessed:** both
  `aoss:APIAccessAll` and the policy's Principal list were already correct — concluded AOSS
  access-policy propagation lag, not a misconfiguration. A third no-op touch retried it, and
  **this apply succeeded — the lab is now fully live, all 12 resources including the vector
  index.**
- **Fixed the root cause so this self-heals next time.** Per the user's own suggestion,
  `create_index.py`'s `AuthorizationException` handling now gets a short, separately-bounded
  retry (2 attempts, 15s apart) — distinct from the general 6×45s loop, whose full budget
  would reopen `F46`'s original "hides a real error for minutes" problem. `security-critic`
  proved the exit-code guarantee correct by exhaustive simulation over all 3⁶ failure
  sequences, confirmed BR-D4-clean, confirmed `F46`'s under-a-minute guarantee survives.
  Three low-severity wording findings, all fixed in the same change.
- **Process trap, worth knowing:** the PR carrying this fix (#90) got merged one commit
  early — on just the no-op touch, before the fix was pushed. A later push to an
  already-merged PR's branch fires no CI (the PR is closed). The fix was rebuilt cleanly as
  **PR #91** against current `main`.
- **BR-D4 near-miss, disclosed rather than glossed over:** a bare
  `aws sts get-caller-identity` while diagnosing printed the account id and an SSO role ARN
  into the session transcript — the identical incident this repo hit during `MW`-T6. Caught
  and named; not repeated in the ~6 follow-up AWS CLI calls, all scoped to
  `--query`/`--output text` returning only booleans or counts.

## Next

**Merge PR #91** (`fix/create-index-auth-retry`) once its CI is fully green — mostly green
as of this cursor.

**Then finish `S1b`'s DoD.** The lab is live; what's left is the **verify** step and a
**destroy** dispatch under the new job-scoped permissions (never exercised since `T7`
changed `destroy-ai-lab`'s `permissions:` block). Present both to the human — do not run
either unattended:
1. A `RetrieveAndGenerate` call against the freshly-built Knowledge Base
   (`test_rag.py`, run locally under admin-SSO — it's interactive).
2. Dispatch `destroy-ai-lab` with the confirm phrase, to exercise the destroy path under
   the new permissions and return the lab to the accepted torn-down steady state (`BR-D26`).

Only after both does `S1b` truly close, and `/archive-sprint` applies.

**Model: `sonnet` / coder.**

## Open gates and blockers

**HITL Gate: OPEN — verify + destroy above are human-watched** (sprint plan + BR-D2/BR-D25).

**PR #88 (`docs/sync-cursor-s1b-t7-merged`) is OPEN but STALE — do not merge it as-is.** It
was written when the whole DoD cycle was outstanding; the apply has since succeeded, so its
content no longer matches reality. Close it unmerged, or supersede it with a fresh sync once
verify+destroy land.

`glunk-works/global-bootstrap#7` (org-wide lock-table question) still awaits a response —
informational, not blocking.

**F61** (floating tool versions on `tofu-fmt`/`tofu-validate`/`tflint`) has no sprint owner
yet — flag it for whoever plans the next sprint.

**Process lesson, not yet written into a doc — consider a `/retro`:** merging a PR while
more commits are still being actively pushed to its branch is a real trap in this repo's
flow. Squash-merge takes whatever was on the branch at merge time; anything pushed after
fires no further CI, since the PR is already closed.

## Pointers

- `docs/hardening_roadmap.md` — reference of record and threat model. `F59`/`F60` closed,
  `F61` recorded, `F46`'s row updated with this session's refinement. `S1b`'s status row
  still says `implementing` — correct, don't mark it `complete` until verify+destroy land.
- `sprints/S1_pipeline_hardening/sprint_plan.md` — Definition of Done section (the paragraph
  starting `**`S1b` (~~T2, T1, T4, T3, T6, T7~~**`) is the authoritative text for what remains.
