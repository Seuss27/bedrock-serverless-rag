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

# 2. The DynamoDB Table for State Locking
# This prevents GitHub Actions and your local laptop from modifying infrastructure at the exact same time.
resource "aws_dynamodb_table" "tofu_locks" {
  name         = "bedrock-lab-state-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# GitHub Actions access to s3 bucket and table
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
      {
        Effect = "Allow"
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = aws_dynamodb_table.tofu_locks.arn
      },
      # Least Privilege Infrastructure Permissions
      {
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:PutBucket*",
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
          "aoss:GetSecurityPolicy",
          "aoss:ListSecurityPolicies",
          "aoss:BatchGetCollection",
          "aoss:CreateSecurityPolicy",
          "aoss:DeleteSecurityPolicy",
          "aoss:CreateCollection",
          "aoss:DeleteCollection",
          "aoss:UpdateCollection",
          "bedrock:CreateKnowledgeBase",
          "bedrock:DeleteKnowledgeBase",
          "bedrock:CreateDataSource",
          "bedrock:DeleteDataSource"
        ],
        Resource = "*" # This should be locked down outside of lab use
      }
    ]
  })
}