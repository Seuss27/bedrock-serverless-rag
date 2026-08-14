# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`SD`, `implementing`.** Task 3 is **done and merged**. Task 4 is the active work. `S2` Task 4
continues as a parallel, human-gated thread, unchanged.

## Just done

- **SD Task 3 — container-vs-CI comparison.** Rebuilt the devcontainer image from the committed
  Dockerfile (zero cache misses — confirms parity with what's on disk), ran `gates.green` plus
  `tflint --recursive` / `checkov -d .` / `zizmor .github/workflows/` against a **fresh clone**
  (not the host-mounted workspace), and compared every verdict to CI's job conclusions on the
  tree-identical commit (`5d21932` / PR #123's head `c0e0fd1`). Everything matched CI except a
  **bare `tflint --recursive`** — the exact command the sprint plan's own prose names — which
  drops the `--config` flag `ci.yml` passes explicitly and false-positives on `bootstrap/`'s
  pre-existing missing `required_version`. Recorded as **F62** (Low — not a tool-pin defect,
  a documentation gap Task 4's README must close).
- **`/way-of-working:critic-gate` ran** (`docs-consistency`; `review.ci_gate` is `null` so this
  is the only critic look the diff gets): round 1 found two real defects — F62 had misattributed
  `bootstrap/`'s gap as "already-tracked" when the comment it cited says the opposite, and a
  pre-existing blank line (from an earlier `S1b`-T7 edit) had pushed F60/F61 outside the
  markdown table, which F62's own row would have extended. Both fixed; round 2 converged clean.
- **Shipped:** [PR #124](https://github.com/glunk-works/bedrock-serverless-rag/pull/124),
  merged at `8c2ec46`.
- **v0.6.0 canary satisfied.** This whole session (`/way-of-working:resume` →
  implement → `/way-of-working:critic-gate` → `/way-of-working:ship` → `/way-of-working:handoff`)
  ran under a **loaded** `way-of-working` v0.6.0 with no defect found —
  [claude-workbench#36](https://github.com/glunk-works/claude-workbench/pull/36) can be closed
  next time that repo is touched.

## Next

**Model: `sonnet` / coder.**

1. **SD Task 4** — `.devcontainer/README.md` (what's in the image and why, how credentials
   reach the container, the `.terraform/` fresh-clone wrinkle, how to bump a pin), **BR-D15**
   in the roadmap, a `CLAUDE.md` § Commands pointer at the container, and a comment-only note
   in `.ai/project.yml` (no new schema key). Spec:
   `grep -n '^- \*\*Task 4' -A 20 sprints/SD_devcontainer/sprint_plan.md`.
   While in the roadmap, also close two carried items:
   - **F61's row is now stale** — this session's critic-gate confirmed PR #117 already pins
     `tofu_version` (`1.12.5`) and `tflint_version` (`0.64.0`) everywhere in `ci.yml`/
     `plan.yml`/`deploy.yml`. Close it.
   - **GitHub MCP server decision record** — still absent from the roadmap (confirmed by grep
     this session). App auth (`bedrock-rag-mcp-reader`), why not PAT/OAuth, the digest pin,
     devcontainer incompatibility.
2. **S2 Task 4 step 3** — sub-steps 3.2/3.3, unchanged, **human-gated**.

## Open gates and blockers

**HITL Gate: NONE OPEN for SD's queue** — Task 4 has no gate, safe to auto-start.
Separately, **still OPEN: the `S2` thread**, unchanged for four sessions now — Task 4 step 3's
sub-steps 3.2 (`production` Environment approval click) and 3.3 (`destroy-ai-lab` typed confirm
phrase, watched live per BR-D25). Do not begin those two unattended.

**Process note new this session:** `docker run -v ... -w /path` under Git Bash hits the same
MSYS path-conversion trap already known for `gh api` — it mangled a bind-mount path and errored
loudly. `MSYS_NO_PATHCONV=1` fixed it immediately; same root cause as the existing memory, new
call site.

## Pointers

- `docs/hardening_roadmap.md` — reference of record and threat model. F62 landed this session;
  two edits (F61, GitHub MCP record) queued above.
- `sprints/SD_devcontainer/sprint_plan.md` — Tasks 1–3 done, Task 4 next.
- `sprints/S2_identity_least_privilege/sprint_plan.md` — Task 4 step 3: 3.1 satisfied,
  3.2/3.3 pending human action.
