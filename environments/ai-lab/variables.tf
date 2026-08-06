variable "aws_region" {
  type        = string
  description = "The target AWS region for deployment"
  default     = "us-east-1"
}

variable "data_source_bucket_name" {
  type        = string
  description = "The name of the S3 bucket where Bedrock RAG source documents are stored"
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