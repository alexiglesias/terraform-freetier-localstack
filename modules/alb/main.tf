# ---------------------------------------------------------------------------
# Security: internet -> ALB :80, ALB -> target :target_port, nothing else.
# ---------------------------------------------------------------------------

resource "aws_security_group" "this" {
  name        = "${var.name}-alb-sg"
  description = "Application Load Balancer"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-alb-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "http_from_internet" {
  # checkov:skip=CKV_AWS_260:A public website must accept port 80 from the internet; only the ALB is exposed.
  security_group_id = aws_security_group.this.id
  description       = "HTTP from anywhere"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "to_target" {
  security_group_id            = aws_security_group.this.id
  description                  = "Forward to targets only"
  ip_protocol                  = "tcp"
  from_port                    = var.target_port
  to_port                      = var.target_port
  referenced_security_group_id = var.target_security_group_id
}

# The rule that lets the ALB reach the instance lives here, next to the ALB,
# so it only exists when the ALB exists.
resource "aws_vpc_security_group_ingress_rule" "target_from_alb" {
  # checkov:skip=CKV_AWS_260:False positive - the source is the ALB security group, not 0.0.0.0/0.
  security_group_id            = var.target_security_group_id
  description                  = "HTTP from the ALB"
  ip_protocol                  = "tcp"
  from_port                    = var.target_port
  to_port                      = var.target_port
  referenced_security_group_id = aws_security_group.this.id
}

# ---------------------------------------------------------------------------
# Load balancer
# ---------------------------------------------------------------------------

resource "aws_lb" "this" {
  # checkov:skip=CKV2_AWS_20:HTTPS needs a domain + ACM certificate; this lab has no domain.
  # checkov:skip=CKV2_AWS_28:WAF costs ~$5+/month; out of scope for a cost-capped lab.
  # checkov:skip=CKV_AWS_91:Access logs need an extra S3 bucket and policy; out of scope here.
  # checkov:skip=CKV_AWS_150:Deletion protection would block `make destroy`, which runs after every session.
  name               = "${var.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.this.id]
  subnets            = var.subnet_ids

  # Reject malformed HTTP headers (request-smuggling protection). Free.
  drop_invalid_header_fields = true

  tags = { Name = "${var.name}-alb" }
}

resource "aws_lb_target_group" "this" {
  # checkov:skip=CKV_AWS_378:ALB -> instance traffic stays inside the VPC; TLS ends at the ALB (when a domain exists).
  name        = "${var.name}-tg"
  port        = var.target_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = { Name = "${var.name}-tg" }
}

resource "aws_lb_target_group_attachment" "this" {
  target_group_arn = aws_lb_target_group.this.arn
  target_id        = var.target_instance_id
  port             = var.target_port
}

resource "aws_lb_listener" "http" {
  # checkov:skip=CKV_AWS_2:HTTP only - HTTPS needs a domain + ACM certificate; this lab has no domain.
  # checkov:skip=CKV_AWS_103:No TLS listener exists, so there is no TLS policy to set (see CKV_AWS_2).
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
