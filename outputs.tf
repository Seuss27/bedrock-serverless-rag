output "opensearch_endpoint" {
  description = "The endpoint URL for the OpenSearch Serverless collection"
  value       = aws_opensearchserverless_collection.vector_store.collection_endpoint
}