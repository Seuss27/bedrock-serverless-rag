variable "github_repo_path" {
  type        = string
  description = "The GitHub owner and repo (e.g., your-username/your-repo-name)"
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
            # Injects the variable dynamically
            "token.actions.githubusercontent.com:sub" : "repo:${var.github_repo_path}:*"
          }
        }
      }
    ]
  })
}