# The encryption and network policies are prerequisites of the collection below, so they
# can't reference aws_opensearchserverless_collection.vector_store.name the way iam.tf's
# data-access policy does -- the collection's own `depends_on` (below) already points at
# both policies, so a reference the other way would be a static dependency cycle, not a
# missing-value problem. Both this literal and the collection's own `name` must still match
# exactly -- deriving both from one local closes the hazard CLAUDE.md documents: two
# independent resources hardcoding the same string can silently diverge.
#
# vector_index_name has the same shape one level down: bedrock.tf's KB storage config and
# automation.tf's index-creation script each declared "personal-rag-index" independently.
# Centralized here for the same reason, threaded to the script via an env var since it runs
# out-of-process.
locals {
  collection_name   = "bedrock-rag-store"
  vector_index_name = "personal-rag-index"
}

# 1. Encryption Policy (Required prerequisite)
resource "aws_opensearchserverless_security_policy" "encryption_policy" {
  name        = "bedrock-encryption-policy"
  type        = "encryption"
  description = "Encryption policy for Bedrock RAG vector store"

  policy = jsonencode({
    Rules = [
      {
        # Must match the collection name exactly
        Resource     = ["collection/${local.collection_name}"]
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
          Resource     = ["collection/${local.collection_name}"]
        },
        {
          ResourceType = "dashboard"
          Resource     = ["collection/${local.collection_name}"]
        }
      ]
      AllowFromPublic = true
    }
  ])
}

# 3. The Serverless Collection
resource "aws_opensearchserverless_collection" "vector_store" {
  name = local.collection_name

  # For Bedrock RAG, this must be set to VECTORSEARCH, not SEARCH
  type = "VECTORSEARCH"

  # This block prevents the deployment from failing
  depends_on = [
    aws_opensearchserverless_security_policy.encryption_policy,
    aws_opensearchserverless_security_policy.network_policy
  ]
}