# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**GitHub MCP server evaluation is the priority for the next session**, per the user's own
request. `SD` Tasks 1–2 are done (PR #117 merged, PR #118 open); `SD` Task 3–4 and `S2` Task 4's
remaining human-gated sub-steps continue as parallel threads, neither dropped.

⚠️ **If `/way-of-working:resume` itself fails to invoke** (`Unknown skill`), the `way-of-working`
plugin is still disconnected from a mid-session outage today — try `/reload-plugins` or
restarting Claude Code first. This file was written by hand this session because the handoff
skill itself stopped working; treat that as a live process problem, not a sign the cursor is
unreadable.

## Just done

- **SD Task 1 merged** ([PR #117](https://github.com/glunk-works/bedrock-serverless-rag/pull/117)):
  `.devcontainer/Dockerfile`, pinned tofu/tflint/checkov/gitleaks/zizmor. Two rounds of
  `security-critic`+`architect` review (before those agents went unavailable — see below) found
  and fixed a mutable base-image tag, a false claim that had left `tflint` — a **required
  check** — floating unpinned, and an overclaiming checkov-verification comment. Also
  reconciled `tofu_version` across all 6 `setup-opentofu` occurrences in
  `ci.yml`/`plan.yml`/`deploy.yml` and added `tflint_version` to `ci.yml`.
- **SD Task 2 open** ([PR #118](https://github.com/glunk-works/bedrock-serverless-rag/pull/118)):
  `.devcontainer/devcontainer.json` + generated `devcontainer-lock.json`. Live-verified
  end-to-end with the `devcontainer` CLI on this workstation — build/up/exec, AWS mount
  resolves, `git status` clean, `aws sts get-caller-identity` fails with the *expected*
  "token expired" error rather than a missing-mount error. **Found a real gotcha**: invoking
  the `devcontainer` CLI via `npx` on Windows injects a synthetic `HOME` env var that corrupts
  the `${localEnv:HOME}${localEnv:USERPROFILE}` mount pattern — a test-harness artifact, not a
  `devcontainer.json` defect. Invoke the CLI's own entry point directly (not through `npx`)
  when testing this kind of cross-platform path logic.
- **SD banner correction merged** ([PR #116](https://github.com/glunk-works/bedrock-serverless-rag/pull/116)):
  the sprint was never actually blocked on Docker; corrected across `CLAUDE.md`, the roadmap,
  and the sprint plan.
- **`/doctor` cleanup**: disabled the unused `aws-core` plugin (0 usage, 19 skills + a
  `PreToolUse` hook on every `Bash` call + an MCP proxy, zero benefit in this repo) via
  `.claude/settings.local.json` — local, gitignored, not part of any commit.
- **CLAUDE.md context management, evaluated and partly landed**
  ([PR #119](https://github.com/glunk-works/bedrock-serverless-rag/pull/119), open): a bigger
  restructuring (moving ~21k chars into path-scoped `.claude/rules/*.md` files) was proposed,
  **built as a real test case, and empirically disproven** — a fresh session's `/context` still
  counted the moved content even though nothing under the scoped path (`.github/workflows/**`)
  had been touched, matching an open upstream bug
  ([anthropics/claude-code#16299](https://github.com/anthropics/claude-code/issues/16299)).
  Fully reverted, byte-identical. Landed the smaller win that doesn't depend on that broken
  mechanism instead: moved a ~1.8k-char task-specific runbook (local `tofu plan`/`apply`
  walkthrough + Git-Bash-`gpg` debugging) into `.claude/skills/tofu-local-plan/SKILL.md`.
- ⚠️ **Mid-session: the `way-of-working` plugin's custom review agents disappeared**
  (`architect`/`coder`/`docs-consistency`/`security-critic` — confirmed twice via direct probe,
  `Unknown agent type`). By session end **the plugin's skills stopped working too**
  (`way-of-working:handoff` itself: `Unknown skill`) — this reads as a broader
  plugin-connectivity problem, not just the agents. All PR work after the agents disappeared
  used a self-review-and-ship fallback (asked the user first each time). This cursor file was
  written by hand, replicating `/way-of-working:handoff`'s own mechanics from memory.

## Next

**Priority 1 — GitHub MCP server evaluation (new thread, starting fresh next session):**

Research already done this session, don't re-derive it:
- `github/github-mcp-server` covers `pull_requests`/`actions`/`issues`/`repos` toolsets well,
  including `get_job_logs` — would replace the `gh run view --log | grep` pattern used
  repeatedly this session to find resolved CI tool versions.
- Supports a `--read-only` flag/env var that skips every write tool — mirrors this repo's own
  plan-role/apply-role philosophy.
- **Does NOT expose branch protection rulesets or repo secrets/variables** — `gh` CLI stays
  needed for those, in particular the `/way-of-working:resume` ruleset-drift check.
- Prefer local Docker deployment (`ghcr.io/github/github-mcp-server`, digest-pinned per this
  repo's own supply-chain convention) with a narrowly-scoped PAT over the remote
  `api.githubcopilot.com/mcp` endpoint, which is beta/rollout-gated.
- Net assessment: a real but modest win, not a `gh` replacement.

Decide whether to actually add it, and if so scope/pin it properly.

**Priority 2 — SD, parallel:**

1. Task 3: run every `gates.green` entry plus `tflint --recursive`/`checkov -d .`/
   `zizmor .github/workflows/` **inside the container from a fresh clone** (not the
   host-mounted workspace — its `.terraform/` is already initialized against the S3 backend).
   Compare verdicts to the same-commit CI run; record any divergence in
   `docs/hardening_roadmap.md`. Full spec:
   `grep -n '^- \*\*Task 3' -A 60 sprints/SD_devcontainer/sprint_plan.md`.
2. Task 4: `.devcontainer/README.md`, a BR-D15 entry in the roadmap, a `CLAUDE.md` pointer, a
   comment-only note in `.ai/project.yml`.

**Priority 3 — S2, parallel, human-gated:**

Task 4 step 3's verify cycle. **Sub-step 3.1 (a PR plan job green on the plan role) is already
satisfied** — evidenced by PR #116's `plan.yml` run
[31504008599](https://github.com/glunk-works/bedrock-serverless-rag/actions/runs/31504008599),
no re-proof needed. Sub-steps 3.2 (merge → `tofu-apply` plans `12 to add` → needs your
`production` Environment approval click) and 3.3 (dispatch `destroy-ai-lab` with the typed
confirm phrase, watch it live per BR-D25) have not started — declined this session pending
readiness. Full spec: `grep -n '^### Task 4' -A 200 sprints/S2_identity_least_privilege/sprint_plan.md`.

**Model: `sonnet` / coder** for all three threads.

## Open gates and blockers

**HITL Gate: OPEN, unchanged from last session — S2 thread only.** Task 4 step 3's remaining
sub-steps (3.2 Environment approval, 3.3 destroy confirm phrase) are human-gated pipeline
actions. Neither the SD thread nor the GitHub-MCP-evaluation thread has an open gate.

**Not filed, deliberately** (carried): `security-critic`'s LOW finding that no required check
can see `encryption.tf`'s `enforced = true` line. `global-bootstrap` has no CI/branch
protection at all — worth an issue, not filed. `F61` (`docs/hardening_roadmap.md`) named both
`setup-opentofu` and `setup-tflint` floating on "latest" as a required-check hazard — SD Task 1
closed both halves (explicit `tofu_version`/`tflint_version` everywhere) but the roadmap row
isn't updated yet; do it next time that file is touched.

**Process notes worth carrying forward:**
- **`.claude/rules/*.md` `paths:` frontmatter does not actually scope loading** on this
  installed Claude Code version — verified empirically, matches
  [anthropics/claude-code#16299](https://github.com/anthropics/claude-code/issues/16299).
  Saved to memory (`claude-rules-path-scoping-broken.md`); re-check the issue's status before
  trying this again.
- **Subagents inherit a stale, session-start snapshot of `CLAUDE.md`**, not a live read —
  confirmed by a subagent quoting pre-edit content verbatim, explicitly labeled as the live
  file. Don't use a same-session subagent to answer "what does a fresh session see" — only a
  genuinely new process is valid for that.
- Invoking a Node CLI via `npx` on Windows injects a synthetic `HOME` env var absent from the
  parent shell — breaks `${localEnv:HOME}${localEnv:USERPROFILE}`-style cross-platform path
  logic. Invoke the tool's own entry point directly when testing this.
- PowerShell piping a value to a native exe's stdin can silently inject a UTF-8 BOM that
  `.Trim()` won't remove. Use `--body`/equivalent argument-passing for secrets/exact-match
  values instead of piping.
- `tofu init -lockfile=readonly` needs the committed lockfile to carry hashes for **every**
  platform CI runs on, not just the authoring workstation's.

## Pointers

- `docs/hardening_roadmap.md` — reference of record and threat model. F61 partial-closure note
  above; unchanged otherwise this session.
- `sprints/SD_devcontainer/sprint_plan.md` — Tasks 1–2 done, Task 3–4 next.
- `sprints/S2_identity_least_privilege/sprint_plan.md` — Task 4 step 3 sub-step 3.1 satisfied,
  3.2/3.3 pending human action, unchanged.
