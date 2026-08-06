# 1. Define the required binaries from the OpenTofu Registry
terraform {
  required_version = ">= 1.8.0" # Ensures compatibility with OpenTofu-specific features

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