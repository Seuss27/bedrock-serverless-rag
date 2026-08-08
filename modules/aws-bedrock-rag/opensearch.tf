# The encryption and network policies are prerequisites of the collection below, so they
# can't reference aws_opensearchserverless_collection.vector_store.name the way iam.tf's
# data-access policy does -- the collection's own `depends_on` (below) already points at
# both policies, so a reference the other way would be a static dependency cycle, not a
# missing-value problem. Both this literal and the collection's own `name` must still match
# exactly -- deriving both from one local closes the hazard CLAUDE.md documents: two
# independent resources hardcoding the same string can silently diverge.
#
# vector_index_name has the same shape one level down: bedrock.tf's KB storage config and
# automation.tf's index-creation script each declared "personal-rag-index" independently.
# Centralized here for the same reason, threaded to the script via an env var since it runs
# out-of-process.
locals {
  collection_name   = "bedrock-rag-store"
  vector_index_name = "personal-rag-index"
}

# 1. Encryption Policy (Required prerequisite)
resource "aws_opensearchserverless_security_policy" "encryption_policy" {
  name        = "bedrock-encryption-policy"
  type        = "encryption"
  description = "Encryption policy for Bedrock RAG vector store"

  policy = jsonencode({
    Rules = [
      {
        # Must match the collection name exactly
        Resource     = ["collection/${local.collection_name}"]
        ResourceType = "collection"
      }
    ]
    AWSOwnedKey = true
  })
}

# 2. Network Policy (Required prerequisite)
resource "aws_opensearchserverless_security_policy" "network_policy" {
  name        = "bedrock-network-policy"
  type        = "network"
  description = "Network policy for Bedrock RAG vector store"

  policy = jsonencode([
    {
      Description = "Allow Bedrock and local testing access",
      Rules = [
        {
          ResourceType = "collection"
          Resource     = ["collection/${local.collection_name}"]
        },
        {
          ResourceType = "dashboard"
          Resource     = ["collection/${local.collection_name}"]
        }
      ]
      AllowFromPublic = true
    }
  ])
}

# 3. The Serverless Collection
resource "aws_opensearchserverless_collection" "vector_store" {
  name = local.collection_name

  # For Bedrock RAG, this must be set to VECTORSEARCH, not SEARCH
  type = "VECTORSEARCH"

  # BR-D26. AOSS bills a MINIMUM OCU floor for as long as the collection exists, independent
  # of usage -- an empty index costs what a busy one does. Leaving this unset is therefore not
  # neutral: the provider default is "ENABLED" (locked hashicorp/aws 5.100.0 schema, verbatim:
  # 'One of `ENABLED` or `DISABLED`. Defaults to `ENABLED`'), which buys cross-AZ redundancy
  # at 4 OCU where this lab needs 2.
  #
  # ⚠️ INFERRED, NOT MEASURED. That the live collection was actually running at the default was
  # never read back from AWS -- no batch-get-collection was recorded -- and the collection was
  # destroyed 2026-08-08 19:37 UTC, so the claim is now unfalsifiable. It rests on the schema
  # default above, which is good evidence and is not the same thing as a measurement. Said
  # plainly because this repo's recurring failure is a confident dated assertion that traces
  # back to prose rather than to a reading.
  #
  # What this buys: BR-D20 makes the workload ephemeral and the corpus empty, so paying a
  # redundancy premium to protect an empty index against an AZ failure is the same trade
  # BR-D16 already declined for the VPC endpoint -- ceremony around a store holding nothing.
  # The trade is AVAILABILITY, not durability: AOSS is S3-backed either way, so DISABLED risks
  # a slower recovery, never a lost index. And it HALVES an overrun rather than resolving one
  # -- ~2 OCU is still far above `budget_limit_usd`'s "20"; do not read this as "cost handled".
  #
  # ⚠️ CREATE-TIME. AOSS does not permit changing redundancy in place, so a later flip back to
  # ENABLED REPLACES the collection rather than updating it -- which fires automation.tf's
  # `triggers_replace` on the new collection id, and create_index.py deletes the index if it
  # exists. That is BR-D10's destructive chain reached from a plain `tofu apply`, and S4-T4's
  # guard is not in place yet. Free today (state is empty; the next plan is 12 creates, no
  # replacement) -- which is exactly why it is written down now rather than after it costs
  # something. So: do not "restore" this to ENABLED as a silent edit. If this workload ever
  # holds data worth an AZ, that premise change amends BR-D26 in the decision log first.
  # (ForceNew is an inference from the AOSS UpdateCollection API surface, which accepts only
  # `description`; the provider schema JSON does not expose ForceNew and no plan confirmed it.)
  standby_replicas = "DISABLED"

  # This block prevents the deployment from failing
  depends_on = [
    aws_opensearchserverless_security_policy.encryption_policy,
    aws_opensearchserverless_security_policy.network_policy
  ]
}