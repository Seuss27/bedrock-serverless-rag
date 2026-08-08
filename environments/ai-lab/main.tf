# No-op touch, MW-T6: deliberately triggers deploy-ai-lab.yml's path filter so the
# CI-role apply half of the destroy -> apply -> RetrieveAndGenerate cycle runs. AWS is
# fully empty as of the human-watched destroy (runs 31259407481, 31260054651,
# 31260209345 -- the last one destroyed the KB execution role, the final resource);
# a local admin-SSO plan confirmed `Plan: 12 to add, 0 to change, 0 to destroy` with no
# drift or orphans first. No code change was otherwise required -- see PR #53 for the
# same pattern used for the same reason.
module "rag_backend" {
  source = "../../modules/aws-bedrock-rag"

  aws_region                = var.aws_region
  data_source_bucket_name   = var.data_source_bucket_name
  data_plane_principal_arns = var.data_plane_principal_arns
}