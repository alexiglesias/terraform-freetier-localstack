output "vpc_id" {
  description = "ID of the VPC."
  value       = module.network.vpc_id
}

output "ec2_instance_id" {
  description = "ID of the EC2 instance."
  value       = module.compute.instance_id
}

output "ec2_public_ip" {
  description = "Public IP of the EC2 instance (SSH)."
  value       = module.compute.public_ip
}

output "ssh_command" {
  description = "Ready-to-paste SSH command."
  value       = "ssh -i ${module.compute.private_key_path} ubuntu@${module.compute.public_ip}"
}

output "alb_url" {
  description = "URL of the web app through the ALB (null when create_alb = false)."
  value       = var.create_alb ? "http://${module.alb[0].dns_name}" : null
}

output "rds_endpoint" {
  description = "RDS endpoint (null when create_rds = false)."
  value       = var.create_rds ? module.database[0].endpoint : null
}
