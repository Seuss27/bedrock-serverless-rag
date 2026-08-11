# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`SD` (devcontainer) is the priority for the next session.** `S2` Task 4 PR A —
[PR #114](https://github.com/glunk-works/bedrock-serverless-rag/pull/114) — **merged**
2026-08-11T14:22:19Z. `S2` keeps running as a parallel thread (SD's own sprint plan says
"run it in parallel" — neither blocks the other); its next action is below, not dropped.

## Just done

- **S2 Task 4 PR A merged.** All required checks green (`pr-title`, `tofu-fmt`,
  `tofu-validate`, `tflint`, `secrets-scan`, `zizmor`, `tofu-plan`). Full record of the
  implementation, the 4-round `/way-of-working:critic-gate` pass, and three live CI bugs found and
  fixed (a missing Linux provider hash, a PowerShell-pipe UTF-8 BOM silently corrupting a
  secret, a GitHub-side job-status reporting glitch) is in `git log -p -- .ai/next-steps.md`
  and in PR #114's own description.
- **`checkov` (non-required check on `ci.yml`) is red, and that is expected, not a defect
  introduced by PR A.** Traced its findings to two already-tracked roadmap rows, not new work:
  - **F7** (`modules/aws-bedrock-rag/iam.tf`, the `bedrock_source` bucket): no public-access
    block, no versioning, no TLS-only policy, no access logging, `force_destroy = true`.
    Scoped to **S3-T2**, part of the not-yet-started S3+S4 sprint.
  - **F6** (AOSS network policy `AllowFromPublic = true`): scoped to **S3-T1**, same sprint.
  - `bootstrap/state-backend.tf`'s bucket findings need **no fix at all** — that whole
    directory is deleted in `S2` Task 5 (already planned), so hardening a bucket about to be
    torn down is wasted work.
  - Some individual `checkov` flags (cross-region replication, event notifications) may never
    get "fixed" as such — they cut against this repo's own BR-D20 ephemerality design. S3-T2
    may end up accepting some as documented residuals rather than fixing them. **Do not treat
    "get `checkov` clean" as a quick task** — it is real S3+S4 sprint work, not tracked here
    as a `next_action` on purpose.

## Next

**Priority 1 — SD (devcontainer), starting fresh next session:**

1. **Correct `sprints/SD_devcontainer/sprint_plan.md`'s deferred banner first, in its own
   small PR.** It currently says the sprint is deferred because Docker is unavailable on the
   workstation — **that has never been true**; Docker has always been available. Rewrite the
   banner per this repo's own banner-vs-body convention (dated, and the body below it — the
   "on the merits" bullets about permanent-obligation cost vs. observed pain — either still
   holds and should stay, or gets struck if the operator's priorities have changed; ask rather
   than assume). Do **not** silently delete the banner; a stale "deferred" claim and a silently
   vanished one are both bad, for different reasons.
2. **Then start SD's Task 1** (`grep -n '^## Tasks' -A 40 sprints/SD_devcontainer/sprint_plan.md`
   for the full spec): `.devcontainer/Dockerfile` from
   `mcr.microsoft.com/devcontainers/base:bookworm`, pinning `tofu`/`tflint`/`checkov`/
   `gitleaks`/`zizmor`/`jq`/`yq` each with an `ARG <TOOL>_VERSION` + `ARG <TOOL>_SHA256`,
   verified before use. Tasks 2 (`devcontainer.json`) and 3 (run the real green gate inside
   the container) follow in order — read the full task list before starting, the security
   considerations section has real constraints (no `--privileged`, credentials mounted
   read-only from the host, never baked into the image).

**Priority 2 — S2 Task 4, parallel, pick up whenever:**

1. Drive Task 4 step 3's verify cycle (full spec:
   `grep -n '^### Task 4' -A 200 sprints/S2_identity_least_privilege/sprint_plan.md`): a
   merge-triggered `tofu-plan-main` → `tofu-apply` should plan `12 to add` and, after the
   human clicks the `production` Environment approval, succeed (exercises the create verbs
   under the new apply role) — then dispatch `destroy-ai-lab` (typed confirm phrase, human
   watches live, BR-D25) to exercise the destroy verbs. Capture both run links per Task 4's
   acceptance criteria.
2. Then PR B (Task 4 step 4: delete `bootstrap/`'s escalation-capable role +
   `state_access_policy` — human apply) and PR C (step 5: require `tofu-plan` as the
   seventh check).

**Model: `sonnet` / coder** for both threads.

## Open gates and blockers

**HITL Gate: OPEN, but only on the S2 thread.** Task 4 step 3's verify cycle carries two
human-gated steps already built into the pipeline (the Environment approval, the destroy
confirm phrase) — do not begin it unattended. **The SD thread has no open gate**: the banner
correction and Task 1 are both auto-startable once a session picks them up.

**Not filed, deliberately** (`security-critic` #1, LOW, carried from `S2` Task 2): no required
check can *see* `encryption.tf`'s `enforced = true`, so deleting it passes all six required
checks green. Details in `.ai/state.json`'s `known_followups`.

**Process notes worth carrying forward:**
- The action classifier blocks some agent-run commands in this repo/session (`gh secret set`
  observed) — secret rotation needs the human to run handed-over commands directly.
- **PowerShell + piping a value to a native exe's stdin can silently inject a UTF-8 BOM** that
  `.Trim()` won't remove. Use `--body`/equivalent argument-passing for exact-match values
  (secrets, tokens) instead of piping.
- `tofu init -lockfile=readonly` needs the committed lockfile to carry hashes for **every**
  platform CI runs on, not just the authoring workstation's.

## Pointers

- `docs/hardening_roadmap.md` — reference of record and threat model. F6/F7 are the `checkov`
  findings' home; unchanged this session otherwise.
- `sprints/S2_identity_least_privilege/sprint_plan.md` — Tasks 0–4(PR A) done; step 3 cycle
  next, then PR B, PR C.
- `sprints/SD_devcontainer/sprint_plan.md` — **stale deferred banner, correct first.**
