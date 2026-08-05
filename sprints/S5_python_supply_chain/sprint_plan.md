### FILEPATH: /sprints/S5_python_supply_chain/sprint_plan.md

# S5 — Python quality and supply chain

**Sprint Goal:** Give the Python half of this repo the same deterministic gate the IaC half
has: a real project definition, pinned and audited dependencies, an SBOM, lint and security
rules that match the Global Conventions, and the first tests this repo has ever had.

**Closes:** F29, F30, F31, F32.

**Dependencies:** **S4-T4 must be merged first.** It rewrites `create_index.py` — removing
the destructive delete and the `local-exec` coupling. Writing tests before that change means
writing tests that pin behavior S4 is about to delete, and S4 then lands looking like a
regression against a green suite. **SD should be merged** so the toolchain is pinned; this
sprint adds the Python layer to that image (Task 5).

**Security Considerations:** Two of this sprint's four findings are disclosure issues, not
quality issues. F31 — bare `except Exception` printing the exception to stdout — reaches a
**public** workflow log and can render the collection endpoint and caller identity (BR-D4).
And the dependency work is supply-chain: this code authenticates to AWS with the operator's
credentials, so an unpinned transitive dependency runs with those credentials.

**Risks & Blockers:**
- Hash-pinned requirements break as soon as a platform-specific wheel is missing. Generate
  the lock on the same Linux base the devcontainer and CI use, not on the Windows host.
- `pip-audit` will report real CVEs on first run. Those are findings to record and fix, not a
  reason to soften the gate.

---

## Tasks

- **Task 1: A real dependency pin (F29)**
  - **Description:** `requirements.txt` today uses `~=` ranges, has no hashes, no lock file,
    and carries a **UTF-8 BOM** on line 1 — so its first requirement can parse as `﻿boto3`
    on a strict reader. Replace it:
    1. Strip the BOM. Verify with `head -c3 requirements.txt | xxd` — it must not be
       `ef bb bf`. Write the file **UTF-8 without BOM, LF line endings** (this is the concrete
       reason `.gitattributes` from S0-T5 matters).
    2. Declare direct dependencies in `pyproject.toml` (Task 2) and generate a fully
       hash-pinned, transitively-complete `requirements.lock` with
       `pip-compile --generate-hashes` (or `uv pip compile --generate-hashes`). Generate it
       **inside the devcontainer**, on Linux, so the hashes match the wheels CI resolves.
    3. CI installs from the lock with `pip install --require-hashes -r requirements.lock`.
       `--require-hashes` is the load-bearing flag: a hash file installed without it is a
       comment.
  - **Target Files:** `environments/ai-lab/requirements.lock` (new),
    `environments/ai-lab/requirements.txt` (removed), `pyproject.toml`
  - **Acceptance Criteria:** No file in the repo begins with a BOM — verify across the tree,
    not just this file. `pip install --require-hashes -r requirements.lock` succeeds in a
    clean container. Every line in the lock carries at least one `--hash=sha256:`. The old
    `requirements.txt` is gone and no workflow references it.

- **Task 2: Project definition, lint, and security rules (F30)**
  - **Description:** Add a `pyproject.toml` at the repo root defining the project and its
    tool configuration, per the Global Conventions:
    - `requires-python = ">=3.12"`. **Note the conflict:** CI currently pins 3.11 and the
      conventions require ≥3.12. Resolve it by moving CI to 3.12 in this same PR — do not
      leave the two disagreeing, and do not silently lower the convention.
    - `[tool.ruff]` — `line-length = 100`, `select = ["E", "F", "I", "B", "S"]`
      (pycodestyle, pyflakes, isort, bugbear, bandit). Import ordering is isort-managed; do
      not hand-order.
    - `[tool.bandit]` configured for `-ll` (medium+ severity).
    - `[tool.pytest.ini_options]` with `testpaths` naming the test directory explicitly, so
      collection never wanders into `environments/`.
    - Hatch environments mirroring the sibling repo's names so the two stay diffable:
      `lint:check` (ruff check + ruff format --check + bandit), `lint:fmt`, `test:run`,
      `audit:run` (pip-audit), `sbom:run` (cyclonedx).
    Then fix what the new rules find. **`# noqa` requires an inline justification on the same
    line** (`# noqa: RULE — reason`); a bare `# noqa` fails review.
  - **Target Files:** `pyproject.toml`, `environments/ai-lab/*.py`
  - **Acceptance Criteria:** `hatch run lint:check` exits 0. `ruff check --select S` reports
    no finding, or each is suppressed with an inline justification. `grep -rn 'noqa' --include=*.py .`
    shows no bare `# noqa`. `python -c "import sys; assert sys.version_info >= (3,12)"` matches
    what CI installs.

- **Task 3: The first tests (F30)**
  - **Description:** This repo has no tests. Add `tests/`, and hold to the conventions' bar:
    **every validated I/O boundary needs a test proving invalid input is rejected.**
    Minimum coverage, all hermetic — no AWS call, no network, boto3 and the OpenSearch client
    stubbed:
    - **Index schema:** the mapping `create_index.py` builds matches what `bedrock.tf`'s
      `field_mapping` declares — `bedrock-embedding`, `AMAZON_BEDROCK_TEXT_CHUNK`,
      `AMAZON_BEDROCK_METADATA` — and the `dimension` matches the embedding model's output
      size. This test is the one that earns its keep: the two files declare the contract
      independently today, and a mismatch surfaces as a runtime ingestion failure, not a plan
      error.
    - **Destruction guard (S4-T4):** with `RAG_ALLOW_INDEX_DESTRUCTION` unset, `indices.delete`
      is **never called** — asserted against the stub, not inferred from an exit code. This
      is the negative test the conventions require, on the boundary that can destroy data.
    - **Idempotency:** an existing, matching index produces exit 0 and no mutating call.
    - **Config validation:** a missing `OPENSEARCH_ENDPOINT` or `KNOWLEDGE_BASE_ID` exits
      non-zero with a message, and — per S4-T1 — a missing guardrail id exits non-zero.
    - **No-leak assertion:** the error path does not print the endpoint, an account id, or an
      ARN (F31). Assert on captured stdout/stderr.
  - **Target Files:** `tests/` (new), `pyproject.toml`
  - **Acceptance Criteria:** `hatch run test:run` exits 0. Every test runs with no network and
    no AWS credentials present — verify by running with `AWS_ACCESS_KEY_ID`,
    `AWS_SECRET_ACCESS_KEY`, `AWS_PROFILE` and `AWS_DEFAULT_REGION` unset. The destruction-guard
    test **fails** if the guard is removed — verify by temporarily removing it.

- **Task 4: Stop leaking through the error path, and fix the misnamed script (F31, F32)**
  - **Description:**
    1. Replace both bare `except Exception: print(e)` blocks with logging that catches the
       specific exceptions each path can raise, emits a stable message plus an error **class
       name**, and never interpolates the exception's string representation into a message
       that reaches CI. Boto3 and OpenSearch exception strings render endpoints, ARNs, and
       request ids — on a public repo that is BR-D4 disclosure. Use the `logging` module with
       a configured level, not `print`.
    2. Rename `test_rag.py` → `query_rag.py`. It is an interactive script, not a test, and
       once Task 3 adds pytest, default collection tries to import and run it — which blocks
       on `input()`. Update every reference (`README.md`, `CLAUDE.md`, the roadmap, any
       workflow) in the same commit; `grep -rn 'test_rag' .` must come back empty.
    3. Bound the interactive input: reject an empty query and cap length (e.g. 4 000 chars)
       before it reaches `retrieve_and_generate`.
  - **Target Files:** `environments/ai-lab/create_index.py`,
    `environments/ai-lab/query_rag.py` (renamed), `README.md`, `CLAUDE.md`,
    `docs/hardening_roadmap.md`
  - **Acceptance Criteria:** `grep -rn 'except Exception' environments/` returns nothing.
    `grep -rn 'test_rag' .` returns nothing. Task 3's no-leak test passes. Forcing an
    authentication failure produces a log line naming the error class and **not** the
    endpoint — verified by running it with a deliberately wrong endpoint and reading the
    output.

- **Task 5: Wire it into CI, the devcontainer, and the ruleset**
  - **Description:**
    1. Add four jobs to `ci.yml`, all unchained, job ids only, no `name:` overrides, Python
       3.12, `pip install --require-hashes -r requirements.lock`: **`python-lint`**
       (`hatch run lint:check`), **`python-test`** (`hatch run test:run`),
       **`dependency-audit`** (`hatch run audit:run` — pip-audit), **`sbom`**
       (`hatch run sbom:run`, uploading `sbom.json` as an artifact; the SBOM enumerates this
       project's own third-party dependencies, which are already public in `pyproject.toml`,
       so it carries none of BR-D4's restricted classes).
    2. Add the Python layer to `.devcontainer/Dockerfile` — the deferral SD recorded. Pin
       `hatch` to a version, install it, and remove SD's "Python layer deferred to S5-T5"
       comment.
    3. Append `python-lint`, `python-test`, `dependency-audit`, `sbom` to the live ruleset,
       to `ruleset.required_checks` in `.ai/project.yml`, **and** to the check list in
       `ruleset-drift.yml` — all three in this PR (BR-D9). Append `gates.green` entries for
       `hatch run lint:check` and `hatch run test:run` in the same file.
    4. Add the `pip` ecosystem to `.github/dependabot.yml` — deferred from S0-T5 and SD
       precisely until the lock file exists.
  - **Target Files:** `.github/workflows/ci.yml`, `.devcontainer/Dockerfile`,
    `.ai/project.yml`, `.github/workflows/ruleset-drift.yml`, `.github/dependabot.yml`
  - **Acceptance Criteria:** The live ruleset, `.ai/project.yml`'s `required_checks`, and
    `ruleset-drift.yml`'s list are **identical** — diff all three programmatically. All four
    new checks are green on this PR. `gates.green` runs clean inside the devcontainer from a
    fresh clone. `gh api …/rules/branches/main` shows 12 contexts.

---

## Definition of Done

`gates.green` (now including the Python entries) passes inside the devcontainer. Every
required check green. `pip-audit` reports zero unaddressed vulnerabilities — each finding
either fixed by a version bump or recorded in the roadmap with a stated reason. `/critic-gate`
has run; propose `architect` (test validity — a suite that passes when the guard is removed is
worse than no suite) and `security-critic` (the disclosure paths in Task 4).

---

## Critical review

**Security**

- *A hash-pinned lock installed without `--require-hashes` is decorative.* pip accepts the
  file and ignores the hashes. The flag is called out as load-bearing because the file
  *looks* like the control.
- *`pip-audit` becoming a required check means a new upstream CVE can turn `main` red with no
  change on our side.* Accepted — that is the point of the control, and the response is a
  bump, not a suppression. What must be avoided is the reflex `--ignore-vuln`; any suppression
  needs a roadmap row with a stated reason and a revisit date.
- *The SBOM artifact is safe to publish on a public repo* — it enumerates this project's own
  third-party dependencies, already public in `pyproject.toml`. It carries no account
  identifier, no finding, no corpus data. Stated so nobody later "hardens" it away, and so
  nobody adds an account-scoped artifact beside it by analogy.
- *Task 4's leak fix is easy to do incompletely.* Catching specific exceptions but still
  logging `str(e)` changes nothing — boto3 exception strings render endpoints, ARNs, and
  request ids. The acceptance criterion is an **observed** output from a deliberately failing
  run, not a code read.

**Logic**

- **The 3.11 / ≥3.12 conflict must be resolved, not inherited.** CI pins 3.11; the
  conventions require ≥3.12. Leaving both means the gate enforces one thing and the docs
  claim another, and the sibling repo has an open issue from exactly that drift. Task 2 moves
  CI in the same PR.
- **Task 3's index-schema test is the highest-value test in the sprint** and the least
  obvious: `create_index.py` and `bedrock.tf` declare the same field-mapping contract
  independently, in different languages, with nothing tying them together. A mismatch fails
  at ingestion time with an authorization-shaped error. A test that reads the `.tf` and
  asserts against the Python is the only thing that catches it before apply.
- **A test suite that passes when the guard is removed is worse than no suite**, because it
  licenses the removal. Task 3 requires verifying the destruction-guard test **fails** when
  the guard is deleted. This is the one mutation check in the sprint and it is not optional.
- *Ordering inside the sprint:* Task 1 (lock) → Task 2 (config) → Tasks 3/4 (code) → Task 5
  (CI + ruleset, last). Task 5 last for the same reason S0 and S1 put ruleset changes last:
  requiring a check before its job exists is a deadlock.
- *The rename in Task 4 touches docs across the repo.* A partial rename leaves a doc telling
  a reader to run a file that no longer exists — the exact drift class `docs-consistency`
  exists to catch. `grep -rn 'test_rag' .` returning empty is the criterion.

**Execution**

- *Generate the lock on Linux, in the devcontainer.* A lock generated on Windows can carry
  platform-specific wheel hashes that fail `--require-hashes` on the runner, and the error
  reads like a corrupted file rather than a platform mismatch. This is also the concrete
  payoff for SD landing first.
- *`pyproject.toml` at the repo root vs `environments/ai-lab/`.* Root, because the tests live
  at the root and pytest's `testpaths` should not have to climb out of an environment
  directory. Say so in a comment — the sibling repo puts its `pyproject.toml` under `src/`,
  and a reader diffing the two repos will wonder.
- *Running the suite with AWS credentials present hides accidental network calls*, because
  they succeed. The acceptance criterion requires running with every AWS environment variable
  unset, which is how a stub gap actually surfaces.
