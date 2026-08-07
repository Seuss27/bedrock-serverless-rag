variable "aws_region" {
  type        = string
  description = "The target AWS region for deployment"
}

variable "data_source_bucket_name" {
  type        = string
  description = "The name of the S3 bucket where Bedrock RAG source documents are stored"
}

variable "data_plane_principal_arns" {
  type        = list(string)
  description = "IAM role ARNs granted data-plane access to the vector collection. Must be role ARNs (arn:aws:iam::…:role/…), never sts assumed-role ARNs."
  default     = []
  nullable    = false
  validation {
    condition     = alltrue([for a in var.data_plane_principal_arns : can(regex("^arn:aws:iam::[0-9]{12}:role/", a))])
    error_message = "Each principal must be an IAM role ARN, not an sts assumed-role ARN."
  }
}