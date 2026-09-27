variable "name" {
  description = "Name prefix for every resource in this module."
  type        = string
}

variable "vpc_id" {
  description = "VPC the database security group lives in."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets for the DB subnet group (at least 2 AZs)."
  type        = list(string)
}

variable "allowed_security_group_id" {
  description = "Security group allowed to connect on 3306 (the app/EC2 security group)."
  type        = string
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GB."
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Initial database name."
  type        = string
  default     = "labdb"
}

variable "username" {
  description = "Master username."
  type        = string
  default     = "labadmin"
}

variable "password" {
  description = "Master password."
  type        = string
  sensitive   = true
}
