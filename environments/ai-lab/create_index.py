import boto3
from opensearchpy import OpenSearch, RequestsHttpConnection
from requests_aws4auth import AWS4Auth
import os
import sys
import time
from dotenv import load_dotenv

# Load environment variables from the local .env file
load_dotenv()

# 1. Configuration 
region = os.getenv("TF_VAR_aws_region", "us-east-1") 
host = os.getenv("OPENSEARCH_ENDPOINT") 
if host:
    host = host.replace("https://", "") # opensearchpy expects the raw host without the scheme
index_name = "personal-rag-index"

# 2. Authenticate using your active AWS CLI credentials
session = boto3.Session()
credentials = session.get_credentials()
awsauth = AWS4Auth(
    credentials.access_key,
    credentials.secret_key,
    region,
    'aoss', 
    session_token=credentials.token
)

# 3. Initialize the OpenSearch Serverless Client
client = OpenSearch(
    hosts=[{'host': host, 'port': 443}],
    http_auth=awsauth,
    use_ssl=True,
    verify_certs=True,
    connection_class=RequestsHttpConnection,
    timeout=300
)

# 4. Define the Vector Index Schema
index_body = {
    "settings": {
        "index": {
            "knn": True,
            "knn.algo_param.ef_search": 512
        }
    },
    "mappings": {
        "properties": {
            "bedrock-embedding": {
                "type": "knn_vector",
                "dimension": 1024,
                "method": {
                    "name": "hnsw",
                    "engine": "faiss",
                    "space_type": "l2"
                }
            },
            "AMAZON_BEDROCK_TEXT_CHUNK": {
                "type": "text",
                "index": True
            },
            "AMAZON_BEDROCK_METADATA": {
                "type": "text",
                "index": False
            }
        }
    }
}

# 5. Polling loop to handle IAM propagation delay
max_retries = 6
retry_delay = 45  # Wait n seconds between attempts

for attempt in range(max_retries):
    try:
        print(f"Attempt {attempt + 1}: Checking OpenSearch index...")
        if client.indices.exists(index=index_name):
            client.indices.delete(index=index_name)
            print(f"Deleted existing index: '{index_name}'")
            
        response = client.indices.create(index=index_name, body=index_body)
        print(f"Success! Index '{index_name}' created with FAISS engine.")
        sys.exit(0)  # Tell OpenTofu the script was 100% successful
        
    except Exception as e:
        print(f"Attempt {attempt + 1} failed: {e}")
        if attempt < max_retries - 1:
            print(f"Waiting {retry_delay} seconds for AWS IAM data access policies to propagate...")
            time.sleep(retry_delay)
        else:
            print("Max retries reached. The index could not be created.")
            sys.exit(1)  # Force OpenTofu to halt with an error