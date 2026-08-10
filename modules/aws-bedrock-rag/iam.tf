terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

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

  # Every role this module creates lives under this path (ST-T2a). The path is what a
  # future upstream policy scopes to -- `role/bedrock-rag/*` -- so that the deploy identity
  # can create this role and nothing else. `permissions_boundary` is the other half of that
  # construction and lands in S2, together with the boundary policy it must point at; adding
  # it here first would reference an ARN that does not exist yet.
  #
  # Changing `path` forces replacement. That is free today (BR-D20: the corpus is empty) and
  # is why this lands BEFORE MW rebuilds -- after MW it would cost a second replacement.
  path = "/${local.bedrock_rag_path}/"

  # Boundary policy is created upstream in glunk-works/global-bootstrap (S2-T0c) and referenced
  # here by name only -- the ARN is built from data.aws_caller_identity.current.account_id, never
  # a committed literal or a variable default carrying an account id (BR-D4).
  permissions_boundary = local.permissions_boundary_arn

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
          # The KB's own ARN isn't knowable before the KB exists -- referencing
          # aws_bedrockagent_knowledge_base.rag_kb.arn here is a dependency cycle. Match the
          # pattern instead. Residual: this does not by itself prevent a second knowledge base
          # in this account from also being able to assume this role -- only that no resource
          # outside knowledge-base/* or outside this account can.
          ArnLike = {
            "aws:SourceArn" = "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:knowledge-base/*"
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
  description = "Allow the KB execution role and the granted data-plane principals to access collection data"

  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "index"
          Resource     = ["index/${aws_opensearchserverless_collection.vector_store.name}/*"]
          Permission = [
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
          Permission = [
            "aoss:CreateCollectionItems",
            "aoss:DeleteCollectionItems",
            "aoss:UpdateCollectionItems",
            "aoss:DescribeCollectionItems"
          ]
        }
      ]
      Principal = distinct(concat(
        [aws_iam_role.bedrock_kb_role.arn],
        var.data_plane_principal_arns
      ))
    }
  ])
}

# Helper data block to fetch your active AWS account context dynamically
data "aws_caller_identity" "current" {}

locals {
  # Single source for the path segment every role this module creates lives under, and that
  # the upstream boundary policy also lives under -- CLAUDE.md's "never hardcode a resource
  # name a sibling resource also references as a string" rule, applied to a path shared with
  # an upstream repo instead of a sibling resource in this one.
  bedrock_rag_path         = "bedrock-rag"
  permissions_boundary_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${local.bedrock_rag_path}/${var.permissions_boundary_name}"
}