# AWS Budgets is a billing/account-level service, not simulated by
# LocalStack, and meaningless there anyway since LocalStack never bills you.
# This resource only applies when use_localstack is false.
#
# IMPORTANT: this alerts on spend, it does not prevent it. There is no AWS
# API that can hard-stop billing automatically and safely. Treat this as an
# early warning, not a circuit breaker, and still get in the habit of
# running scripts/destroy.sh at the end of every session.

resource "aws_budgets_budget" "cost_guard" {
  count = var.use_localstack ? 0 : 1

  name         = "${var.project_name}-budget-guard"
  budget_type  = "COST"
  limit_amount = tostring(var.budget_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_alert_email != "" ? [var.budget_alert_email] : []
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_alert_email != "" ? [var.budget_alert_email] : []
  }

  # Also fire on the *forecast*, not just actual spend, so a runaway
  # NAT Gateway or an accidentally-enabled Multi-AZ RDS gets flagged before
  # the money is actually spent, not just after.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.budget_alert_email != "" ? [var.budget_alert_email] : []
  }
}
