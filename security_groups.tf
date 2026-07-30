# ---------------------------------------------------------------------------
# ALB security group: open to the world on HTTP
# ---------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  count       = var.create_alb ? 1 : 0
  name        = "${var.project_name}-alb-sg"
  description = "Allow inbound HTTP from the internet to the ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# ---------------------------------------------------------------------------
# EC2 security group: SSH from a known IP, app port from the ALB only
# ---------------------------------------------------------------------------

resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "SSH from an allowed CIDR, HTTP from the ALB security group only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from allowed_ssh_cidr"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description     = "HTTP from the ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = var.create_alb ? [aws_security_group.alb[0].id] : []
    # If create_alb is false there is no ALB security group to reference,
    # so this rule is simply skipped (empty security_groups list).
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ec2-sg"
  }
}

# ---------------------------------------------------------------------------
# RDS security group: MySQL from the EC2 security group only, never the world
# ---------------------------------------------------------------------------

resource "aws_security_group" "rds" {
  count       = var.create_rds ? 1 : 0
  name        = "${var.project_name}-rds-sg"
  description = "MySQL from the EC2 instance only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from EC2"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}
