output "opensearch_endpoint" {
  description = "The endpoint URL for the OpenSearch Serverless collection"
  value       = aws_opensearchserverless_collection.vector_store.collection_endpoint
}

output "knowledge_base_id" {
  description = "The ID of the Bedrock Knowledge Base"
  value       = aws_bedrockagent_knowledge_base.rag_kb.id
}

output "collection_id" {
  description = "The ID of the OpenSearch collection (used for automation triggers)"
  value       = aws_opensearchserverless_collection.vector_store.id
}