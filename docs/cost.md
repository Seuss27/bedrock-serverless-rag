# Cost guardrail — ai-lab

An environment left running is the most likely real-world loss this project will ever
produce — larger in expectation than any finding in `docs/hardening_roadmap.md` § 3.4.
This is a notification guardrail, not a hard cap: nothing here stops spend, it only tells
a human when spend crosses a threshold.

## What's provisioned

`environments/ai-lab/budget.tf` declares one `aws_budgets_budget`
(`bedrock-serverless-rag-ai-lab-monthly`), `COST` type, `MONTHLY`, with three ACTUAL-spend
notifications at 50%, 80%, and 100% of `var.budget_limit_usd` (default `20`, i.e. $20/month).

## Setting the notification email

`var.budget_notification_email` has **no default** and is marked `sensitive`. An email
address in a public repo is spam bait and PII (BR-D4 — restricted-but-not-secret data
never reaches the tree). Set it locally before a real `plan`/`apply`:

```powershell
$env:TF_VAR_budget_notification_email = '<your-email>'
```

Never commit this value in a `.tf` or `.tfvars` file.

## Scope: account-wide, not this workload alone

This budget has no `cost_filter` and therefore tracks spend across the **entire AWS
account**, not just this workload. That account is shared with
`glunk-works/global-bootstrap` and bounty-infra's findings archive (`CLAUDE.md`), and
resources here are not consistently tagged, so a tag-based filter would silently
undercount rather than scope correctly — a filtered budget that misses untagged spend is
worse than an honest account-wide one. Expect the 50/80/100% notifications to reflect
combined spend across all projects in the account, not just `bedrock-serverless-rag`.
Narrowing this to a per-workload filter is future work, gated on consistent tagging
existing first.

## What this does NOT cover

There is no AOSS capacity limit alongside this budget.
`aws_opensearchserverless_account_settings` does not exist under any spelling in the AWS
provider (`hashicorp/terraform-provider-aws#41245`, open since 2025-02-05) — a capacity
limit for OpenSearch Serverless is console/CLI-only today. If that provider gap closes,
revisit adding it here.
