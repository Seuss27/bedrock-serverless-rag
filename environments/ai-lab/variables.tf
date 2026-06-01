variable "aws_region" {
  type        = string
  description = "The target AWS region for deployment"
  default     = "us-east-1"
}

# variable "infisical_workspace_id" {
#   type        = string
#   description = "The project/workspace ID from your Infisical dashboard"
# }

variable "data_source_bucket_name" {
  type        = string
  description = "The name of the S3 bucket where Bedrock RAG source documents are stored"
}