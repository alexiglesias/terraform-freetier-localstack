output "vpc_id" {
  description = "ID of the VPC created by this project."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets."
  value       = aws_subnet.private[*].id
}

output "ec2_instance_id" {
  description = "ID of the EC2 web instance."
  value       = aws_instance.web.id
}

output "ec2_public_ip" {
  description = "Public IP of the EC2 web instance. On real AWS, curl this on port 80 to see the Terraform-deployed nginx page."
  value       = aws_instance.web.public_ip
}

output "ssh_private_key_path" {
  description = "Path to the generated private key, for `ssh -i <path> ubuntu@<ec2_public_ip>`."
  value       = local_file.private_key.filename
}

output "alb_dns_name" {
  description = "Public DNS name of the ALB, if created (null when create_alb = false)."
  value       = var.create_alb ? aws_lb.main[0].dns_name : null
}

output "rds_endpoint" {
  description = "Connection endpoint for the RDS instance, if created (null when create_rds = false). Marked sensitive since it reveals internal addressing."
  value       = var.create_rds ? aws_db_instance.main[0].endpoint : null
  sensitive   = true
}

output "budget_guard_active" {
  description = "Whether the AWS Budget cost-guard alarm is active for this apply (always false on LocalStack)."
  value       = !var.use_localstack
}
