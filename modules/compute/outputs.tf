output "instance_id" {
  description = "ID of the EC2 instance."
  value       = aws_instance.this.id
}

output "public_ip" {
  description = "Public IP of the EC2 instance."
  value       = aws_instance.this.public_ip
}

output "security_group_id" {
  description = "Security group attached to the instance. Other modules add rules to it."
  value       = aws_security_group.this.id
}

output "private_key_path" {
  description = "Path to the generated SSH private key (null when SSH is disabled)."
  value       = one(local_sensitive_file.private_key[*].filename)
}
