# Unit tests for the network module. They run with a *mock* AWS provider:
# no credentials, no LocalStack, no cost - Terraform only evaluates the plan.
#   terraform -chdir=modules/network init -backend=false
#   terraform -chdir=modules/network test

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d"]
    }
  }
}

variables {
  name = "test"
}

run "defaults_two_azs_with_predictable_cidrs" {
  command = plan

  assert {
    condition     = length(aws_subnet.public) == 2 && length(aws_subnet.private) == 2
    error_message = "Expected 2 public and 2 private subnets by default."
  }

  assert {
    condition     = aws_subnet.public["us-east-1a"].cidr_block == "10.20.0.0/24" && aws_subnet.public["us-east-1b"].cidr_block == "10.20.1.0/24"
    error_message = "Public subnets should be 10.20.0.0/24 and 10.20.1.0/24."
  }

  assert {
    condition     = aws_subnet.private["us-east-1a"].cidr_block == "10.20.10.0/24" && aws_subnet.private["us-east-1b"].cidr_block == "10.20.11.0/24"
    error_message = "Private subnets should start at offset 10 (10.20.10.0/24, 10.20.11.0/24)."
  }

  assert {
    condition     = alltrue([for s in aws_subnet.private : s.map_public_ip_on_launch == false])
    error_message = "Private subnets must never hand out public IPs."
  }
}

run "no_nat_gateway_by_default" {
  command = plan

  assert {
    condition     = length(aws_nat_gateway.this) == 0 && length(aws_eip.nat) == 0
    error_message = "NAT Gateway is not Free Tier and must be off by default."
  }
}

run "nat_gateway_when_enabled" {
  command = plan

  variables {
    enable_nat_gateway = true
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 1
    error_message = "enable_nat_gateway = true should create exactly one NAT Gateway."
  }
}

run "three_azs" {
  command = plan

  variables {
    az_count = 3
  }

  assert {
    condition     = length(aws_subnet.public) == 3 && contains(keys(aws_subnet.public), "us-east-1c")
    error_message = "az_count = 3 should spread subnets over the first 3 AZs."
  }
}

run "rejects_single_az" {
  command = plan

  variables {
    az_count = 1
  }

  expect_failures = [var.az_count]
}

run "rejects_invalid_cidr" {
  command = plan

  variables {
    vpc_cidr = "not-a-cidr"
  }

  expect_failures = [var.vpc_cidr]
}
