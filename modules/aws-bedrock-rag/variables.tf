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

variable "permissions_boundary_name" {
  type        = string
  description = "Name of the IAM permissions-boundary policy at path /bedrock-rag/, created upstream in glunk-works/global-bootstrap (S2-T0c). The module builds the full ARN from data.aws_caller_identity.current.account_id -- never pass an ARN or a value containing an account id here (BR-D4). No default: this name is owned upstream, not by this module -- defaulting it here too would give the same fact three independent literals to drift out of sync (module default, environment default, upstream resource name)."
}