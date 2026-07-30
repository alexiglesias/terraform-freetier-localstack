variable "use_localstack" {
  description = "If true, point every AWS API call at a local LocalStack endpoint instead of real AWS. Toggles cost, region checks and credential validation accordingly."
  type        = bool
  default     = false
}

variable "aws_region" {
  description = "AWS region to deploy into (real AWS) or to simulate (LocalStack)."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used to prefix and tag every resource this project creates."
  type        = string
  default     = "tf-freetier-lab"
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zones" {
  description = "Two AZs to spread the public/private subnets across."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets (one per AZ)."
  type        = list(string)
  default     = ["10.20.0.0/24", "10.20.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets (one per AZ)."
  type        = list(string)
  default     = ["10.20.10.0/24", "10.20.11.0/24"]
}

variable "enable_nat_gateway" {
  description = "Whether to create a NAT Gateway for the private subnets. NAT Gateways are NOT Free Tier (~$0.045/h + data), so this defaults to false; flip it on deliberately and tear it down promptly."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# EC2
# ---------------------------------------------------------------------------

variable "instance_type" {
  description = "EC2 instance type. t2.micro is the Free Tier eligible type in most regions."
  type        = string
  default     = "t2.micro"
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to reach the EC2 instance on port 22. Set this to your own IP/32, never 0.0.0.0/0."
  type        = string
  default     = "0.0.0.0/0" # overridden per-environment in environments/*.tfvars
}

# ---------------------------------------------------------------------------
# RDS
# ---------------------------------------------------------------------------

variable "create_rds" {
  description = "Whether to create the RDS instance. RDS and ALB are LocalStack Pro features, not available on the free/community LocalStack image, so this is toggled off by default when use_localstack is true (see environments/localstack.tfvars)."
  type        = bool
  default     = true
}

variable "db_instance_class" {
  description = "RDS instance class. db.t3.micro is Free Tier eligible (750h/month, 20GB storage)."
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB. 20GB is the Free Tier ceiling."
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Initial database name."
  type        = string
  default     = "labdb"
}

variable "db_username" {
  description = "Master username for RDS."
  type        = string
  default     = "labadmin"
}

variable "db_password" {
  description = "Master password for RDS. No default on purpose: pass via TF_VAR_db_password or a .auto.tfvars file that is gitignored, never commit it."
  type        = string
  sensitive   = true
}

# ---------------------------------------------------------------------------
# ALB
# ---------------------------------------------------------------------------

variable "create_alb" {
  description = "Whether to create the Application Load Balancer. Same LocalStack Pro caveat as create_rds."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Budget alert (real AWS only)
# ---------------------------------------------------------------------------

variable "budget_limit_usd" {
  description = "Monthly budget ceiling in USD that triggers the alert. Keep this tiny (e.g. 1) so any real spend gets flagged immediately."
  type        = number
  default     = 1
}

variable "budget_alert_email" {
  description = "Email address to notify when the budget threshold is crossed. Required on real AWS, ignored on LocalStack."
  type        = string
  default     = ""
}
