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
  description = "EC2 instance type."
  type        = string
  default     = "t2.micro"
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to reach the instance on port 22."
  type        = string
}

variable "private_key_path" {
  description = "Where to write the generated SSH private key on the machine running Terraform."
  type        = string
}
