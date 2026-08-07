# 1. Define the required binaries from the OpenTofu Registry
terraform {
  required_version = ">= 1.10.0" # 1.10+ for the S3 backend's native use_lockfile (BR-D22)

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# 2. Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}