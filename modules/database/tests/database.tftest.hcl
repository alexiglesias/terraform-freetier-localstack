# Unit tests for the database module, with a mock provider (no AWS, no cost).

mock_provider "aws" {}

variables {
  name                      = "test"
  vpc_id                    = "vpc-12345678"
  subnet_ids                = ["subnet-11111111", "subnet-22222222"]
  allowed_security_group_id = "sg-12345678"
}

run "secure_and_cost_aware_defaults" {
  command = plan

  assert {
    condition     = aws_db_instance.this.engine_version == "8.4"
    error_message = "MySQL 8.0 is in paid Extended Support - default must be 8.4."
  }

  assert {
    condition     = aws_db_instance.this.engine_lifecycle_support == "open-source-rds-extended-support-disabled"
    error_message = "Extended Support auto-enrolment must be disabled."
  }

  assert {
    condition     = aws_db_instance.this.storage_encrypted == true && aws_db_instance.this.storage_type == "gp3"
    error_message = "Storage must be encrypted gp3."
  }

  assert {
    condition     = aws_db_instance.this.manage_master_user_password == true
    error_message = "The master password must be managed by RDS (Secrets Manager), never passed in."
  }

  assert {
    condition     = aws_db_instance.this.publicly_accessible == false && aws_db_instance.this.multi_az == false
    error_message = "DB must be private and single-AZ."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.mysql_from_app.from_port == 3306 && aws_vpc_security_group_ingress_rule.mysql_from_app.referenced_security_group_id == "sg-12345678"
    error_message = "Only the app security group may reach MySQL on 3306."
  }
}
