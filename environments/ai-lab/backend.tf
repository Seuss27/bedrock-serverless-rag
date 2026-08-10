terraform {
  backend "s3" {
    bucket       = "personal-bedrock-lab-state" # Match the bucket name from bootstrap/state-backend.tf
    key          = "environments/ai-lab/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true # Native S3 locking (OpenTofu >= 1.10) -- see BR-D22. No DynamoDB table.
    # ⚠️ SSE-S3 only -- this is NOT what protects state from a legitimate s3:GetObject reader.
    # The real control is client-side: see encryption.tf (BR-D22, S2-T2). Do not read
    # `encrypt = true` as "state is encrypted" in the sense this repo cares about.
    encrypt = true
  }
}