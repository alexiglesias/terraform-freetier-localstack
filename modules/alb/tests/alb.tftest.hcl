# Unit tests for the alb module, with a mock provider (no AWS, no cost).

# The provider validates ARN formats, so give the mocks realistic ARNs.
mock_provider "aws" {
  mock_resource "aws_lb" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/test-alb/0123456789abcdef"
    }
  }
  mock_resource "aws_lb_target_group" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/test-tg/0123456789abcdef"
    }
  }
}

variables {
  name                     = "test"
  vpc_id                   = "vpc-12345678"
  subnet_ids               = ["subnet-11111111", "subnet-22222222"]
  target_instance_id       = "i-12345678"
  target_security_group_id = "sg-12345678"
}

run "alb_wiring" {
  command = plan

  assert {
    condition     = aws_lb.this.internal == false && aws_lb.this.drop_invalid_header_fields == true
    error_message = "ALB should be internet-facing and drop invalid headers."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.target_from_alb.security_group_id == "sg-12345678" && aws_vpc_security_group_ingress_rule.target_from_alb.from_port == 80
    error_message = "The ALB must add a port-80 rule to the target's security group."
  }

  assert {
    condition     = aws_vpc_security_group_egress_rule.to_target.referenced_security_group_id == "sg-12345678"
    error_message = "ALB egress must be limited to the target security group."
  }
}

run "rejects_single_subnet" {
  command = plan

  variables {
    subnet_ids = ["subnet-11111111"]
  }

  expect_failures = [var.subnet_ids]
}
