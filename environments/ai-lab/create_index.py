import logging
import os
import sys
import time

import boto3
from dotenv import load_dotenv
from opensearchpy import OpenSearch, RequestsHttpConnection
from opensearchpy.exceptions import AuthorizationException, TransportError
from requests_aws4auth import AWS4Auth

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
# opensearchpy's own request-failure logging renders the full collection URL (BR-D4).
# It is silent today only because the library attaches a NullHandler; pin the level so
# an unrelated `logging.basicConfig()` call elsewhere in the process can't re-enable it.
logging.getLogger("opensearch").setLevel(logging.CRITICAL)

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

    except AuthorizationException:
        # A 403 here means the caller's IAM/data-access-policy grant is wrong -- it can
        # never resolve by waiting, so retrying it costs minutes and hides the real cause.
        print(
            f"Attempt {attempt + 1} failed: not authorized to manage the OpenSearch "
            "Serverless index. This is a permissions problem, not eventual consistency "
            "-- check the collection's data-access-policy principal and the caller's "
            "aoss:APIAccessAll grant. Exiting without retrying."
        )
        sys.exit(1)

    except TransportError as e:
        # Do not print str(e): opensearchpy errors can embed the collection endpoint
        # and caller identity, which would land in a public workflow log.
        print(f"Attempt {attempt + 1} failed: {type(e).__name__}")
        if attempt < max_retries - 1:
            print(f"Waiting {retry_delay} seconds for AWS IAM data access policies to propagate...")
            time.sleep(retry_delay)
        else:
            print("Max retries reached. The index could not be created.")
            sys.exit(1)  # Force OpenTofu to halt with an error

    except Exception as e:  # noqa: BLE001 -- BR-D4: an unhandled traceback would print
        # str(e) to a public log just as surely as the print() calls above. Covers
        # opensearchpy.exceptions.SerializationError (raises the raw response body,
        # which can name the collection) and any exception AWS4Auth raises while
        # signing the request, both of which sit outside TransportError. Not retried:
        # neither is IAM eventual consistency, so waiting cannot fix either one.
        print(f"Attempt {attempt + 1} failed: {type(e).__name__} (not retrying)")
        sys.exit(1)