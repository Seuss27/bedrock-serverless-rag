variable "aws_region" {
  type        = string
  description = "The target AWS region for deployment"
  default     = "us-east-1"
}

variable "data_source_bucket_name" {
  type        = string
  description = "The name of the S3 bucket where Bedrock RAG source documents are stored"
}

variable "data_plane_principal_arns" {
  type        = list(string)
  description = <<-EOT
    IAM role ARNs granted data-plane access to the AOSS collection, in addition to the KB
    execution role: this repo's own github-actions-deploy-role and the human operator's SSO
    role. Restricted, not secret (BR-D4) -- source via TF_VAR_data_plane_principal_arns
    locally and a repository variable in CI, never a committed .tfvars. No default on
    purpose: an unset OR empty value must fail plan rather than silently reproduce F5.
    TF_VAR_data_plane_principal_arns must be an HCL list literal, e.g.
    '["arn:aws:iam::<acct>:role/a","arn:aws:iam::<acct>:role/b"]' -- a comma-separated
    string is not accepted.
  EOT
  nullable    = false
  validation {
    condition     = length(var.data_plane_principal_arns) > 0
    error_message = "At least one data-plane principal ARN is required -- an empty list silently reproduces F5 (the CI role loses AOSS data-plane access)."
  }
}

variable "permissions_boundary_name" {
  type        = string
  description = "Name of the IAM permissions-boundary policy at path /bedrock-rag/, created upstream in glunk-works/global-bootstrap (S2-T0c)."
  default     = "bedrock-rag-workload-boundary"
}

variable "budget_limit_usd" {
  type        = string
  description = "Monthly cost guardrail for the ai-lab environment, in USD."
  default     = "20"
}

variable "state_kms_key_arn" {
  type        = string
  description = <<-EOT
    ARN of the upstream BR-D22 OpenTofu-state KMS key (glunk-works/global-bootstrap output
    state_kms_key_arn), consumed by encryption.tf's aws_kms key provider. Restricted, not
    secret (BR-D4) -- no default, set via TF_VAR_state_kms_key_arn locally and
    secrets.STATE_KMS_KEY_ARN in deploy.yml (BR-D21's GitHub Actions exception: a vars.*
    value is dumped into every step's log preamble).

    WHERE IT IS REQUIRED, measured 2026-08-10 rather than assumed: any REAL `tofu init`
    (deploy.yml's three jobs, and any local plan/apply), because that evaluates the
    encryption block. It is NOT required by `tofu init -backend=false`, which does not
    evaluate the block at all -- so ci.yml's uncredentialed tofu-validate needs neither this
    variable nor AWS credentials, and fork PRs are unaffected.
  EOT

  # Lighter than bootstrap/state-migration.tf's identically-named variable ON PURPOSE, and
  # the difference is the failure direction. There, the value rendered an entire IAM policy
  # Resource, so a "*" failed OPEN into kms:Decrypt on every key in the account. Here it
  # names the key to encrypt with: a wrong or wildcarded value fails CLOSED at init.
  #
  # ⚠️ THIS VALIDATION DOES NOT FIRE ON THE init PATH -- corrected after measurement, having
  # first been written here as though it did. Variable validations are not evaluated during
  # the encryption block's static evaluation, so a real `tofu init` reports its own error
  # instead. ⚠️ AND ONLY ONE OF THE THREE init ERRORS NAMES THIS VARIABLE -- measured, and
  # worth knowing before debugging a red tofu-plan-main:
  #   unset      -> "Unable to compute static value ... encryption.key_provider.aws_kms.state
  #                  depends on var.state_kms_key_arn"          <- names it
  #   empty ""   -> "Unable to build encryption key data / ... no kms_key_id provided"
  #   malformed  -> "... errors were encountered in aws kms configuration"
  # The last two name NEITHER this variable NOR secrets.STATE_KMS_KEY_ARN -- and "empty" is
  # exactly what a deleted or mistyped repository secret renders as in CI, i.e. the realistic
  # failure. So init is self-explanatory only in the unset case; if you hit either of the
  # others, the value is reaching the key provider and the secret is the place to look.
  # This block is belt-and-braces for a later `plan`/`apply`, NOT the thing that makes an
  # init failure readable. Everything fails closed either way.
  # (This paragraph itself is a correction of a correction: it first claimed the validation
  # fired at init, then that all these errors "already name the variable". Both measured
  # false. The error_message below has been right the whole time.)
  validation {
    condition     = startswith(var.state_kms_key_arn, "arn:aws:kms:")
    error_message = "state_kms_key_arn must be a KMS key ARN (arn:aws:kms:...) -- a bare key id or alias would fail inside the encryption block with a KMS error that does not name this variable."
  }
}

variable "budget_notification_email" {
  type        = string
  description = <<-EOT
    Address that receives the 50/80/100% budget notifications. No default on purpose --
    an email address in a public repo is spam bait and PII (BR-D4). Set it via
    TF_VAR_budget_notification_email, never committed.
  EOT
  sensitive   = true
}