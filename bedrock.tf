# 1. The Bedrock Knowledge Base
resource "aws_bedrockagent_knowledge_base" "rag_kb" {
  name     = "serverless-rag-kb"
  role_arn = aws_iam_role.bedrock_kb_role.arn

  # Define the embedding model
  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/amazon.titan-embed-text-v2:0"
    }
  }

  # Map the OpenSearch integration
  storage_configuration {
    type = "OPENSEARCH_SERVERLESS"
    opensearch_serverless_configuration {
      collection_arn    = aws_opensearchserverless_collection.vector_store.arn
      vector_index_name = "bedrock-knowledge-base-default-index"
      
      # These fields must exactly match the index you create in OpenSearch
      field_mapping {
        vector_field   = "bedrock-embedding"
        text_field     = "AMAZON_BEDROCK_TEXT_CHUNK"
        metadata_field = "AMAZON_BEDROCK_METADATA"
      }
    }
  }

  # Ensure IAM permissions exist before attempting to create the KB
  depends_on = [
    aws_iam_role_policy.bedrock_policy_attachment
  ]
}

# 2. The S3 Data Source Attachment
resource "aws_bedrockagent_data_source" "rag_source" {
  knowledge_base_id = aws_bedrockagent_knowledge_base.rag_kb.id
  name              = "s3-document-source"
  
  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn = "arn:aws:s3:::${var.data_source_bucket_name}"
    }
  }
}