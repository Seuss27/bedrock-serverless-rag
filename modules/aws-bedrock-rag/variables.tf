variable "aws_region" {
  type        = string
  description = "The target AWS region for deployment"
}

variable "data_source_bucket_name" {
  type        = string
  description = "The name of the S3 bucket where Bedrock RAG source documents are stored"
}