# syntax=docker/dockerfile:1
#
# Reproduces this repo's `gates.green` (tofu fmt / tofu validate) plus the
# pinnable CI tool checks (tflint, checkov, gitleaks, zizmor -- NOT
# `python-lint`'s ruff/bandit, which this image does not install), so
# `Reopen in Container` gives close to the same toolchain the CI checks run, on
# one Linux base (SD sprint, docs/hardening_roadmap.md BR-D15).
#
# Every DOWNLOADED RELEASE ASSET below is version-pinned and SHA256-verified
# BEFORE it is unpacked or made executable -- no `curl | sh`, no `@latest`
# release tag, no unverified download. That does not cover apt packages
# (verified by apt's own signed-repo mechanism instead) or `pip install
# checkov` (pip checks the artifact against PyPI's OWN published hash, not a
# value recorded in this repo the way the four ARGs below are -- see the
# checkov block for the exact distinction). Pins are kept EQUAL to what
# .github/workflows/{ci,plan,deploy}.yml resolve, not just "a recent version"
# -- a divergence between this image and CI is a defect in this repo, not a
# local quirk (BR-D15). Where each pin was checked against a live CI run is
# noted per tool below.
#
# amd64-only: every download below hardcodes a linux_amd64/x64 asset against a
# multi-arch base. The smoke-test layer right before `USER vscode` exists
# specifically to fail the BUILD on an arm64 host instead of failing every
# tool at runtime with a silent `exec format error`.
#
# Deliberately OUT of scope here: the Python toolchain (hatch, ruff, bandit,
# pytest, pip-audit) -- S5 defines that toolchain and S5-T5 adds it to this
# image. Do not "complete" it here. Any layer S5-T5 adds MUST go ABOVE the
# `USER vscode` line -- a `RUN pip install` appended after it runs as uid 1000
# and fails on a system-wide install.
FROM mcr.microsoft.com/devcontainers/base:bookworm@sha256:73d85a96694a2cadca1ba3fcb5721f2312a64f1d571dd86f6c77e10a708931dc

# jq/yq: the way-of-working skills shell out to them to read .ai/project.yml and
# to summarize plan JSON -- not optional. curl/unzip/ca-certificates: needed to
# fetch and verify the pinned binaries below. python3-pip: installs checkov
# below. All six via apt, whose package integrity is verified by apt itself
# (signed repo metadata), not a per-binary SHA256 pin the way a bare GitHub
# release asset needs one.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        jq \
        yq \
        curl \
        unzip \
        ca-certificates \
        python3-pip \
    && rm -rf /var/lib/apt/lists/*

# --- tofu -----------------------------------------------------------------
# The workflow previously pinned only the setup-opentofu ACTION version
# (a1320f89... # v2.0.2) and left `tofu_version` unset, which setup-opentofu
# resolves as "latest" -- a floating target this image cannot match reliably.
# Fixed in the same PR that adds this Dockerfile: ci.yml, plan.yml and
# deploy.yml now all pass an explicit `tofu_version:`, pinned to the same value
# as below, so the two cannot drift apart silently.
ARG TOFU_VERSION=1.12.5
ARG TOFU_SHA256=a6894d45ae7a17ce83189cce8fe04b5a65f68cefceb62455b5a6a89fa53ab38f
RUN curl -fsSL -o /tmp/tofu.tar.gz \
        "https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}/tofu_${TOFU_VERSION}_linux_amd64.tar.gz" \
    && echo "${TOFU_SHA256}  /tmp/tofu.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/tofu.tar.gz -C /usr/local/bin tofu \
    && chmod +x /usr/local/bin/tofu \
    && rm /tmp/tofu.tar.gz

# --- tflint -----------------------------------------------------------------
# terraform-linters/setup-tflint@6e1e064... (# v6.3.0) previously floated
# `tflint_version: latest` in ci.yml with NO explicit pin -- corrected in the
# same PR as this Dockerfile, the same way as tofu: ci.yml's `tflint` job now
# passes `tflint_version: '0.64.0'` explicitly (the action DOES support this
# input plus a `checksums:` input; an earlier draft of this comment claimed no
# such override existed, which was false and would have left `tflint` -- a
# REQUIRED check -- floating). Verified equal to CI's resolution before the
# pin, against run 31504008713 (2026-08-11): `TFLint version 0.64.0`.
ARG TFLINT_VERSION=0.64.0
ARG TFLINT_SHA256=cca9d13e2e1d7a2c627af60ff899a3c9b74212899416aeb96ec764d2ef954537
RUN curl -fsSL -o /tmp/tflint.zip \
        "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_amd64.zip" \
    && echo "${TFLINT_SHA256}  /tmp/tflint.zip" | sha256sum -c - \
    && unzip -o -q -j /tmp/tflint.zip tflint -d /usr/local/bin \
    && chmod +x /usr/local/bin/tflint \
    && rm /tmp/tflint.zip

# --- checkov ------------------------------------------------------------------
# Not a CI gate (non-required check, F6/F7 tracked separately), but still kept
# equal to what bridgecrewio/checkov-action@9b70310... (# v12.3115.0) resolves
# -- that action runs checkov from a docker image with the version baked into
# its own pinned SHA (currently 3.3.9), so unlike tofu/tflint this one cannot
# drift until the action's SHA is bumped; verified against run 31504008713
# (2026-08-11): "By Prisma Cloud | version: 3.3.9".
#
# HONEST ABOUT WHAT THIS PIN BUYS, per this sprint's own bar for not collapsing
# trust levels in a comment: pip DOES check each downloaded artifact against
# the SHA256 PyPI's own index publishes for it (confirmed: checkov 3.3.9's
# wheel is served with a `sha256` digest in PyPI's index, and pip verifies
# against it even without `--require-hashes` -- that flag makes a hash
# MANDATORY per requirement, it is not what turns checking on). So the trust
# anchor here is PyPI's index AT BUILD TIME, not a value recorded in this
# repo the way the four SHA256 ARGs above are -- weaker because a compromised
# index could serve a matching bad hash alongside a bad artifact, not because
# no check happens. checkov's ~100 transitive dependencies get the same
# per-artifact check, but their VERSIONS are unpinned by this file, so the
# resolved set can change between builds. Installs as root during build.
ARG CHECKOV_VERSION=3.3.9
RUN pip install --break-system-packages --no-cache-dir "checkov==${CHECKOV_VERSION}"

# --- gitleaks -----------------------------------------------------------------
# ci.yml's secrets-scan job runs the digest-pinned
# ghcr.io/gitleaks/gitleaks@sha256:c00b6bd... image directly rather than an
# action. Confirmed by resolving the registry tag itself (not by reading a run
# log -- gitleaks never prints its own version into that job's log; the only
# "v8.30.1" string there is ci.yml's own trailing shell comment echoed back):
# `ghcr.io/gitleaks/gitleaks:v8.30.1` resolves to `sha256:c00b6bd0...`, an
# exact match to what ci.yml pins.
ARG GITLEAKS_VERSION=8.30.1
ARG GITLEAKS_SHA256=551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb
RUN curl -fsSL -o /tmp/gitleaks.tar.gz \
        "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" \
    && echo "${GITLEAKS_SHA256}  /tmp/gitleaks.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/gitleaks.tar.gz -C /usr/local/bin gitleaks \
    && chmod +x /usr/local/bin/gitleaks \
    && rm /tmp/gitleaks.tar.gz

# --- zizmor -------------------------------------------------------------------
# Matches the binary version zizmorcore/zizmor-action@3dc1ecc... (# v0.6.2)
# resolved in run 31504008713 (2026-08-11): "zizmor v1.29.0". zizmor publishes
# NO upstream checksum manifest for its release assets (checked: no SHASUMS
# file, no per-asset .sha256, nothing in the release notes) -- the SHA256 below
# is self-sourced, computed locally from the downloaded asset. This is
# trust-on-first-use, weaker than the upstream-published checksums used for
# tofu/tflint/gitleaks above, and is not presented as equivalent to them.
ARG ZIZMOR_VERSION=1.29.0
ARG ZIZMOR_SHA256=dd96df044a6e8538d5f423790f453bdd03d49e5b2bcc38214acc41a2f1297839
RUN curl -fsSL -o /tmp/zizmor.tar.gz \
        "https://github.com/zizmorcore/zizmor/releases/download/v${ZIZMOR_VERSION}/zizmor-x86_64-unknown-linux-gnu.tar.gz" \
    && echo "${ZIZMOR_SHA256}  /tmp/zizmor.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/zizmor.tar.gz -C /usr/local/bin zizmor \
    && chmod +x /usr/local/bin/zizmor \
    && rm /tmp/zizmor.tar.gz

# Fails the BUILD, not a future `docker run`, if any binary above was
# extracted wrong, landed off PATH, or can't execute on this host's
# architecture (every download above hardcodes linux_amd64/x64 against a
# multi-arch base -- an arm64 host pulls an arm64 base, every SHA256 above
# still verifies fine since nothing has executed yet, and `docker build`
# would otherwise succeed while every tool below dies at runtime with
# `exec format error`).
RUN tofu version \
    && tflint --version \
    && checkov --version \
    && gitleaks version \
    && zizmor --version \
    && jq --version \
    && yq --version

# devcontainer.json (SD Task 2) sets remoteUser: vscode; default the image the
# same way so `docker run` without that config is not root by surprise. Any
# layer ADDED AFTER THIS LINE (S5-T5's Python toolchain) runs as uid 1000 --
# see the header note.
USER vscode
