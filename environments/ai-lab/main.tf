# No-op touch, S1b-T7: deliberately triggers deploy.yml's tofu-plan-main -> tofu-apply so
# S1b's Definition of Done can be satisfied -- a destroy -> apply -> verify cycle,
# human-watched, run against the FINAL split ci.yml/deploy.yml shape (all five required
# checks live, F59/F60's fixes, job-scoped deploy.yml permissions). Nothing since T2 deleted
# deploy-ai-lab.yml has exercised this; the last real cycle (MW-T6) proved a file that no
# longer exists. AWS is empty as of the 2026-08-08 teardown (BR-D26); this apply is the
# create half, dispatch destroy-ai-lab afterward for the destroy half. No code change was
# otherwise required -- see PR #53/#64 for the same pattern used for the same reason.
module "rag_backend" {
  source = "../../modules/aws-bedrock-rag"

  aws_region                = var.aws_region
  data_source_bucket_name   = var.data_source_bucket_name
  data_plane_principal_arns = var.data_plane_principal_arns
}