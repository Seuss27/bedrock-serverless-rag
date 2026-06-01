resource "terraform_data" "init_vector_schema" {
  # Depend directly on the OpenSearch collection being built first
  depends_on = [
    aws_opensearchserverless_collection.vector_store
  ]

  triggers_replace = {
    # Reference the resource ID directly
    collection_id = aws_opensearchserverless_collection.vector_store.id
  }

  provisioner "local-exec" {
    # Your cross-platform Python command from earlier!
    command = "python create_index.py"

    environment = {
      # Reference the resource endpoint directly
      OPENSEARCH_ENDPOINT = aws_opensearchserverless_collection.vector_store.collection_endpoint
      TF_VAR_aws_region   = var.aws_region
    }
  }
}