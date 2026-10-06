# Unit tests for the compute module, with mock providers (no AWS, no cost).

mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}
mock_provider "tls" {}
mock_provider "local" {}

variables {
  name             = "test"
  vpc_id           = "vpc-12345678"
  subnet_id        = "subnet-12345678"
  ami_id           = "ami-12345678"
  private_key_path = "./test.pem"
}

run "secure_defaults" {
  command = plan

  assert {
    condition     = aws_instance.this.instance_type == "t3.micro"
    error_message = "Default instance type should be the Free Tier t3.micro."
  }

  assert {
    condition     = aws_instance.this.metadata_options[0].http_tokens == "required"
    error_message = "IMDSv2 must be required."
  }

  assert {
    condition     = aws_instance.this.root_block_device[0].encrypted == true && aws_instance.this.root_block_device[0].volume_type == "gp3"
    error_message = "Root disk must be encrypted gp3."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.ssh) == 0 && length(aws_key_pair.this) == 0
    error_message = "SSH (port 22 rule and key pair) must be off by default."
  }

  assert {
    condition     = length(aws_iam_instance_profile.ssm) == 1
    error_message = "SSM instance profile should be attached by default."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.http_public) == 0
    error_message = "Port 80 must not be public unless explicitly requested."
  }
}

run "ssh_enabled_for_one_ip" {
  command = plan

  variables {
    allowed_ssh_cidr = "203.0.113.10/32"
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.ssh) == 1 && aws_vpc_security_group_ingress_rule.ssh[0].cidr_ipv4 == "203.0.113.10/32"
    error_message = "SSH rule should allow exactly the given /32."
  }

  assert {
    condition     = length(aws_key_pair.this) == 1
    error_message = "A key pair should be created when SSH is enabled."
  }
}

run "rejects_ssh_from_the_whole_internet" {
  command = plan

  variables {
    allowed_ssh_cidr = "0.0.0.0/0"
  }

  expect_failures = [var.allowed_ssh_cidr]
}

run "rejects_oversized_root_disk" {
  command = plan

  variables {
    root_volume_size = 50
  }

  expect_failures = [var.root_volume_size]
}

run "public_http_only_when_asked" {
  command = plan

  variables {
    public_http_cidrs = ["0.0.0.0/0"]
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.http_public) == 1
    error_message = "public_http_cidrs should open port 80 for each CIDR given."
  }
}
