variable "name" {
  description = "Name prefix for every resource in this module."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC. Subnets are carved out of it automatically (/24 each)."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block, e.g. 10.20.0.0/16."
  }
}

variable "az_count" {
  description = "How many availability zones to spread subnets across. An ALB needs at least 2."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 4
    error_message = "az_count must be between 2 and 4."
  }
}

variable "enable_nat_gateway" {
  description = "Create a NAT Gateway so private subnets get outbound internet. NOT Free Tier: billed per hour and per GB."
  type        = bool
  default     = false
}
