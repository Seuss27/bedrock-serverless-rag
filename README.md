# AWS Bedrock Serverless RAG Pipeline

This repository contains the Infrastructure as Code (IaC) and automation scripts to deploy a fully serverless Retrieval-Augmented Generation (RAG) pipeline on AWS. It provisions a native Amazon Bedrock Knowledge Base backed by an Amazon OpenSearch Serverless vector database, with source documents ingested via S3.

This project is built with a focus on modern security practices: it relies entirely on short-lived AWS IAM Identity Center (SSO) credentials and dynamically injects secrets via Infisical to maintain a zero-trust local development environment.

## 🏗️ Architecture & Tech Stack

* **Infrastructure as Code:** OpenTofu (>= 1.8.0)
* **AI/ML Engine:** Amazon Bedrock (Titan Text Embeddings v1)
* **Vector Database:** Amazon OpenSearch Serverless
* **Storage:** Amazon S3 (AES-256 Encrypted)
* **Secrets Management:** Infisical & .env (No hardcoded credentials on disk)
* **Scripting:** Python 3 (Boto3, OpenSearch-py, AWS SigV4 Auth)

## 📂 Repository Structure

    .
    ├── .env                    # (Gitignored) Local secrets and variable injection
    ├── .gitignore              # Blocks state files, environment vars, and caches
    ├── bedrock.tf              # Bedrock Knowledge Base & Data Source config
    ├── create_index.py         # Python script to build the vector schema
    ├── iam.tf                  # S3 ingestion bucket & strict execution roles
    ├── opensearch.tf           # Vector collection, encryption, & network policies
    ├── outputs.tf              # Exposes dynamically generated endpoints
    ├── providers.tf            # AWS & Infisical provider initialization
    ├── requirements.txt        # Python package dependencies
    └── variables.tf            # Input definitions for modular deployment

## 📋 Prerequisites

Before deploying, ensure your local development environment has the following installed:
1. OpenTofu (via winget or Homebrew)
2. AWS CLI v2
3. Python 3.x
4. An active AWS IAM Identity Center setup (SSO).
5. An Infisical account/workspace.

---

## 🚀 Deployment Guide

### Step 1: Local Environment Preparation
Do not store your AWS access keys or Infisical secrets in plain text. Create a `.env` file in the root directory and populate it with your specific values:

    INFISICAL_CLIENT_ID="your-machine-identity-client-id"
    INFISICAL_CLIENT_SECRET="your-single-use-secret"
    TF_VAR_infisical_workspace_id="your-workspace-id"
    TF_VAR_data_source_bucket_name="personal-bedrock-serverless-rag-source"

*Note: The `.env` file is explicitly ignored by Git.*

### Step 2: Authenticate with AWS
Authenticate your terminal using your short-lived SSO credentials.

    aws sso login --profile admin-sso

### Step 3: Load Variables & Deploy Infrastructure
Load your `.env` variables into your active PowerShell session, initialize OpenTofu, and apply the configuration.

    # 1. Load variables into terminal memory
    Get-Content .env | Foreach-Object {
        $var = $_.Split('=')
        Set-Item "Env:$($var[0])" $var[1].Replace('"', '')
    }

    # 2. Initialize and deploy
    tofu init
    tofu apply

### Step 4: Initialize the Vector Data Plane
Once OpenTofu finishes building the control plane, it will output the new OpenSearch Serverless endpoint URL. 

1. Append the generated URL to your `.env` file:
    OPENSEARCH_ENDPOINT="https://[YOUR_COLLECTION_ID].us-east-1.aoss.amazonaws.com"

2. Set up your Python virtual environment and install the required dependencies using the requirements file:
    python -m venv .venv
    .\.venv\Scripts\activate
    pip install -r requirements.txt

3. Run the schema creation script to prepare the vector database for Bedrock:
    python create_index.py

### Step 5: Ingest Documents
1. Upload your source PDF/TXT documents into the newly created S3 bucket (`personal-bedrock-serverless-rag-source`).
2. Trigger a sync in the Amazon Bedrock Knowledge Base console (or via the AWS CLI) to chunk the text, generate vector embeddings, and store them in OpenSearch.

## 🧹 Teardown

Because OpenSearch Serverless incurs active hourly costs, do not leave this environment running idly. To destroy all resources, ensure your `.env` variables are loaded in your terminal and run:

    tofu destroy