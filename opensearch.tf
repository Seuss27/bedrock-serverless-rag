# 1. Encryption Policy (Required prerequisite)
resource "aws_opensearchserverless_security_policy" "encryption_policy" {
  name        = "bedrock-encryption-policy"
  type        = "encryption"
  description = "Encryption policy for Bedrock RAG vector store"
  
  policy = jsonencode({
    Rules = [
      {
        # Must match the collection name exactly
        Resource     = ["collection/bedrock-rag-store"]
        ResourceType = "collection"
      }
    ]
    AWSOwnedKey = true
  })
}

# 2. Network Policy (Required prerequisite)
resource "aws_opensearchserverless_security_policy" "network_policy" {
  name        = "bedrock-network-policy"
  type        = "network"
  description = "Network policy for Bedrock RAG vector store"
  
  policy = jsonencode([
    {
      Description = "Allow Bedrock and local testing access",
      Rules = [
        {
          ResourceType = "collection"
          Resource     = ["collection/bedrock-rag-store"]
        },
        {
          ResourceType = "dashboard"
          Resource     = ["collection/bedrock-rag-store"]
        }
      ]
      AllowFromPublic = true 
    }
  ])
}

# 3. The Serverless Collection
resource "aws_opensearchserverless_collection" "vector_store" {
  name = "bedrock-rag-store"
  
  # For Bedrock RAG, this must be set to VECTORSEARCH, not SEARCH
  type = "VECTORSEARCH"
  
  # This block prevents the deployment from failing
  depends_on = [
    aws_opensearchserverless_security_policy.encryption_policy,
    aws_opensearchserverless_security_policy.network_policy
  ]
}