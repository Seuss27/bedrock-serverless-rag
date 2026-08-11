terraform {
  backend "s3" {
    # S2 Task 3 (F43 pt. 1): migrated from this project's own bucket to the org-owned state
    # bucket (glunk-works/global-bootstrap's aws_s3_bucket.state_bucket). The key's prefix
    # MUST equal this project's key in global-bootstrap's var.projects map byte-for-byte, or
    # the upstream role's s3:prefix condition denies access -- surfacing as a credentials
    # error, not a naming one.
    bucket       = "glunk-works-tofu-state-00042"
    key          = "bedrock-serverless-rag/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true # Native S3 locking (OpenTofu >= 1.10) -- see BR-D22. No DynamoDB table.
    # ⚠️ SSE-S3 only -- this is NOT what protects state from a legitimate s3:GetObject reader.
    # The real control is client-side: see encryption.tf (BR-D22, S2-T2). Do not read
    # `encrypt = true` as "state is encrypted" in the sense this repo cares about.
    encrypt = true
  }
}