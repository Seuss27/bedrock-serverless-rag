# 1. Define the required binaries from the OpenTofu Registry
terraform {
  required_version = ">= 1.8.0" # Ensures compatibility with OpenTofu-specific features

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    infisical = {
      source  = "infisical/infisical"
      version = "~> 0.16.0"
    }
    # cloudflare = {
    #   source  = "cloudflare/cloudflare"
    #   version = "~> 4.0"
    # }
  }
}

# 2. Configure the Infisical Provider
# Leaving this configuration block empty tells the provider to automatically look 
# for the standard system variables: INFISICAL_CLIENT_ID and INFISICAL_CLIENT_SECRET
provider "infisical" {
  host = "https://app.infisical.com"
}

# 3. Pull Cloudflare credentials dynamically from your free-tier Viewer workspace
# data "infisical_secrets" "cloudflare_secrets" {
#   workspace_id = var.infisical_workspace_id
#   environment  = "prod"
#   folder_path  = "/cloudflare"
# }

# 4. Configure the Cloudflare Provider using Infisical values in memory
# provider "cloudflare" {
#   api_token = data.infisical_secrets.cloudflare_secrets.secrets["CF_API_TOKEN"].value
# }

# 5. Configure the AWS Provider
provider "aws" {
  region  = var.aws_region
}