# encryption.tf -- OpenTofu native state encryption (BR-D22, S2 Task 2).
#
# WHY NOT SSE. backend.tf already sets `encrypt = true`, and the state object carried
# ServerSideEncryption: AES256 before this change -- that is SSE-S3, which protects the object
# at rest in S3 and nothing else. It does not protect state from anyone who can legitimately
# s3:GetObject it, and after S2 Task 0c that set includes a plan role assumable from any pull
# request. Native encryption encrypts client-side, so what lands in the bucket is ciphertext
# to every reader of the bucket, privileged or not.
#
# THIS ROOT ONLY -- an amendment to BR-D22, which says "both roots". bootstrap/ is DELETED in
# Task 5, not encrypted; there is no value in encrypting a root that ceases to exist in the
# same sprint. providers.tf already declares required_version >= 1.10.0, which covers native
# encryption's >= 1.7 floor, so no version bump rides this change.
#
# WHAT THIS DOES AND DOES NOT MAKE CREDENTIAL-DEPENDENT -- measured 2026-08-10 on a clean
# checkout, because getting this wrong in either direction is expensive:
#   - `tofu init -backend=false` does NOT evaluate this block. No KMS call, no AWS
#     credentials, and var.state_kms_key_arn need not even be set. So ci.yml's tofu-validate
#     -- uncredentialed by construction (S1b-T2) and a required check -- is unaffected, and
#     fork PRs still pass. Nothing here is an argument for putting AWS credentials into
#     ci.yml; that stays uncredentialed by construction even after S2-T4 PR A puts a
#     credentialed job back on pull_request elsewhere (plan.yml, on the read-only plan role --
#     see that file's header for the F2 residual this reopens at the trigger-type level, even
#     though F3's escalation-capable INSTANCE stays closed).
#   - A REAL `tofu init` DOES evaluate it, and fails closed without the variable
#     ("Unable to compute static value"). deploy.yml's three jobs therefore each set
#     TF_VAR_state_kms_key_arn from secrets.STATE_KMS_KEY_ARN.
#   - ⚠️ Do not re-measure the first point in an already-initialized local directory. A
#     workstation's .terraform names the S3 backend, so init -backend=false reaches for the
#     backend and dies on "No valid credential sources found" WHETHER OR NOT this file
#     exists -- which reads exactly like "the encryption block requires credentials".
#     CLAUDE.md documents that wrinkle and says -reconfigure fixes it; it does not. Test from
#     a clean copy. CI checks out clean, so CI never sees it.
#
# NO `fallback` BLOCK, AND THAT IS A DELIBERATE ONE-WAY DOOR. OpenTofu refuses to read
# plaintext state once an encryption block exists, so the usual adoption path is to ship a
# fallback to an `unencrypted` method, apply once, then strip it in a second PR. That path
# was not needed here: at adoption time this root's state tracked ZERO resources (a 373-byte
# empty skeleton), so it was deleted outright rather than migrated -- BR-D20's "prefer
# rebuilding correctly over migrating carefully", applied to the one artifact that is
# normally the exception. Consequence to know before debugging a future init failure: there
# is no configuration here that will read a plaintext state object. If one appears, it is
# new, and the question is where it came from -- not what fallback to add.
#
# ⚠️ NOT COVERED HERE: the `plan { … }` block, which encrypts saved plan FILES. Out of scope
# for BR-D22, which is about state -- but deploy.yml saves a plan file in all three jobs, and
# a saved plan renders every value BR-D4 forbids (account id, role ARNs, bucket names, the
# collection endpoint). Today that is bounded by the plan file never leaving the runner (no
# artifact upload anywhere in this repo, ephemeral runner, and an explicit rm in an
# `if: always()` step in all three jobs -- destroy-ai-lab's was MISSING and was added by this
# same change, because a bound cited here has to actually exist in every job it covers).
# Worth its own tracked item rather than a silent widening here;
# `plan { method = method.aes_gcm.state }` is the whole change.
terraform {
  encryption {
    key_provider "aws_kms" "state" {
      # var.aws_region rather than a literal: the key provider must call KMS in the region
      # that actually holds the key, and this root already parameterizes its region.
      kms_key_id = var.state_kms_key_arn
      region     = var.aws_region

      # The DATA key spec -- the symmetric key OpenTofu asks KMS to generate and then uses
      # to encrypt state locally. It is not a property of the KMS key itself, and it must
      # match what the aes_gcm method below expects.
      key_spec = "AES_256"
    }

    method "aes_gcm" "state" {
      keys = key_provider.aws_kms.state
    }

    state {
      method = method.aes_gcm.state

      # enforced = true is the CONFIG-LEVEL expression of this file's "no fallback" prose
      # above, and it is here because prose was the only thing holding that invariant.
      # Nothing in the green gate or the six required checks can see this block at all --
      # `-backend=false` does not evaluate it, and tflint/checkov/zizmor do not model it --
      # so a later PR swapping aes_gcm for an unencrypted method, or adding a fallback for
      # a debugging session, would pass every check green and the next apply would write
      # PLAINTEXT state into a versioning-Enabled bucket, where BR-D22's amendment (4) says
      # it persists forever. `enforced` turns that into a hard init failure instead.
      #
      # ⚠️ THE TRADE, stated rather than inherited: bootstrap/state-backend.tf enables
      # versioning explicitly "so you can roll back if a state file gets corrupted", and
      # every pre-encryption version is already unreadable by this root. `enforced` also
      # forecloses the fallback→apply→strip recovery that a versioned restore would need.
      # Accepted under BR-D20: the corpus is empty and this workload is rebuilt, not
      # recovered -- a destroy → apply cycle is the sanctioned repair, not a state restore.
      # Revisit this line, not the whole design, if that ever stops being true.
      enforced = true
    }
  }
}
