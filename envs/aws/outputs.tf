output "vpc_id" {
  description = "ID of the VPC."
  value       = module.network.vpc_id
}

output "ec2_instance_id" {
  description = "ID of the EC2 instance."
  value       = module.compute.instance_id
}

output "ec2_public_ip" {
  description = "Public IP of the EC2 instance."
  value       = module.compute.public_ip
}

output "web_url" {
  description = "Where to open the site: through the ALB if there is one, otherwise the instance directly."
  value       = var.create_alb ? "http://${module.alb[0].dns_name}" : "http://${module.compute.public_ip}"
}

output "ssm_command" {
  description = "Open a shell on the instance without SSH (needs the AWS CLI Session Manager plugin)."
  value       = var.enable_ssm ? "aws ssm start-session --region ${var.aws_region} --target ${module.compute.instance_id}" : null
}

output "ssh_command" {
  description = "SSH command (null when SSH is disabled)."
  value       = var.allowed_ssh_cidr != null ? "ssh -i ${module.compute.private_key_path} ubuntu@${module.compute.public_ip}" : null
}

output "rds_endpoint" {
  description = "RDS endpoint (null when create_rds = false)."
  value       = var.create_rds ? module.database[0].endpoint : null
}

output "rds_password_command" {
  description = "Fetch the RDS master credentials from Secrets Manager (null when create_rds = false)."
  value       = var.create_rds ? "aws secretsmanager get-secret-value --region ${var.aws_region} --secret-id '${module.database[0].master_user_secret_arn}' --query SecretString --output text" : null
}
