resource "terraform_data" "init_vector_schema" {
  # 1. Wait for the database and security policies to exist
  # Wait for the module to finish provisioning
  depends_on = [module.rag_backend]

  # 2. Only re-run this script if the database is destroyed and recreated
  triggers_replace = [
    module.rag_backend.collection_id
  ]

  # 3. Execute the Python script using your local virtual environment
  provisioner "local-exec" {
    # Using the Windows path for your .venv
    command = ".\\.venv\\Scripts\\python.exe create_index.py"

    # Inject the variables directly into the script's environment
    environment = {
      OPENSEARCH_ENDPOINT = module.rag_backend.opensearch_endpoint
      TF_VAR_aws_region   = var.aws_region
    }
  }
}