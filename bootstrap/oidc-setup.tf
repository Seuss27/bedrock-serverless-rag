# Every OIDC subject prefix this repository is allowed to present, WITHOUT the trailing
# `:*` — that is appended where the condition is built.
#
# GitHub can emit two subject forms for the same repository, and they are NOT
# interchangeable in an IAM condition:
#
#   plain            repo:<owner>/<repo>:<context>
#   ID-qualified     repo:<owner>@<org_id>/<repo>@<repo_id>:<context>
#
# THIS ORG-OWNED REPOSITORY PRESENTS THE ID-QUALIFIED FORM. That is measured, not inferred
# — CloudTrail `AssumeRoleWithWebIdentity` on 2026-08-06 recorded, on the two runs that
# succeeded after the narrow:
#
#   repo:glunk-works@295891085/bedrock-serverless-rag@1253604712:ref:refs/heads/main
#   repo:glunk-works@295891085/bedrock-serverless-rag@1253604712:pull_request
#
# It is also why the `Seuss27/` → `glunk-works/` transfer broke authentication even though
# the trust policy already named the new owner: `repo:glunk-works/bedrock-serverless-rag:*`
# does not match a subject carrying `@<id>` segments.
#
# ⚠️ DO NOT TRUST THE API FIELD OVER THE EVIDENCE.
# `gh api repos/<owner>/<repo>/actions/oidc/customization/sub` reports
# `use_immutable_subject: false` for this repository while `sub_claim_prefix` carries the
# ID-qualified value and the ID-qualified value is what actually arrives. Read
# `sub_claim_prefix`, and confirm against CloudTrail before changing anything here.
#
# The PLAIN form is deliberately ABSENT. It matched nothing, so it granted nothing — but a
# name-based glob is squattable in a way an id-based one is not: once this repo is renamed
# or its role retired (S2-T2), `glunk-works/bedrock-serverless-rag` frees up INSIDE the
# org, and any member who can create a repository at that name would mint a matching
# subject. Numeric org/repo ids are GitHub-assigned and cannot be reclaimed. If GitHub ever
# reverts to the plain form, CI fails loudly and closed, and the fix is one hand-apply —
# strictly preferable to a standing grant that fails silently and open.
#
# ⚠️ NO `Seuss27` ENTRY, AND NEVER RE-ADD ONE. The transfer is complete, so no run in this
# repository can present the old owner's subject — it has zero fallback value — while
# GitHub usernames are RECLAIMABLE, so a `repo:Seuss27/...` glob admitting every branch
# and every PR would stand against a role holding `iam:CreateRole` on `*` in an AWS
# account shared with the whole organization (ST-T3, BR-D13).
#
# THE DEFAULT IS COMMITTED ON PURPOSE, and that is a security property rather than a
# convenience. `bootstrap/` is in `code_paths` precisely because a diff here changes what
# CI may do in AWS — so the set of principals that can assume a role holding
# `iam:CreateRole` on `*` must not be knowable only from a gitignored file. With the value
# off-tree, a reviewer could not tell whether the live policy admitted two subjects or
# twelve, or whether one of them contained a `*`, and the highest-consequence change in
# this repository could be made with no diff at all.
#
# These values are NOT BR-D4 restricted: a public org name, a public repo name, and two
# GitHub numeric ids anyone can read with
# `gh api repos/glunk-works/bedrock-serverless-rag --jq '.id, .owner.id'`. They were only
# ever off-tree because `.gitignore`'s blanket `*.tfvars` line swept them up. Committing
# also means a fresh clone can `plan` this root at all (cf. F49).
variable "github_oidc_subject_prefixes" {
  type        = list(string)
  description = "OIDC subject prefixes allowed to assume the deploy role, without the trailing ':*'."

  default = [
    "repo:glunk-works@295891085/bedrock-serverless-rag@1253604712",
  ]

  validation {
    condition     = length(var.github_oidc_subject_prefixes) > 0
    error_message = "At least one subject prefix is required; an empty list would trust nothing and break CI."
  }

  validation {
    condition     = alltrue([for p in var.github_oidc_subject_prefixes : startswith(p, "repo:")])
    error_message = "Every prefix must start with 'repo:' — a bare owner/repo would not match any GitHub OIDC subject."
  }

  # THE ONLY VALIDATION THAT GUARDS A FAIL-OPEN INPUT. The two above reject values that
  # already matched nothing — they fail closed on their own. A wildcard does the opposite:
  # in IAM `StringLike`, `*` matches `:` too, so `["repo:*"]` renders `repo:*:*` and admits
  # EVERY GitHub OIDC subject in existence — any stranger's repo — against a role holding
  # `iam:CreateRole` on `*` in the shared account. `?` is an IAM wildcard as well.
  # This is the mechanism the roadmap names in F2; nothing scans `bootstrap/` (F19), so
  # this validation is the only thing standing between a fat-fingered glob and that grant.
  validation {
    condition = alltrue([
      for p in var.github_oidc_subject_prefixes :
      !strcontains(p, "*") && !strcontains(p, "?")
    ])
    error_message = "A subject prefix may not contain '*' or '?': in IAM StringLike both are wildcards that match ':' too, so one would widen this trust policy far beyond this repository."
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