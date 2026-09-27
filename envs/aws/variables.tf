variable "project_name" {
  description = "Short name used to prefix and tag every resource."
  type        = string
  default     = "tf-freetier-lab"
}

variable "aws_region" {
  description = "AWS region to deploy into. AZs are looked up automatically."
  type        = string
  default     = "us-east-1"
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "az_count" {
  description = "Number of AZs to spread subnets across (ALB needs >= 2)."
  type        = number
  default     = 2
}

variable "enable_nat_gateway" {
  description = "Create a NAT Gateway. NOT Free Tier - leave off unless you need it."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Compute
# ---------------------------------------------------------------------------

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t2.micro"
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH to the instance. Your own IP as x.x.x.x/32."
  type        = string
}

# ---------------------------------------------------------------------------
# Optional components
# ---------------------------------------------------------------------------

variable "create_alb" {
  description = "Create the Application Load Balancer in front of the instance."
  type        = bool
  default     = true
}

variable "create_rds" {
  description = "Create the RDS MySQL instance."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Database
# ---------------------------------------------------------------------------

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "db_password" {
  description = "RDS master password. Pass via TF_VAR_db_password, never commit it."
  type        = string
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Budget alert
# ---------------------------------------------------------------------------

variable "budget_limit_usd" {
  description = "Monthly budget in USD that triggers the alert."
  type        = number
  default     = 1
}

variable "budget_alert_email" {
  description = "Email that receives budget alerts."
  type        = string
  default     = ""
}
