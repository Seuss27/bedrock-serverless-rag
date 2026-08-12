---
name: tofu-local-plan
description: Run a REAL tofu plan/apply against AWS from this workstation (SSO login, the required TF_VAR_ env vars, why a bare checkout can't do this), and how to debug Git Bash's gpg-vs-git-signing-key mismatch when commit signing needs debugging. Use when actually running a credentialed tofu plan/apply locally, or when `git commit` signing fails and needs debugging.
---

# Running a real `tofu plan`/`apply` locally

`environments/ai-lab`'s `gates.green` entry (`tofu init -backend=false && tofu validate`)
needs no AWS credentials. A **real** `plan`/`apply` against the S3 backend does, and does not
run cleanly from a bare checkout by design.

```powershell
aws sso login --profile admin-sso

# `TF_VAR_<name>` is OpenTofu's own variable mechanism and `AWS_PROFILE` is the SDK's — no
# wrapper is involved in either. The first three are what the (deleted) Invoke-Tofu.ps1
# wrapper used to inject; the fourth arrived with S0's `budget.tf`, the fifth with MW-T4's
# AOSS principal fix, the sixth with S2-T2's state encryption — all six are just as required.
$env:AWS_PROFILE                      = 'admin-sso'   # bootstrap/providers.tf sets no profile (F49)
$env:TF_VAR_aws_region                = '<region>'    # has a default; override only if needed
$env:TF_VAR_data_source_bucket_name   = '<bucket>'    # no default — required
$env:TF_VAR_budget_notification_email = '<email>'     # no default — required; PII, never commit it
$env:TF_VAR_data_plane_principal_arns = '["<deploy-role-arn>","<sso-role-arn>"]'  # no default — required; HCL list literal, not comma-separated
$env:TF_VAR_state_kms_key_arn         = '<kms-key-arn>'  # no default — required by any REAL init (S2-T2/BR-D22, encryption.tf)

tofu -chdir=environments/ai-lab plan
```

`environments/ai-lab/.env` stays as the **gitignored record of which values to set**, not as
something a script sources. Those values are BR-D4 *restricted* — a bucket name and a region on
a public repo are free reconnaissance — so they belong in the shell or a repository variable,
never in a committed `.tf` or `.tfvars`.

**Never reintroduce a wrapper script for this.** `Invoke-Tofu.ps1` was deleted 2026-08-05 for
exactly this reason (F49) — see `CLAUDE.md`'s `## Commands` section for why.

## Debugging commit signing: Git Bash's `gpg` is not the `gpg` git uses

Git Bash resolves a bare `gpg` command to its own bundled `/usr/bin/gpg`, which has an
**empty keyring** — running `gpg --list-secret-keys` or a manual `gpg --clearsign` there to
debug commit signing proves nothing about what `git` actually does. `git` (and PowerShell)
resolve to the real Windows GnuPG install instead (`gpg.exe` under `Program Files\GnuPG\bin`),
which holds the key `user.signingkey` points at. If commit signing needs debugging, invoke
that binary explicitly or just retry the real `git commit` — don't diagnose from a bare `gpg`
call in Git Bash. Separately, if the workstation has more than one secret key, a manual `gpg`
command with no `-u` picks GnuPG's own default key, which is not necessarily the one `git` is
configured to sign with — a mismatch there is not evidence of misconfiguration.
