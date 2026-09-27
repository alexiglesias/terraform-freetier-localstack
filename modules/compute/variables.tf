variable "name" {
  description = "Name prefix for every resource in this module."
  type        = string
}

variable "vpc_id" {
  description = "VPC to create the instance's security group in."
  type        = string
}

variable "subnet_id" {
  description = "Subnet to launch the instance into."
  type        = string
}

variable "ami_id" {
  description = "AMI to launch. Leave null to use the latest official Canonical Ubuntu image. Set it on emulators (LocalStack) that don't have real Canonical AMIs."
  type        = string
  default     = null
}

variable "instance_type" {
  description = "EC2 instance type (x86_64). t3.micro is Free Tier eligible for both old and new (post July 2025) AWS accounts."
  type        = string
  default     = "t3.micro"
}

variable "root_volume_size" {
  description = "Root disk size in GB (gp3, encrypted). Ubuntu needs at least 8."
  type        = number
  default     = 8

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 30
    error_message = "root_volume_size must be between 8 and 30 GB (30 GB is the Free Tier EBS limit)."
  }
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH on port 22, e.g. your IP as x.x.x.x/32. null = no SSH at all (no port 22 rule, no key pair) - use SSM Session Manager instead."
  type        = string
  default     = null

  validation {
    condition     = var.allowed_ssh_cidr == null || can(cidrhost(var.allowed_ssh_cidr, 0))
    error_message = "allowed_ssh_cidr must be null or a valid IPv4 CIDR, e.g. 203.0.113.10/32."
  }

  validation {
    condition     = var.allowed_ssh_cidr == null || try(tonumber(split("/", var.allowed_ssh_cidr)[1]) >= 16, false)
    error_message = "allowed_ssh_cidr is too broad: SSH must be limited to a /16 or smaller (ideally your own IP as /32). Never 0.0.0.0/0."
  }
}

variable "enable_ssm" {
  description = "Attach an IAM role that lets you open a shell with AWS SSM Session Manager (no open port, no SSH key needed)."
  type        = bool
  default     = true
}

variable "public_http_cidrs" {
  description = "CIDRs allowed to reach the instance directly on port 80. Leave empty when an ALB sits in front (the ALB module adds its own rule)."
  type        = list(string)
  default     = []
}

variable "private_key_path" {
  description = "Where to write the generated SSH private key. Only used when allowed_ssh_cidr is set."
  type        = string
  default     = null
}
