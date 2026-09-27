variable "project_name" {
  description = "Short name used to prefix and tag every resource."
  type        = string
  default     = "tf-freetier-lab"
}

variable "aws_account_id" {
  description = "The only AWS account this configuration may touch (12 digits)."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be exactly 12 digits."
  }
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
  description = "EC2 instance type. t3.micro is Free Tier eligible on old and new AWS accounts; t2.micro is NOT for accounts created after 15 July 2025."
  type        = string
  default     = "t3.micro"
}

variable "allowed_ssh_cidr" {
  description = "Your IP as x.x.x.x/32 to enable SSH. Leave null (default) for no SSH - connect with SSM Session Manager instead."
  type        = string
  default     = null
}

variable "enable_ssm" {
  description = "Allow shell access through SSM Session Manager (recommended over SSH)."
  type        = bool
  default     = true
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

