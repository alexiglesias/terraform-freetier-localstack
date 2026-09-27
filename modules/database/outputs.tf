output "endpoint" {
  description = "Connection endpoint (host:port)."
  value       = aws_db_instance.this.endpoint
}

output "security_group_id" {
  description = "Security group attached to the database."
  value       = aws_security_group.this.id
}
