# Every OIDC subject prefix this repository is allowed to present, WITHOUT the trailing
# `:*` — that is appended where the condition is built.
#
# This is a LIST because GitHub can emit more than one subject form for the same
# repository, and picking only one silently breaks CI:
#
#   plain            repo:<owner>/<repo>:<context>
#   ID-qualified     repo:<owner>@<org_id>/<repo>@<repo_id>:<context>
#
# The ID-qualified ("immutable") form is what an ORG-OWNED repository can present, and it
# is the reason the `Seuss27/` → `glunk-works/` transfer broke authentication even though
# the trust policy already named the new owner: `repo:glunk-works/bedrock-serverless-rag:*`
# does not match a subject carrying `@<id>` segments. Read the live value rather than
# guessing the format:
#
#   gh api repos/<owner>/<repo>/actions/oidc/customization/sub --jq .sub_claim_prefix
#
# ⚠️ NO `Seuss27` ENTRY, AND NEVER RE-ADD ONE. The transfer is complete, so no run in this
# repository can present the old owner's subject — it has zero fallback value — while
# GitHub usernames are RECLAIMABLE, so a `repo:Seuss27/...` glob admitting every branch
# and every PR would stand against a role holding `iam:CreateRole` on `*` in an AWS
# account shared with the whole organization (ST-T3, BR-D13).
#
# No `default` on purpose: an unset value must fail the plan loudly rather than render an
# empty subject. Narrowing from `StringLike` to enumerated subjects (F2) is S2's job.
variable "github_oidc_subject_prefixes" {
  type        = list(string)
  description = "OIDC subject prefixes allowed to assume the deploy role, without the trailing ':*'."

  validation {
    condition     = length(var.github_oidc_subject_prefixes) > 0
    error_message = "At least one subject prefix is required; an empty list would trust nothing and break CI."
  }

  validation {
    condition     = alltrue([for p in var.github_oidc_subject_prefixes : startswith(p, "repo:")])
    error_message = "Every prefix must start with 'repo:' — a bare owner/repo would not match any GitHub OIDC subject."
  }
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
            # A LIST VALUE on the single `:sub` key — NOT two `StringLike` blocks, and not
            # two `:sub` keys in this map, either of which is a duplicate-key error. IAM
            # treats a condition value as a set, so a one-element list and a bare string
            # are equivalent.
            "token.actions.githubusercontent.com:sub" : [
              for prefix in var.github_oidc_subject_prefixes : "${prefix}:*"
            ]
          }
        }
      }
    ]
  })
}