# state-backend.tf

variable "state_bucket_name" {
  type        = string
  description = "Globally unique name for the S3 state bucket"
  default     = "personal-bedrock-lab-state" # CHANGE THIS to be globally unique
}

# 1. The S3 Bucket to hold the state file
resource "aws_s3_bucket" "tofu_state" {
  bucket = var.state_bucket_name

  # Prevents accidental deletion of the state bucket
  lifecycle {
    prevent_destroy = true
  }
}

# Enable versioning so you can roll back if a state file gets corrupted
resource "aws_s3_bucket_versioning" "tofu_state_versioning" {
  bucket = aws_s3_bucket.tofu_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption by default
resource "aws_s3_bucket_server_side_encryption_configuration" "tofu_state_crypto" {
  bucket = aws_s3_bucket.tofu_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Used only to build partial-scope Resource ARNs below (role/collection wildcards) --
# never for principal identification (that mistake is F5).
data "aws_caller_identity" "current" {}

# GitHub Actions access to s3 bucket
resource "aws_iam_role_policy" "state_access_policy" {
  name = "OpenTofuStateAccess"
  role = aws_iam_role.github_actions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.tofu_state.arn,
          "${aws_s3_bucket.tofu_state.arn}/*"
        ]
      },
      # Least Privilege Infrastructure Permissions
      {
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          # S3's HeadBucket API returns 403 for BOTH "no permission" and "bucket doesn't
          # exist" (a deliberate AWS anti-enumeration measure), and the AWS provider reads
          # that 403 as "resource no longer exists" during refresh. The state bucket's own
          # s3:ListBucket grant above doesn't cover this bucket, so CI's refresh of
          # aws_s3_bucket.bedrock_source misreported it as deleted and planned to recreate
          # it. Measured live 2026-08-07, MW-T6: local admin-SSO plan was clean while CI's
          # was not, across two separate CI runs. Read-only verb; flat here matching the
          # rest of this statement's style, unlike s3:DeleteObject which stays scoped given
          # force_destroy = true on the source bucket.
          "s3:ListBucket",
          "s3:PutBucket*",
          # GetBucket* covers most of the AWS provider's bucket-refresh reads (Acl, Cors,
          # Logging, Policy, Replication is NOT one of these -- see below -- RequestPayment,
          # Tagging, Versioning, Website). A handful of S3 config-read/write actions do NOT
          # carry "Bucket" in their IAM action name despite the API being bucket-scoped, so
          # this wildcard does not reach them -- granted explicitly instead. This is exactly
          # F55's originally-named gap (`s3:PutBucket*` matches neither encryption verb);
          # closing it needs the real action names, not the CloudTrail API-operation names
          # they were harvested as. Cross-checked against the service authorization
          # reference, not just CloudTrail -- confidence high but not exhaustively verified;
          # re-check against a live plan before trusting this list for the destroy path too.
          "s3:GetBucket*",
          "s3:GetEncryptionConfiguration",
          "s3:PutEncryptionConfiguration",
          "s3:GetLifecycleConfiguration",
          "s3:GetReplicationConfiguration",
          "s3:GetAccelerateConfiguration",
          "s3:DeleteBucket",
          "iam:CreateRole",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:DeleteRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:GetRole",
          "iam:ListRolePolicies",
          "iam:GetRolePolicy",
          # Required for refresh, not for any create/update the pipeline performs: the AWS
          # provider calls ListAttachedRolePolicies whenever it reads an aws_iam_role, which
          # CI does for bedrock_kb_role on every plan. It was granted out-of-band and existed
          # only in live AWS until this line; committing it makes the plan clean (F50).
          "iam:ListAttachedRolePolicies",
          "aoss:GetSecurityPolicy",
          "aoss:ListSecurityPolicies",
          "aoss:BatchGetCollection",
          "aoss:CreateSecurityPolicy",
          "aoss:DeleteSecurityPolicy",
          "aoss:CreateCollection",
          "aoss:DeleteCollection",
          "aoss:UpdateCollection",
          # aws_opensearchserverless_access_policy management -- MW-T5, measured.
          "aoss:CreateAccessPolicy",
          "aoss:GetAccessPolicy",
          "aoss:UpdateAccessPolicy",
          "aoss:ListTagsForResource",
          "bedrock:CreateKnowledgeBase",
          "bedrock:DeleteKnowledgeBase",
          "bedrock:CreateDataSource",
          "bedrock:DeleteDataSource",
          # Create waiters poll these. MW-T5, measured.
          "bedrock:GetKnowledgeBase",
          "bedrock:GetDataSource",
          # The AWS provider calls ListTagsForResource when refreshing a taggable resource,
          # same class as F50's iam:ListAttachedRolePolicies gap. MW-T5's harvest missed
          # this one -- the admin-SSO apply that produced the harvest never happened to
          # exercise this exact refresh path. Measured live 2026-08-07, MW-T6: CI's first
          # real plan attempt failed AccessDeniedException on exactly this action against
          # the Knowledge Base. This fix closes THIS gap, not the class: it does not mean
          # the create-path harvest is now exhaustive, and it says nothing about the
          # destroy path, which is separately and still unmeasured -- e.g.
          # aoss:DeleteAccessPolicy has no grant here at all, unlike every sibling AOSS
          # resource's delete verb. Regenerate from a real destroy, don't presume from this
          # comment.
          "bedrock:ListTagsForResource"
        ],
        Resource = "*" # This should be locked down outside of lab use
      },
      # AWS Budgets enforces via its coarse ModifyBudget/ViewBudget model, confirmed live: an
      # earlier CI run's budget create failed AccessDenied on ModifyBudget specifically (see
      # sprints/MW_make_it_work/sprint_plan.md "Measured live state"), not on any of the
      # finer-grained action names the IAM reference also lists. MW-T5. Unlike most of this
      # statement, Budgets DOES support resource-level scoping (arn:...:budget/<name>) --
      # scoped to it rather than left flat, because ViewBudget on `*` would otherwise let a
      # PR-triggered credential (F2/F3) read this repo's only secret straight out of AWS: the
      # notification email subscriber list, which CLAUDE.md records as the one value in this
      # repo that is PII rather than merely BR-D4 restricted.
      {
        Effect = "Allow"
        Action = [
          "budgets:ModifyBudget",
          "budgets:ViewBudget",
          "budgets:ListTagsForResource"
        ]
        Resource = "arn:aws:budgets::${data.aws_caller_identity.current.account_id}:budget/bedrock-serverless-rag-ai-lab-monthly"
      },
      # iam:PassRole -- needed for the KB's roleArn parameter on CreateKnowledgeBase.
      # Conditioned on the passed-to service per the sprint's scoping decision, AND scoped to
      # the path ST-T2a′ already gives bedrock_kb_role for exactly this purpose (F57) --
      # unlike the flat verbs above, this one costs nothing to scope. MW-T5, measured.
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/bedrock-rag/*"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "bedrock.amazonaws.com"
          }
        }
      },
      # Data-plane grant, distinct from the data-access-policy principal above: without this
      # the caller cannot reach the collection's index/document API at all. F55's "two
      # independent grants" gap; the KB execution role already has it, scoped to its own
      # single collection (modules/aws-bedrock-rag/iam.tf,
      # OpenSearchServerlessAPIAccessAllStatement) -- the CI role did not have it at all.
      # ⚠️ NOT the same scoping, despite the parallel: bootstrap/ cannot see the collection ID
      # (it is generated in a different root), so this is a region-wildcarded `collection/*`,
      # not one collection. Region wildcarded rather than hardcoded to environments/ai-lab's
      # default: that root's `aws_region` is independently overridable (CLAUDE.md § Commands)
      # and a mismatch here would fail closed but undiagnosably. The real residual this
      # leaves: `aoss:CreateAccessPolicy`/`UpdateAccessPolicy` above are still flat on
      # Resource = "*", so this role could rewrite ANY collection's data-access policy to
      # name itself and then reach it via this grant -- narrowed to "any AOSS collection in
      # this account+partition", not closed to "this project's collection only". No second
      # AOSS consumer exists in the shared account today (bounty-infra's archive is S3+KMS),
      # so blast radius is forward-looking, not live. MW-T5, measured.
      {
        Effect   = "Allow"
        Action   = "aoss:APIAccessAll"
        Resource = "arn:aws:aoss:*:${data.aws_caller_identity.current.account_id}:collection/*"
      }
    ]
  })
}

# ⚠️ TEMPORARY WIDEN (MW-T5, F55/F39). Every verb added by MW-T5 above -- and this whole
# resource -- is deleted, not narrowed, by S2-T2 step 3 once CI adopts global-bootstrap's
# roles. Do not treat this policy as a place to converge on least privilege; it goes away
# wholesale. See sprints/S2_identity_least_privilege/sprint_plan.md Task 2, step 3.