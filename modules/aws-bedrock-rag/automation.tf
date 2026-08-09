resource "terraform_data" "init_vector_schema" {
  # Depend on the collection AND the data-access policy that grants aoss:CreateIndex on it.
  # Without the second edge these are sibling resources with no ordering between them, so
  # OpenTofu can run this script concurrently with CreateAccessPolicy on a from-scratch
  # apply -- the script's first attempt then 403s before the policy exists. This depends_on
  # is still load-bearing even though create_index.py now retries an AuthorizationException
  # briefly (2 short retries, 15s apart -- see the script's own comment): that budget exists
  # to absorb AOSS's own propagation lag on a policy that already exists, not to substitute
  # for the policy existing in the first place. Removing this edge would race the two
  # resources and only sometimes land inside the retry budget.
  depends_on = [
    aws_opensearchserverless_collection.vector_store,
    aws_opensearchserverless_access_policy.data_access_policy
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
      VECTOR_INDEX_NAME   = local.vector_index_name
    }
  }
}