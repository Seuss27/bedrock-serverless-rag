# No-op touch: deliberately triggers deploy-ai-lab.yml's path filter to verify, in one
# real CI run, the secrets-based disclosure fix (#55), the bedrock:ListTagsForResource
# grant (#54), and the data_plane_principal_arns wiring (#53) all together.
module "rag_backend" {
  source = "../../modules/aws-bedrock-rag"

  aws_region                = var.aws_region
  data_source_bucket_name   = var.data_source_bucket_name
  data_plane_principal_arns = var.data_plane_principal_arns
}