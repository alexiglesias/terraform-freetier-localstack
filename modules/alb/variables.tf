variable "name" {
  description = "Name prefix for every resource in this module."
  type        = string
}

variable "vpc_id" {
  description = "VPC the ALB and target group live in."
  type        = string
}

variable "subnet_ids" {
  description = "Public subnets for the ALB (at least 2, in different AZs)."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "An Application Load Balancer needs subnets in at least 2 AZs."
  }
}

variable "target_instance_id" {
  description = "EC2 instance to register in the target group."
  type        = string
}

variable "target_security_group_id" {
  description = "Security group of the target. This module adds an ingress rule to it allowing traffic from the ALB only."
  type        = string
}

variable "target_port" {
  description = "Port the target listens on."
  type        = number
  default     = 80
}
