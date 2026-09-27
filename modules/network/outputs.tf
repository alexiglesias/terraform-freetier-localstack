output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "azs" {
  description = "Availability zones the subnets were spread across."
  value       = local.azs
}

output "public_subnet_ids" {
  description = "IDs of the public subnets, in AZ order."
  value       = [for az in local.azs : aws_subnet.public[az].id]
}

output "private_subnet_ids" {
  description = "IDs of the private subnets, in AZ order."
  value       = [for az in local.azs : aws_subnet.private[az].id]
}
