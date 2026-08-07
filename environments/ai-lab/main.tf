# No-op touch, PR #53: deliberately triggers deploy-ai-lab.yml's path filter so the
# plan-summary fix in this PR can be watched running once before merge.
module "rag_backend" {
  source = "../../modules/aws-bedrock-rag"

  aws_region                = var.aws_region
  data_source_bucket_name   = var.data_source_bucket_name
  data_plane_principal_arns = var.data_plane_principal_arns
}