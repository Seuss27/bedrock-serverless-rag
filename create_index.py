import boto3
from opensearchpy import OpenSearch, RequestsHttpConnection
from requests_aws4auth import AWS4Auth
import os
from dotenv import load_dotenv

# Load environment variables from the local .env file
load_dotenv()

# 1. Configuration (Replace with your actual collection endpoint)
region = os.getenv("TF_VAR_aws_region", "us-east-1") # Falls back to us-east-1 if not found
host = os.getenv("OPENSEARCH_ENDPOINT") # Add to .env after first tofu apply
index_name = "personal-rag-index"

# 2. Authenticate using your active AWS CLI credentials
credentials = boto3.Session().get_credentials()
awsauth = AWS4Auth(
    credentials.access_key,
    credentials.secret_key,
    region,
    'aoss', # Service name for OpenSearch Serverless
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
# The dimensions MUST match the output of your chosen Bedrock embedding model.
# Amazon Titan Text Embeddings v2 defaults to 1024 dimensions.
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
                    "engine": "nmslib",
                    "space_type": "cosinesimil"
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

# 5. Create the Index
try:
    response = client.indices.create(index=index_name, body=index_body)
    print(f"Success! Index '{index_name}' created.")
    print(response)
except Exception as e:
    print(f"Error creating index: {e}")