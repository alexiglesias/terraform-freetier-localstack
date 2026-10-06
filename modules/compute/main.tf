locals {
  ssh_enabled = var.allowed_ssh_cidr != null
}

# ---------------------------------------------------------------------------
# AMI
# ---------------------------------------------------------------------------

# Latest official Ubuntu 24.04 LTS (Noble) for x86_64 - only looked up when
# no ami_id is passed in. Canonical publishes Noble under "hvm-ssd-gp3".
data "aws_ami" "ubuntu" {
  count = var.ami_id == null ? 1 : 0

  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  ami_id = var.ami_id != null ? var.ami_id : data.aws_ami.ubuntu[0].id
}

# ---------------------------------------------------------------------------
# SSH key pair - only when SSH is enabled. The private key is written
# locally (gitignored via *.pem) and is ALSO stored in Terraform state,
# which is one more reason to prefer SSM.
# ---------------------------------------------------------------------------

resource "tls_private_key" "this" {
  count = local.ssh_enabled ? 1 : 0

  algorithm = "ED25519"
}

resource "aws_key_pair" "this" {
  count = local.ssh_enabled ? 1 : 0

  key_name   = "${var.name}-key"
  public_key = tls_private_key.this[0].public_key_openssh

  tags = { Name = "${var.name}-key" }
}

resource "local_sensitive_file" "private_key" {
  count = local.ssh_enabled ? 1 : 0

  content         = tls_private_key.this[0].private_key_openssh
  filename        = var.private_key_path
  file_permission = "0400"

  lifecycle {
    precondition {
      condition     = var.private_key_path != null
      error_message = "private_key_path must be set when allowed_ssh_cidr is set."
    }
  }
}

# ---------------------------------------------------------------------------
# SSM Session Manager: shell access through the AWS API instead of an open
# port. Ubuntu AMIs ship with the SSM agent; it only needs this IAM role and
# outbound HTTPS. Session Manager itself has no extra charge.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "ec2_assume" {
  count = var.enable_ssm ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ssm" {
  count = var.enable_ssm ? 1 : 0

  name               = "${var.name}-ec2-ssm"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume[0].json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  count = var.enable_ssm ? 1 : 0

  role       = aws_iam_role.ssm[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  count = var.enable_ssm ? 1 : 0

  name = "${var.name}-ec2-ssm"
  role = aws_iam_role.ssm[0].name
}

# ---------------------------------------------------------------------------
# Security group. Rules are separate resources (not inline blocks) so that
# other modules - e.g. the ALB - can attach their own rules to this group
# without Terraform fighting over who owns the rule list.
# ---------------------------------------------------------------------------

resource "aws_security_group" "this" {
  name        = "${var.name}-ec2-sg"
  description = "Web instance"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-ec2-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  count = local.ssh_enabled ? 1 : 0

  security_group_id = aws_security_group.this.id
  description       = "SSH from allowed_ssh_cidr"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.allowed_ssh_cidr
}

resource "aws_vpc_security_group_ingress_rule" "http_public" {
  for_each = toset(var.public_http_cidrs)

  security_group_id = aws_security_group.this.id
  description       = "HTTP direct to the instance (no ALB)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  description       = "All outbound (apt, SSM agent)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ---------------------------------------------------------------------------
# Instance
# ---------------------------------------------------------------------------

resource "aws_instance" "this" {
  # checkov:skip=CKV_AWS_126:Detailed (1-minute) monitoring is billed; basic 5-minute metrics are enough here.
  ami                    = local.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  key_name               = local.ssh_enabled ? aws_key_pair.this[0].key_name : null
  iam_instance_profile   = var.enable_ssm ? aws_iam_instance_profile.ssm[0].name : null
  vpc_security_group_ids = [aws_security_group.this.id]
  ebs_optimized          = true # free on t3 (on by default); stated explicitly

  # IMDSv2 only: the metadata service (which hands out the instance's IAM
  # credentials) requires a session token, which blocks the classic SSRF
  # trick of making the app fetch http://169.254.169.254/... for an attacker.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Encrypted gp3 root disk. Encryption with the AWS-managed key is free;
  # 30 GB of EBS is inside the Free Tier.
  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  # user_data only runs on first boot, so a change to it should rebuild the
  # instance instead of silently doing nothing.
  user_data_replace_on_change = true

  user_data = <<-EOT
    #!/bin/bash
    set -euo pipefail
    apt-get update -y
    apt-get install -y nginx
    echo "<h1>${var.name} - deployed by Terraform</h1>" > /var/www/html/index.html
    systemctl enable nginx
    systemctl restart nginx
  EOT

  tags = { Name = "${var.name}-web" }
}
