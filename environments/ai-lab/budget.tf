# The most likely real-world loss this project will ever produce is an environment left
# running, not any finding in the roadmap's § 3.4 inventory (S0 task 8 / sprint plan
# banner). This budget is a cost guardrail only -- it notifies, it does not enforce a cap.
#
# There is NO AOSS capacity-limit companion here: aws_opensearchserverless_account_settings
# does not exist under any spelling in the AWS provider (hashicorp/terraform-provider-aws
# #41245, open since 2025-02-05). A capacity limit is console/CLI-only and out of scope for
# this task.
#
# NO cost_filter: this account is shared with glunk-works/global-bootstrap and
# bounty-infra's findings archive (CLAUDE.md), and resources here are not consistently
# tagged, so a tag-based filter would silently undercount rather than scope correctly. This
# budget is account-wide BY ACCEPTANCE, not by oversight -- it will trip on other projects'
# baseline spend too. See docs/cost.md.

resource "aws_budgets_budget" "ai_lab_monthly" {
  name         = "bedrock-serverless-rag-ai-lab-monthly"
  budget_type  = "COST"
  limit_amount = var.budget_limit_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_notification_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_notification_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_notification_email]
  }
}
