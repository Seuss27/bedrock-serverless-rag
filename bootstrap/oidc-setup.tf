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
resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
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