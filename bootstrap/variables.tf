variable "project_name" {
  description = "Short name used to prefix and tag every resource."
  type        = string
  default     = "tf-freetier-lab"
}

variable "aws_region" {
  description = "Region for the state bucket (use the same one as envs/aws)."
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "The only AWS account this configuration may touch (12 digits)."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be exactly 12 digits."
  }
}

variable "budget_limit_usd" {
  description = "Monthly spend in USD that triggers the alerts. Deploying envs/aws costs roughly $0.07/hour while it runs."
  type        = number
  default     = 5

  validation {
    condition     = var.budget_limit_usd > 0
    error_message = "budget_limit_usd must be greater than 0."
  }
}

variable "budget_alert_email" {
  description = "Email that receives the budget alerts."
  type        = string

  validation {
    condition     = can(regex("^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$", var.budget_alert_email))
    error_message = "budget_alert_email must be a valid email address - an alert nobody receives is not an alert."
  }
}
