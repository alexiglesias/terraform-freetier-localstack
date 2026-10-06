resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db-subnets"
  subnet_ids = var.subnet_ids

  tags = { Name = "${var.name}-db-subnets" }
}

# No egress rule on purpose: RDS answers connections, it never needs to start
# them. (aws_security_group removes AWS's default allow-all egress rule.)
resource "aws_security_group" "this" {
  name        = "${var.name}-rds-sg"
  description = "MySQL from the app security group only"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-rds-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "mysql_from_app" {
  security_group_id            = aws_security_group.this.id
  description                  = "MySQL from the app"
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = var.allowed_security_group_id
}

resource "aws_db_instance" "this" {
  # checkov:skip=CKV_AWS_157:Multi-AZ doubles the cost; single-AZ is fine for a lab.
  # checkov:skip=CKV_AWS_118:Enhanced monitoring is billed via CloudWatch; basic metrics are enough here.
  # checkov:skip=CKV_AWS_129:Log exports create never-expiring CloudWatch log groups; not worth it for a lab DB.
  # checkov:skip=CKV_AWS_133:Backups disabled on purpose - the lab DB holds no data worth keeping.
  # checkov:skip=CKV_AWS_293:Deletion protection would block `make destroy`, which runs after every session.
  identifier     = "${var.name}-db"
  engine         = "mysql"
  engine_version = var.engine_version

  # Never silently enrol in paid Extended Support: if the version ever falls
  # out of standard support, AWS refuses to create it instead of billing.
  engine_lifecycle_support   = "open-source-rds-extended-support-disabled"
  auto_minor_version_upgrade = true

  instance_class        = var.instance_class
  allocated_storage     = var.allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true # AWS-managed KMS key, no extra cost
  copy_tags_to_snapshot = true

  db_name  = var.db_name
  username = var.username

  # RDS generates the master password and keeps it in Secrets Manager.
  # It never appears in Terraform code, variables or state.
  manage_master_user_password = true

  # Allow login with short-lived IAM tokens instead of passwords. Free.
  iam_database_authentication_enabled = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]

  multi_az            = false # Multi-AZ doubles the cost
  publicly_accessible = false

  # Lab settings: nothing here is worth a (billed) final snapshot.
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true
  backup_retention_period = 0

  tags = { Name = "${var.name}-db" }
}
