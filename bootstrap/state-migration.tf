# state-migration.tf
#
# Grants this project's LOCAL role (aws_iam_role.github_actions_role, state-backend.tf) the
# two things S2 Task 2 rides on one bootstrap/ apply (sprints/S2_identity_least_privilege/
# sprint_plan.md, Task 2): KMS access to the upstream BR-D22 state-encryption key, and the
# read-only org-bucket bridge Task 3 needs. Both target the LOCAL role specifically because
# CI still authenticates as it today -- Task 0c already granted the identical KMS statement
# to both UPSTREAM roles (glunk-works/global-bootstrap's project_policies.tf and
# plan_roles.tf, Sid "StateEncryptionKeyAccess"), verified live. This file is the local-root
# mirror for the window before Task 4 cuts CI over to those roles.
#
# Everything here is as temporary as bootstrap/ itself: Task 4 retires the local role in
# favour of the upstream ones, and Task 5 deletes bootstrap/ outright. Neither resource below
# is a candidate to "converge on least privilege" in place -- same footnote as
# state-backend.tf's MW-T5 widen.
#
# ⚠️ RESIDUAL, recorded rather than fixed (security-critic pass, S2-T2, both HIGH). This
# root's local role -- unlike either upstream role Task 0c granted the identical KMS
# statement to -- also holds state-backend.tf's MW-T5 flat s3:PutBucket*/s3:ListBucket on
# Resource = "*" (that policy's own comment already flags this for narrowing "outside of
# lab use" and is explicitly NOT to be converged on in place; it is deleted wholesale, not
# edited, by Task 4). Before this file, that flat grant could reach the org state bucket's
# policy and objects but not decrypt them -- this root had zero kms: grants anywhere. This
# file supplies the missing kms:Decrypt on the SAME key that (once other glunk-works
# projects adopt native state encryption) protects every project's state, so the local
# role's pre-existing over-broad S3 reach and this file's new KMS reach compose into a
# theoretical path to another project's plaintext state via a rewritten bucket policy.
# Not mitigated here: a `kms:EncryptionContext` condition is the right-shaped fix but
# requires confirming what encryption context OpenTofu's native state encryption actually
# sets (unmeasured) before it can be added without risking a silent fail-closed; a
# `kms:ViaService` condition is the WRONG axis (native encryption calls KMS client-side,
# not via S3, and would fail closed). Also unrecorded until now: this grant sits on a role
# whose OIDC trust still admits `:pull_request` (F2, open) for the Task 2 -> Task 4 window,
# so a same-repo PR branch could in principle reach this capability before Task 4 retires
# the local role. Both points belong in Task 4's residual register, not fixed in place here.

# The upstream BR-D22 key (glunk-works/global-bootstrap's aws_kms_key.state_key, output
# state_kms_key_arn) and the org state bucket (aws_s3_bucket.state_bucket, output
# state_bucket_name) both live in a different root's state -- there is nothing in this root
# to derive either from, and both embed the account id, so neither gets a committed default
# (BR-D4; mirrors global-bootstrap's own bootstrap_bucket_name and
# bedrock_rag_source_bucket_name, which use the identical no-default cross-repo pattern).
# Set via TF_VAR_state_kms_key_arn / TF_VAR_org_state_bucket_name at apply time.
variable "state_kms_key_arn" {
  type        = string
  description = "ARN of the upstream BR-D22 OpenTofu-state KMS key (glunk-works/global-bootstrap output state_kms_key_arn). Restricted, not secret -- no default, set via TF_VAR_."

  # security-critic, S2-T2: unlike org_state_bucket_name below, this value is not a
  # fragment spliced into a literal ARN -- it IS the entire Resource string on the KMS
  # grant beneath it. An unvalidated "*" (or a fat-fingered .../key/*) renders
  # Resource = "*" and grants kms:Decrypt on every key in the account, including
  # bounty-infra's findings-archive key (F58's asset). Mirrors
  # github_oidc_subject_prefixes' validation in oidc-setup.tf: the fail-open input is the
  # one that needs the guard, not the fail-closed one.
  validation {
    condition     = !strcontains(var.state_kms_key_arn, "*") && !strcontains(var.state_kms_key_arn, "?")
    error_message = "state_kms_key_arn may not contain '*' or '?' -- both are ARN/glob wildcards and this value is used verbatim as an IAM policy Resource."
  }

  validation {
    condition     = startswith(var.state_kms_key_arn, "arn:aws:kms:")
    error_message = "state_kms_key_arn must be a KMS key ARN (arn:aws:kms:...) -- a bare key id or the wrong resource type would still apply, granting kms:Decrypt on whatever the malformed value happens to name."
  }
}

variable "org_state_bucket_name" {
  type        = string
  description = "Name of the org OpenTofu-state bucket (glunk-works/global-bootstrap output state_bucket_name). Restricted, not secret -- no default, set via TF_VAR_."

  # Same hazard global-bootstrap's own bedrock_rag_source_bucket_name validation guards:
  # this string is spliced directly into the bridge policy's Resource ARNs below. A value
  # containing '*' or '?' would widen s3:GetObject/ListBucket past this one bucket.
  validation {
    condition     = !strcontains(var.org_state_bucket_name, "*") && !strcontains(var.org_state_bucket_name, "?")
    error_message = "org_state_bucket_name may not contain '*' or '?' -- both are ARN/glob wildcards and this value is spliced directly into arn:aws:s3::: Resources."
  }
}

# 1. KMS access to the upstream state-encryption key (BR-D22, Task 0c step 1b's decision).
# Without this, the encryption {} block Task 2 adds to environments/ai-lab/encryption.tf
# breaks tofu-plan-main on the very next merge: every real tofu init evaluates the encryption
# block and reaches KMS. Same three verbs as both upstream roles' identical statement -- not
# an asymmetric read/write split.
#
# ⚠️ Two authoring-time claims that were true when this file was written and are NOT now, left
# here corrected rather than silently deleted (S2-T2, 2026-08-10): this root no longer has
# "zero kms: grants" -- the resource below IS that grant, and it is applied and live. And the
# mechanism for the immediate case is WRITE, not read: the ai-lab state object was deleted
# while empty, so the next apply has nothing to decrypt and needs GenerateDataKey to write
# ciphertext from scratch. Both verbs are granted; only the reasoning changed.
resource "aws_iam_role_policy" "state_kms_access_policy" {
  name = "StateEncryptionKeyAccess"
  role = aws_iam_role.github_actions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "StateEncryptionKeyAccess"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = var.state_kms_key_arn
      }
    ]
  })
}

# 2. The read-only org-bucket bridge (Task 3, F43 part 1) -- specified there, applied here so
# both grants ride the same bootstrap/ apply. A new, separately named resource rather than an
# edit inside state_access_policy: that makes the temporary thing visible on its own, and its
# removal in Task 4 a deletion rather than surgery on a hundred-line policy.
#
# NOT a privilege increase on the S3 ListBucket/GetObject axis specifically -- but say why
# precisely, per security-critic (S2-T2): state_access_policy's own statement 2
# (state-backend.tf) already grants unconditioned s3:ListBucket on Resource = "*" (the
# HeadBucket-403 refresh fix, MW-T6), so this role can already enumerate every bucket in the
# account, prefix condition or not. The prefix condition below is NOT what closes that -- it
# was never open on the List side. What it actually does is keep the READ (s3:GetObject)
# scoped to this project's own prefix rather than the whole org bucket, matching Task 3's
# spec verbatim. See the file-level comment for the KMS-side residual this combination opens
# that the S3 scoping alone does not close.
#
# READ-ONLY on purpose. No PutObject, no DeleteObject: the migration write itself (Task 3
# step 2, `tofu init -migrate-state`) is a human, local, admin-SSO operation. The first CI
# *write* to the org bucket happens under the upstream apply role in Task 4.
resource "aws_iam_role_policy" "state_migration_bridge" {
  name = "StateMigrationBridge"
  role = aws_iam_role.github_actions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Condition copied verbatim from upstream pipeline_state_policy's own
        # AllowListBucketOfSpecificPrefix statement. The prefix MUST equal the
        # var.projects map key exactly ("bedrock-serverless-rag") -- environments/ai-lab's
        # backend.tf key (Task 3 step 2) has to match it byte for byte, or this condition
        # denies ListBucket and the failure reads as a backend/credentials error, not a
        # naming one.
        Sid      = "AllowListOrgBucketOfOurPrefix"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = "arn:aws:s3:::${var.org_state_bucket_name}"
        Condition = {
          StringLike = { "s3:prefix" : ["bedrock-serverless-rag/*"] }
        }
      },
      {
        Sid      = "AllowReadOrgBucketOfOurPrefix"
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "arn:aws:s3:::${var.org_state_bucket_name}/bedrock-serverless-rag/*"
      }
    ]
  })
}
