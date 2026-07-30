# RDS is behind create_rds because it (along with ALB) is a LocalStack Pro
# feature, not available on the free LocalStack image. On real AWS you'd
# leave this at its default of true.

resource "aws_db_subnet_group" "main" {
  count      = var.create_rds ? 1 : 0
  name       = "${var.project_name}-db-subnets"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.project_name}-db-subnets"
  }
}

resource "aws_db_instance" "main" {
  count = var.create_rds ? 1 : 0

  identifier     = "${var.project_name}-db"
  engine         = "mysql"
  engine_version = "8.0"

  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  storage_type      = "gp2"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main[0].name
  vpc_security_group_ids = [aws_security_group.rds[0].id]

  multi_az            = false # Multi-AZ is not Free Tier eligible
  publicly_accessible = false

  # Lab-appropriate settings: this database is not meant to hold anything
  # you can't afford to lose, and skip_final_snapshot avoids leaving a
  # snapshot behind (snapshots are billed) after `terraform destroy`.
  skip_final_snapshot = true
  deletion_protection = false
  apply_immediately   = true

  backup_retention_period = 0

  tags = {
    Name = "${var.project_name}-db"
  }
}
