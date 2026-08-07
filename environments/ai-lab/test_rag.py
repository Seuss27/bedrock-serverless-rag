import os
import sys

import boto3
from botocore.exceptions import ClientError
from dotenv import load_dotenv

# 1. Load environment variables
load_dotenv()
region = os.getenv("TF_VAR_aws_region", "us-east-1")
kb_id = os.getenv("KNOWLEDGE_BASE_ID")

if not kb_id:
    print("Error: KNOWLEDGE_BASE_ID not found in .env")
    sys.exit(1)

# 2. Authenticate using your active AWS CLI credentials
session = boto3.Session()
# Note: We use bedrock-agent-runtime for querying, not bedrock-agent
bedrock_client = session.client('bedrock-agent-runtime', region_name=region)

# 3. Define the LLM to generate the answer
# Claude 3 Haiku is highly recommended for standard text RAG tests
model_arn = f"arn:aws:bedrock:{region}::foundation-model/anthropic.claude-3-haiku-20240307-v1:0"

def query_knowledge_base():
    print(f"\nConnected to Knowledge Base: {kb_id}")
    query = input("Ask your document a question: ")
    print("\nSearching OpenSearch and generating response...\n")

    try:
        # 4. Call the RetrieveAndGenerate API
        response = bedrock_client.retrieve_and_generate(
            input={
                'text': query
            },
            retrieveAndGenerateConfiguration={
                'type': 'KNOWLEDGE_BASE',
                'knowledgeBaseConfiguration': {
                    'knowledgeBaseId': kb_id,
                    'modelArn': model_arn
                }
            }
        )

        # 5. Parse and print the output
        answer = response['output']['text']
        print("🤖 Response:")
        print("-" * 50)
        print(answer)
        print("-" * 50)

        # 6. Extract and print the source citations
        citations = response.get('citations', [])
        if citations:
            print("\n📚 Sources Cited:")
            for i, citation in enumerate(citations, 1):
                docs = citation.get('retrievedReferences', [])
                for doc in docs:
                    source_uri = doc.get('location', {}).get('s3Location', {}).get('uri', 'Unknown Source')
                    print(f"  [{i}] {source_uri}")

    except ClientError as e:
        print(f"\nError querying Knowledge Base: {e}")
        print("\nTroubleshooting:")
        print("- Did you upload a document to your S3 bucket and click 'Sync' in the Bedrock Console?")
        print("- Have you requested Model Access for Claude 3 Haiku in the Bedrock Console?")

if __name__ == "__main__":
    query_knowledge_base()