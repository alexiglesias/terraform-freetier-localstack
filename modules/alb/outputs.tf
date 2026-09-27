output "dns_name" {
  description = "Public DNS name of the ALB."
  value       = aws_lb.this.dns_name
}

output "security_group_id" {
  description = "Security group attached to the ALB."
  value       = aws_security_group.this.id
}
