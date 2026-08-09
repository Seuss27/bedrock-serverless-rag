# No-op touch, retry: the first S1b-T7 DoD attempt (PR #89, run 31330995230) got through
# every resource except the vector index -- S3 bucket, KB execution role, budget, AOSS
# collection (3m13s) and its security/data-access policies all created clean under the
# job-scoped credentials. terraform_data.init_vector_schema's local-exec then hit
# AuthorizationException on its FIRST attempt, 1.6s after the data-access-policy itself
# finished creating -- create_index.py treats that exception as non-retryable by design
# (F46: a genuinely wrong principal can never resolve by waiting), but this looks like AOSS
# access-policy propagation lag on a policy that is seconds old, not a wrong principal.
# Verified directly against live AWS (read-only, admin-sso) before retrying rather than
# guessing: aoss:APIAccessAll IS granted on the CI role's OpenTofuStateAccess policy, and
# the collection's data-access-policy Principal list already includes the CI role's plain
# IAM role ARN (not an assumed-role session, which was F5's original mechanism -- both
# checks came back clean). The failed local-exec provisioner taints its resource (no
# on_failure = "continue" set), so this apply recreates only that one resource against
# everything else, which is already live.
module "rag_backend" {
  source = "../../modules/aws-bedrock-rag"

  aws_region                = var.aws_region
  data_source_bucket_name   = var.data_source_bucket_name
  data_plane_principal_arns = var.data_plane_principal_arns
}