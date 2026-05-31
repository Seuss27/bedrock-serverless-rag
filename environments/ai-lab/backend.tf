terraform {
  backend "s3" {
    bucket         = "personal-bedrock-lab-state" # Match the bucket name from bootstrap/state-backend.tf
    key            = "environments/ai-lab/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "bedrock-lab-state-locks"
    encrypt        = true
  }
}