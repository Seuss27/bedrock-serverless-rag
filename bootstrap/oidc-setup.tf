variable "github_repo_path" {
  type        = string
  description = "The GitHub owner and repo (e.g., your-username/your-repo-name)"
}

# ── ST-T3 WIDEN: TEMPORARY. DELETE THIS BLOCK AT THE NARROW STEP. ────────────
# A second owner accepted by the deploy role's trust policy for the duration of the
# `Seuss27/` → `glunk-works/` repository transfer only (ST-T3, BR-D13).
#
# The discipline is widen → transfer → narrow, never a swap: if the only subject were
# replaced in one apply and it were wrong, CI could not authenticate and could not
# self-correct — the repair needs local admin credentials against `bootstrap/`'s
# single-machine, gitignored state file (F48).
#
# ⚠️ THE NARROW MUST LAND IN THE SAME WORKING SESSION AS THE TRANSFER. Everything works
# without it and nothing gates it, so by default it slips. GitHub usernames are
# RECLAIMABLE: once the transfer completes, `Seuss27/bedrock-serverless-rag` is a free
# name, and until this block is gone a `StringLike` glob admitting every branch and every
# PR under it stands against a role holding `iam:CreateRole` on `*` in an AWS account
# shared with the whole organization.
#
# No `default` on purpose — an unset value must fail the plan loudly, not render an empty
# subject. Narrowing to enumerated subjects (F2) is S2's job, not this transfer's.
variable "github_repo_path_additional" {
  type        = string
  description = "TEMPORARY (ST-T3): second GitHub owner/repo accepted during the org transfer. Delete with the narrow."
}

variable "role_name" {
  type        = string
  description = "The name of the IAM role to create"
  default     = "github-actions-deploy-role"
}

# The OIDC Provider (Only needs to be created once per AWS Account)
#
# SHARED ORGANIZATION-WIDE — DO NOT DELETE.
# An AWS account holds exactly one OIDC provider per URL, and this account is shared:
# `glunk-works/global-bootstrap` consumes THIS provider via
# `data.aws_iam_openid_connect_provider.github` to build every project's CI role. So this
# repo's OpenTofu state owns the federation endpoint that every glunk-works pipeline
# authenticates through — destroying it breaks CI for the whole organization, not just here.
#
# `prevent_destroy` is a plan-time guard, not state: it produces no diff, and it makes
# `tofu destroy` (or any change forcing replacement) fail with an error instead of
# proceeding. It closes the accidental path only — it does not stop someone removing this
# block first, running `tofu state rm`, or deleting the provider outside OpenTofu.
#
# This is a STOPGAP. Ownership belongs upstream: `global-bootstrap` should declare the
# provider as a `resource` with an `import` block, after which this repo drops its
# declaration via `tofu state rm` — never `tofu destroy`.
resource "aws_iam_openid_connect_provider" "github_actions" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  lifecycle {
    prevent_destroy = true
  }
}

# The Parameterized IAM Role
resource "aws_iam_role" "github_actions_role" {
  name = var.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" : "sts.amazonaws.com"
          }
          StringLike = {
            # ST-T3 WIDEN — TEMPORARY; at the narrow this collapses back to the single
            # `"repo:${var.github_repo_path}:*"` scalar and the second entry disappears.
            #
            # A LIST VALUE on the single `:sub` key — NOT two `StringLike` blocks, and not
            # two `:sub` keys in this map, either of which is a duplicate-key error. IAM
            # treats a condition value as a set, so a one-element list and a bare string
            # are equivalent; the widen only adds a member.
            "token.actions.githubusercontent.com:sub" : [
              "repo:${var.github_repo_path}:*",
              "repo:${var.github_repo_path_additional}:*",
            ]
          }
        }
      }
    ]
  })
}