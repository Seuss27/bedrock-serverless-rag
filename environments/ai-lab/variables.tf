variable "aws_region" {
  type        = string
  description = "The target AWS region for deployment"
  default     = "us-east-1"
}

variable "data_source_bucket_name" {
  type        = string
  description = "The name of the S3 bucket where Bedrock RAG source documents are stored"
}

variable "data_plane_principal_arns" {
  type        = list(string)
  description = <<-EOT
    IAM role ARNs granted data-plane access to the AOSS collection, in addition to the KB
    execution role: this repo's own github-actions-deploy-role and the human operator's SSO
    role. Restricted, not secret (BR-D4) -- source via TF_VAR_data_plane_principal_arns
    locally and a repository variable in CI, never a committed .tfvars. No default on
    purpose: an unset OR empty value must fail plan rather than silently reproduce F5.
    TF_VAR_data_plane_principal_arns must be an HCL list literal, e.g.
    '["arn:aws:iam::<acct>:role/a","arn:aws:iam::<acct>:role/b"]' -- a comma-separated
    string is not accepted.
  EOT
  nullable    = false
  validation {
    condition     = length(var.data_plane_principal_arns) > 0
    error_message = "At least one data-plane principal ARN is required -- an empty list silently reproduces F5 (the CI role loses AOSS data-plane access)."
  }
}

variable "permissions_boundary_name" {
  type        = string
  description = "Name of the IAM permissions-boundary policy at path /bedrock-rag/, created upstream in glunk-works/global-bootstrap (S2-T0c)."
  default     = "bedrock-rag-workload-boundary"
}

variable "budget_limit_usd" {
  type        = string
  description = "Monthly cost guardrail for the ai-lab environment, in USD."
  default     = "20"
}

variable "budget_notification_email" {
  type        = string
  description = <<-EOT
    Address that receives the 50/80/100% budget notifications. No default on purpose --
    an email address in a public repo is spam bait and PII (BR-D4). Set it via
    TF_VAR_budget_notification_email, never committed.
  EOT
  sensitive   = true
}