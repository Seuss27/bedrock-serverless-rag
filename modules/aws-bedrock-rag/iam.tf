# 1. The S3 Ingestion Bucket
# This is the physical bucket where you will upload your RAG source PDFs.
resource "aws_s3_bucket" "bedrock_source" {
  bucket        = var.data_source_bucket_name
  force_destroy = true # Allows easy cleanup during 'tofu destroy' for this demo
}

# Enforce encryption at rest for your source data
resource "aws_s3_bucket_server_side_encryption_configuration" "bedrock_source_encryption" {
  bucket = aws_s3_bucket.bedrock_source.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 2. IAM Role for Amazon Bedrock Knowledge Base
# This allows Bedrock to assume a role to interact with S3 and OpenSearch Serverless.
resource "aws_iam_role" "bedrock_kb_role" {
  name = "personal-bedrock-kb-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# Inline policy giving Bedrock read access to your new S3 bucket and model invocation rights
resource "aws_iam_role_policy" "bedrock_kb_s3_policy" {
  name = "personal-bedrock-kb-s3-policy"
  role = aws_iam_role.bedrock_kb_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ReadLocationStatement"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.bedrock_source.arn,
          "${aws_s3_bucket.bedrock_source.arn}/*"
        ]
      },
      {
        Sid    = "BedrockModelInvocationStatement"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.titan-embed-text-v2:0"
        ]
      },
      {
        Sid    = "OpenSearchServerlessAPIAccessAllStatement"
        Effect = "Allow"
        Action = [
          "aoss:APIAccessAll"
        ]
        Resource = [
          aws_opensearchserverless_collection.vector_store.arn
        ]
      }
    ]
  })
}

# 3. OpenSearch Serverless Data Access Policy
resource "aws_opensearchserverless_access_policy" "data_access_policy" {
  name        = "personal-rag-data-access"
  type        = "data"
  description = "Allow Bedrock and local admin to access collection data plane"
  
  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "index"
          Resource     = ["index/${aws_opensearchserverless_collection.vector_store.name}/*"]
          Permission   = [
            "aoss:CreateIndex",
            "aoss:DeleteIndex",
            "aoss:UpdateIndex",
            "aoss:DescribeIndex",
            "aoss:ReadDocument",
            "aoss:WriteDocument"
          ]
        },
        {
          ResourceType = "collection"
          Resource     = ["collection/${aws_opensearchserverless_collection.vector_store.name}"]
          Permission   = [
            "aoss:CreateCollectionItems",
            "aoss:DeleteCollectionItems",
            "aoss:UpdateCollectionItems",
            "aoss:DescribeCollectionItems"
          ]
        }
      ]
      Principal = [
        aws_iam_role.bedrock_kb_role.arn,
        data.aws_arn.current_identity.arn
      ]
    }
  ])
}

# Helper data blocks to fetch your active AWS account context dynamically
data "aws_caller_identity" "current" {}

data "aws_arn" "current_identity" {
  arn = data.aws_caller_identity.current.arn
}