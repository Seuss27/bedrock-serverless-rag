module "rag_backend" {
  source = "../../modules/aws-bedrock-rag"

  aws_region                = var.aws_region
  data_source_bucket_name   = var.data_source_bucket_name
  data_plane_principal_arns = var.data_plane_principal_arns
  permissions_boundary_name = var.permissions_boundary_name
}