resource "terraform_data" "init_vector_schema" {
  # 1. Wait for the database and security policies to exist
  depends_on = [
    aws_opensearchserverless_collection.vector_store,
    aws_opensearchserverless_access_policy.data_access_policy
  ]

  # 2. Only re-run this script if the database is destroyed and recreated
  triggers_replace = [
    aws_opensearchserverless_collection.vector_store.id
  ]

  # 3. Execute the Python script using your local virtual environment
  provisioner "local-exec" {
    # Using the Windows path for your .venv
    command = ".\\.venv\\Scripts\\python.exe create_index.py"

    # Inject the variables directly into the script's environment
    environment = {
      OPENSEARCH_ENDPOINT = aws_opensearchserverless_collection.vector_store.collection_endpoint
      TF_VAR_aws_region   = var.aws_region
    }
  }
}