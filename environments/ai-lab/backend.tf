terraform {
  backend "s3" {
    bucket       = "personal-bedrock-lab-state" # Match the bucket name from bootstrap/state-backend.tf
    key          = "environments/ai-lab/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true # Native S3 locking (OpenTofu >= 1.10) -- see BR-D22. No DynamoDB table.
    encrypt      = true
  }
}