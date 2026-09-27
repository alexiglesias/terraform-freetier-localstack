output "state_bucket" {
  description = "S3 bucket holding the envs/aws state."
  value       = aws_s3_bucket.state.bucket
}

output "backend_config_file" {
  description = "Generated backend settings for envs/aws."
  value       = local_file.aws_backend_config.filename
}

output "next_step" {
  description = "What to run next."
  value       = "terraform -chdir=envs/aws init -backend-config=backend.hcl"
}
