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
  identifier     = "${var.name}-db"
  engine         = "mysql"
  engine_version = "8.0"

  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_type      = "gp2"

  db_name  = var.db_name
  username = var.username
  password = var.password

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]

  multi_az            = false # Multi-AZ is not Free Tier eligible
  publicly_accessible = false

  # Lab settings: nothing here is worth a (billed) final snapshot.
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true
  backup_retention_period = 0

  tags = { Name = "${var.name}-db" }
}
