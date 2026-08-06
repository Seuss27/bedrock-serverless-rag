### FILEPATH: /sprints/SD_devcontainer/sprint_plan.md

# SD — Development container

> **⚠ DEFERRED, 2026-08-05, by BR-D23 — with a stated precondition. Do not execute this sprint.**
>
> **The precondition is Docker on the workstation, which does not exist today.** That makes SD
> undeliverable regardless of merit — a fact, not a judgement, and it is why this is "deferred"
> rather than "optional": there is nothing to re-argue each sprint. **Revisit when Docker is
> available**, and not before.
>
> On the merits, recorded so the decision is not re-litigated from scratch:
>
> - It creates a **permanent obligation** (BR-D15: every pin kept *equal* to CI's, forever, on
>   every future tool bump) — the largest capability investment in the roadmap.
> - Against the smallest demonstrated pain. The frictions actually **observed** are two: CRLF
>   (already fixed by `.gitattributes` in S0-T5) and the `-backend=false` wrinkle (already two
>   lines in `CLAUDE.md`).
> - **It was never actually parallel.** Three of its five tasks read values out of files S1
>   creates, so the "runs alongside everything" premise in the header below is wrong.
>
> **If it is ever picked up: it must not gate S5.** S5's dependency on it is removed.

**Sprint Goal:** Make the green gate reproducible. `Reopen in Container` gives any
contributor — and any agent session — the exact pinned toolchain the CI checks run, on one
Linux base, so local results and CI results are the same result.

**Closes:** BR-D15 (new decision, recorded by this sprint). No `F` finding — this is capability
work, not remediation. It removes a recurring **class** of friction rather than a defect:
Windows/PowerShell/CRLF drift, a missing `jq`, a `tofu` version that differs from the runner's.

**Dependencies:** **S0 must be merged** (so this lands through a PR). Independent of S1–S4 —
it touches no `.tf`, no workflow, and no AWS resource. **Run it in parallel**, ideally
immediately after S0 so every later sprint's green gate runs in a pinned environment.

**Second beat, deliberately deferred:** the Python half of the image (hatch, ruff, bandit,
pytest, pip-audit) is **not** in scope here — S5 defines that toolchain, and pinning
`pip install -r requirements.txt` today would pin a file S5 replaces (F29). SD ships the IaC
and workflow toolchain; **S5-T5 adds the Python layer to this image.** Say so in the
Dockerfile so a reader does not "complete" it prematurely.

**Security Considerations:** A devcontainer is a supply-chain artifact — every tool it
installs runs with the developer's credentials on the developer's machine. Two rules:
**every binary is version-pinned and SHA256-verified before use** (no `curl | sh`, no
`@latest`, no unverified download), and **no credential material is baked into the image or
committed**. AWS SSO credentials, the `.env` file, and the `gh` token stay on the host and
are reached by mount or by re-authentication inside the container.

**Risks & Blockers:**
- Requires Docker Desktop (or an equivalent) on the workstation. If it is not present, this
  sprint cannot be verified and must not be marked done on the strength of the file
  contents alone — a devcontainer that has never been built is a guess.
- `.gitattributes` (S0-T5) must already be in place, or the image will be built from a tree
  containing CRLF scripts that fail as `bad interpreter: /bin/bash^M` inside Linux.

---

## Tasks

- **Task 1: The pinned image**
  - **Description:** Create `.devcontainer/Dockerfile` from
    `mcr.microsoft.com/devcontainers/base:bookworm`. Install, each with an `ARG <TOOL>_VERSION`
    and an `ARG <TOOL>_SHA256`, downloaded then verified with
    `echo "${SHA}  /tmp/file" | sha256sum -c -` **before** it is unpacked or made executable:
    - **`tofu`** — the version must match what `opentofu/setup-opentofu` resolves in CI. If
      the workflow pins only the action version and not a tofu version, pin a specific tofu
      release **here** and add `tofu_version:` to the workflow's `with:` in the same PR, so
      the two cannot drift. State which you did in a comment.
    - **`tflint`** — pinned to the same version as `terraform-linters/setup-tflint` in
      `ci.yml`, so local and CI lint output match byte for byte.
    - **`checkov`** — via `pip install --break-system-packages checkov==<version>`, pinned.
    - **`gitleaks`**, **`zizmor`** — the binaries behind the `secrets-scan` and `zizmor` CI
      jobs, so a contributor can reproduce a failure locally instead of pushing to find out.
    - **`jq`**, **`yq`**, **`curl`**, **`unzip`**, **`ca-certificates`** via apt. `jq` and
      `yq` are not optional: the way-of-working skills shell out to them to read
      `.ai/project.yml` and to summarize plan JSON.
    Where an upstream project publishes a checksum manifest, take the value from it. Where it
    does not, compute the SHA locally from the downloaded asset and **say so in the comment**
    — a self-sourced pin is trust-on-first-use, which is weaker than upstream verification
    and must not be presented as equivalent.
    Add a header comment stating what the image is for (reproducing `gates.green`) and what
    it deliberately excludes (the Python layer, until S5-T5).
  - **Target Files:** `.devcontainer/Dockerfile`
  - **Acceptance Criteria:** `docker build .devcontainer/` succeeds. Inside the built image,
    each of `tofu version`, `tflint --version`, `checkov --version`, `gitleaks version`,
    `zizmor --version`, `jq --version`, `yq --version` prints the pinned version. No `RUN`
    line contains `latest`, `curl … | sh`, or a download that is used before its
    `sha256sum -c` succeeds.

- **Task 2: `devcontainer.json`**
  - **Description:** Create `.devcontainer/devcontainer.json`:
    - `"name": "bedrock-serverless-rag"`, `"build": {"dockerfile": "Dockerfile"}`
    - `features`: `ghcr.io/devcontainers/features/github-cli:1` and
      `ghcr.io/devcontainers/features/aws-cli:1`. **Commit the generated
      `.devcontainer/devcontainer-lock.json`** — a feature reference without a lock file is
      an unpinned dependency that executes at build time, which is the same class of problem
      as an unpinned action.
    - `customizations.vscode.extensions`: `hashicorp.terraform`, `ms-python.python`,
      `charliermarsh.ruff`, `GitHub.vscode-pull-request-github`, `anthropic.claude-code`.
    - `"remoteUser": "vscode"`. **No `--privileged`, no `runArgs`, no docker-in-docker** —
      nothing in this repo builds or runs a container, so none of it is justified here.
    - `postCreateCommand`: `git config --global --add safe.directory ${containerWorkspaceFolder}`
      and a one-line readiness echo naming the pinned tools.
    - **Credentials:** mount the host AWS config read-only —
      `"source=${localEnv:HOME}${localEnv:USERPROFILE}/.aws,target=/home/vscode/.aws,type=bind,consistency=cached,readonly"` —
      so `aws sso login` state on the host is usable inside without copying secrets into the
      image. Do **not** put `INFISICAL_*`, `AWS_ACCESS_KEY_ID`, or any `TF_VAR_` secret into
      `containerEnv` as a literal; if one is needed, reference `${localEnv:…}` so the value
      stays on the host.
  - **Target Files:** `.devcontainer/devcontainer.json`,
    `.devcontainer/devcontainer-lock.json`
  - **Acceptance Criteria:** `Reopen in Container` succeeds from a clean clone. Inside:
    `gh auth status` and `aws sts get-caller-identity` both work (the latter after an
    `aws sso login`) — and **`aws sts get-caller-identity` output is not pasted anywhere**,
    it renders the account id (BR-D4). `git status` is clean and reports no permission
    complaint about a dubious ownership.

- **Task 3: Run the real green gate inside the container**
  - **Description:** Execute every entry of `gates.green` from `.ai/project.yml` inside the
    container, from a **fresh clone** (not the host-mounted workspace, which carries a
    `.terraform/` directory already initialized against the S3 backend — `-backend=false`
    fails there, reaching for credentials and dying on IMDS; this is documented in
    `CLAUDE.md` and is exactly the kind of local-only wrinkle the container exists to
    eliminate for everyone else). Then run `tflint --recursive`, `checkov -d .`, and
    `zizmor .github/workflows/`, and confirm each produces the same verdict CI produces on
    the same commit.
    If any verdict differs from CI, that difference **is** the sprint's finding — record it
    in `docs/hardening_roadmap.md` and reconcile the version pin, rather than accepting a
    container that disagrees with the gate it exists to reproduce.
  - **Target Files:** `docs/hardening_roadmap.md` (only if a divergence is found)
  - **Acceptance Criteria:** All `gates.green` entries exit 0 inside the container from a
    fresh clone. `tflint`, `checkov` and `zizmor` verdicts match the corresponding CI job
    conclusions on the same commit — compared, not assumed.

- **Task 4: Document it, and record the decision**
  - **Description:** Add `.devcontainer/README.md`: what the image contains and why each tool
    is there, how credentials reach the container (host mount + `aws sso login` inside, never
    baked), the `.terraform/` fresh-clone wrinkle from Task 3, and how to bump a pinned
    version (change the `ARG`, recompute the SHA, rebuild, re-run Task 3's comparison).
    Add **BR-D15** to `docs/hardening_roadmap.md` § 4: *the devcontainer is the reproducible
    local green gate; every tool in it is version-pinned and checksum-verified, and its pins
    are kept equal to the CI job pins — a divergence between them is a defect in this repo,
    not a local quirk.*
    Add a line to `CLAUDE.md` § Commands pointing at the container as the supported way to
    run the gate, and note in `.ai/project.yml` — as a **comment only** — that `gates.green`
    is expected to be run inside it. Do not add a schema key for this; the plugin's schema
    does not have one and inventing a local key would be the "override is a bug report"
    failure.
  - **Target Files:** `.devcontainer/README.md`, `docs/hardening_roadmap.md`, `CLAUDE.md`,
    `.ai/project.yml`
  - **Acceptance Criteria:** BR-D15 exists in the decisions table. `.devcontainer/README.md`
    names every pinned tool and its version, and those versions match the `ARG` values in the
    Dockerfile — diff them, do not eyeball them. No new key was added to `.ai/project.yml`.

- **Task 5: Keep the pins from rotting**
  - **Description:** Add a `docker` ecosystem entry to `.github/dependabot.yml`
    (`directory: /.devcontainer`, weekly) so base-image updates surface as PRs rather than as
    a silently ageing image. **Do not** add a CI job that builds the image on every PR: a
    build that pulls five pinned release assets over the network is a slow, flaky check whose
    failure mode is usually "GitHub releases was briefly unavailable," and a flaky required
    check trains people to re-run without reading. If image rot becomes a real problem, a
    weekly scheduled build — not a per-PR gate — is the right instrument; record that as the
    reasoning in the file.
  - **Target Files:** `.github/dependabot.yml`
  - **Acceptance Criteria:** `.github/dependabot.yml` has exactly two ecosystem entries
    (`github-actions` from S0-T5, `docker` from here) and still no `pip` entry — `pip` waits
    for S5, when `requirements.txt` is replaced. No new required check was added.

---

## Definition of Done

`gates.green` passes **inside the container from a fresh clone**. All S0/S1 required checks
green on the PR. The image has actually been built and entered — not merely described.
`/critic-gate` has run; propose `security-critic` (an image that runs with developer
credentials is a supply-chain surface: unpinned downloads, baked secrets, over-broad mounts)
and `docs-consistency` (this sprint edits `CLAUDE.md`, the roadmap, and `.ai/project.yml`).

---

## Critical review

**Security**

- *An unverified download in a Dockerfile is a supply-chain compromise with a friendly face.*
  Every binary is pinned **and** SHA-verified before use, and the verification must precede
  the `chmod +x` — verifying after execution is theatre. The Dockerfile is required to be
  honest about which checksums are upstream-published and which were self-computed; those
  are different trust levels and collapsing them in a comment is the failure mode.
- *Mounting `~/.aws` read-only is the right trade, but it is a real widening.* Anything
  running in the container can read the host's AWS config and cached SSO tokens. That is
  already true of anything running on the host, so the marginal risk is the container's own
  contents — which is exactly why Task 1 forbids unpinned downloads. Read-only prevents the
  container from writing a profile the host would later trust.
- *`${localEnv:HOME}${localEnv:USERPROFILE}` looks like a hack and is one*, but it is the
  documented way to write one mount that resolves on both Linux/macOS and Windows: exactly
  one of the two is set. Verify the resolved path on the actual workstation before declaring
  Task 2 done — a mount that silently resolves to nothing yields "credentials not found,"
  which reads like an SSO problem.
- *No `--privileged`, no docker-in-docker.* The sibling repo needs both because it runs
  untrusted model code in an inner container; this repo runs neither. Copying its `runArgs`
  would widen the host-escape surface for no capability, which is precisely how a template
  spreads a risk its original justified.

**Logic**

- **The Python layer is deliberately absent, and that is the most likely thing to be "fixed"
  wrongly.** Pinning today's `requirements.txt` bakes a BOM-prefixed, `~=`-ranged file (F29)
  that S5 replaces outright — the image would then be wrong within one sprint and the rebuild
  would look like churn. The deferral is stated in the Dockerfile itself, not only here,
  because the Dockerfile is what a future contributor reads.
- **A pin that is not equal to CI's pin is worse than no pin**, because it produces confident
  local results that disagree with the gate. Task 1 requires reconciling `tofu`'s version
  with the workflow — including, if necessary, adding a `tofu_version:` to the workflow in
  the same PR. A container that reproduces a *different* environment reproducibly has solved
  nothing.
- **Task 3 must run from a fresh clone, not the mounted workspace.** The host workspace has a
  `.terraform/` already initialized against the S3 backend, so `-backend=false` reaches for
  credentials and fails — which would make the gate look broken inside a container that is
  actually fine, or, worse, get "fixed" by weakening the gate.
- *Why no per-PR image build?* A build pulling five release assets over the network is flaky
  in a way that is indistinguishable from a real failure, and a flaky required check trains
  people to click re-run without reading — which is how a genuine failure gets waved through.
  Dependabot surfaces rot at the same cadence with none of that cost.
- *Placement.* SD has no dependency on S1–S4 and every later sprint benefits from it, so
  running it right after S0 maximizes its value. It is numbered with a letter prefix, not
  inserted into the sequence, because renumbering S2–S6 would invalidate every cross-reference
  already written into the roadmap and the other plans — and the sibling repo already uses
  letter-prefixed parallel sprints (`SC`, `SE`, `SG`) for exactly this.

**Execution**

- *This sprint cannot be verified without Docker on the workstation.* If Docker is absent,
  the honest outcome is to write the files and mark the sprint **blocked**, not done. A
  devcontainer that has never been built is a plausible-looking guess, and the failures
  (a wrong SHA, a base tag that does not exist, a mount that resolves to nothing) are all
  build-time — invisible to review.
- *Base image tags are easy to get wrong.* The sibling repo's Dockerfile records that
  `debian-bookworm` is not a published tag and `bookworm` is. Verify the tag against the
  registry rather than inferring it from the image's documentation.
- *Committing `devcontainer-lock.json` is easy to skip* because everything works without it —
  right up until a feature publishes a new version and the image changes under you. It is
  listed as a target file for that reason.
