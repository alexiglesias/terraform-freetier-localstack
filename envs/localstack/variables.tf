# Everything has a default: nothing here is personal or secret, so the
# LocalStack environment runs with a plain `terraform apply`.

variable "project_name" {
  description = "Short name used to prefix and tag every resource."
  type        = string
  default     = "tf-freetier-lab-local"
}

variable "aws_region" {
  description = "Region LocalStack simulates."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "az_count" {
  description = "Number of AZs to spread subnets across."
  type        = number
  default     = 2
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t2.micro"
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH. Nothing is reachable on LocalStack anyway."
  type        = string
  default     = "127.0.0.1/32"
}
