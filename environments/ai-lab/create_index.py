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
index_name = os.getenv("VECTOR_INDEX_NAME", "personal-rag-index")

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


def _create_index_once():
    """One attempt: delete the index if it already exists, then create it. Raises on
    failure -- callers decide whether/how to retry."""
    if client.indices.exists(index=index_name):
        client.indices.delete(index=index_name)
        print(f"Deleted existing index: '{index_name}'")
    client.indices.create(index=index_name, body=index_body)
    print(f"Success! Index '{index_name}' created with FAISS engine.")


# AuthorizationException gets its OWN sliding-window retry, self-contained and independent
# of the outer max_retries/retry_delay loop above (that loop is for TransportError-class
# eventual consistency; a 403 is a different signal). Observed three times now (twice during
# S1b-T7's DoD rebuild, once during the DoD verify cycle that followed it): a data-access-
# policy this same apply had *just* created was rejected shortly after its own creation
# completed, then succeeded on a plain retry once AOSS's data plane caught up -- propagation
# lag, not a wrong principal (aoss:APIAccessAll and the policy's Principal list were
# confirmed correct against live AWS every time). A genuinely wrong principal still can
# never resolve by waiting (F46's original finding, unchanged).
#
# AWS's own docs (serverless-data-access.html) state "about a minute" is the typical lag
# after creating a data access policy, and to contact Support if it exceeds 5 minutes. So
# this retries with an increasing delay (starting at AUTH_RETRY_INITIAL_DELAY, doubling up
# to a AUTH_RETRY_MAX_DELAY-second cap per step) against a total elapsed budget of
# AUTH_RETRY_BUDGET_SECONDS = 5:15 -- comfortably past AWS's own documented worst case, with
# a small margin, without drifting into "something else is wrong" territory. That 5:15 is a
# SLEEP budget, not a hard wall-clock ceiling: the last retry can still start just inside the
# budget and then run for up to the client's own `timeout=300`, and if this window is
# entered only after the general loop above already burned through TransportErrors, the
# composite worst case is that 6x45s (270s) PLUS this 315s -- ~9 minutes, not 5:15. Still
# bounded, still far short of F46's original unbounded/mischaracterized ~12-minute hang, but
# the honest number is ~9 minutes in that combined case, not the 5:15 this window uses alone.
#
# This REPLACES `MW`-T3's flat "an authorization failure exits in under a minute" criterion
# for THIS specific exception. The first two occurrences were fixed with a flat 2x15s retry;
# the third showed that budget wasn't enough, and a 3x15s widen was drafted but never
# shipped -- both were the wrong number to be chasing, since AWS's own docs already state a
# bigger one. F46's original worry was a *permanently*-wrong permission being retried
# blindly for ~12 minutes with a message that mischaracterized it as transient; this budget
# avoids that by (a) being bounded, at a ceiling tied to AWS's own documented behavior
# rather than an arbitrary one, and (b) saying so plainly on every attempt, so a long run
# reads as "waiting out a documented window," not a silent hang -- (b) requires unbuffered
# stdout, which is why `automation.tf`'s `local-exec` now sets `PYTHONUNBUFFERED=1`; Python
# block-buffers stdout by default when piped, which would otherwise deliver every print in
# this function in one burst at exit, making a multi-minute wait look exactly like a hang.
# See F46's roadmap row for the decision record. The general 6x45s loop below is unchanged
# and still fails fast on anything that isn't a TransportError-family exception.
AUTH_RETRY_BUDGET_SECONDS = 315  # 5:15
AUTH_RETRY_INITIAL_DELAY = 5  # seconds
AUTH_RETRY_MAX_DELAY = 60  # seconds -- cap the per-step wait so the window keeps checking
# in periodically even late in the budget, rather than sleeping through most of it in one go


def _retry_after_authorization_exception():
    """Called on the FIRST AuthorizationException. Owns its own increasing-delay retry
    loop against a 5:15 wall-clock budget, independent of the outer loop's attempt count.
    Always terminates the process: exit(0) on eventual success, exit(1) once the budget is
    exhausted or a non-TransportError exception occurs."""
    start = time.monotonic()  # not time.time(): a wall-clock step (NTP) must not shrink or
    # stretch a duration budget
    delay = AUTH_RETRY_INITIAL_DELAY
    attempts = 1  # the caller's own attempt, which raised the exception that got us here
    while True:
        elapsed = time.monotonic() - start
        remaining = AUTH_RETRY_BUDGET_SECONDS - elapsed
        if remaining <= 0:
            print(
                f"Not authorized to manage the OpenSearch Serverless index after "
                f"{attempts} attempts over {int(elapsed)}s (budget: "
                f"{AUTH_RETRY_BUDGET_SECONDS}s / 5:15). That is past AWS's own documented "
                "worst case for access-policy propagation, so this is treated as a genuine "
                "permissions problem, not propagation lag -- check the collection's "
                "data-access-policy principal and the caller's aoss:APIAccessAll grant."
            )
            sys.exit(1)

        wait = min(delay, remaining)
        print(
            f"Attempt {attempts} not authorized yet ({int(elapsed)}s elapsed of "
            f"{AUTH_RETRY_BUDGET_SECONDS}s budget). AWS's own docs say AOSS access-policy "
            "propagation is typically ~1 minute, up to 5 -- waiting "
            f"{int(wait)}s before attempt {attempts + 1}."
        )
        time.sleep(wait)
        attempts += 1
        try:
            _create_index_once()
            sys.exit(0)  # Tell OpenTofu the script was 100% successful
        except TransportError:
            # Covers AuthorizationException too (it subclasses TransportError in
            # opensearchpy) as well as a plain connection blip or a 429/503 mid-warm-up.
            # Once we're already in this window, every TransportError-family exception is
            # an eventual-consistency signal, not just the 403 that got us here -- treating
            # only AuthorizationException as retryable would silently drop the general
            # loop's TransportError coverage for the rest of the run, since this function
            # never returns to it.
            delay = min(delay * 2, AUTH_RETRY_MAX_DELAY)
            continue
        except Exception as e:  # noqa: BLE001 -- BR-D4: never print str(e); see the
            # matching comment on the outer loop's own catch-all below.
            print(f"Attempt {attempts} failed: {type(e).__name__} (not retrying)")
            sys.exit(1)


for attempt in range(max_retries):
    try:
        print(f"Attempt {attempt + 1}: Checking OpenSearch index...")
        _create_index_once()
        sys.exit(0)  # Tell OpenTofu the script was 100% successful

    except AuthorizationException:
        print(
            f"Attempt {attempt + 1} failed: not authorized to manage the OpenSearch "
            "Serverless index yet. Handing off to the sliding-window retry (up to 5:15) "
            "in case this is AOSS access-policy propagation lag on a policy created "
            "moments ago."
        )
        _retry_after_authorization_exception()  # never returns -- always exit()s

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