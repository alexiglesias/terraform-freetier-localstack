# Generates a fresh SSH key pair with Terraform itself, so there's nothing
# to create by hand in the console first. The private key is written locally
# and gitignored — never commit it.

resource "tls_private_key" "ec2" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "ec2" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.ec2.public_key_openssh

  tags = {
    Name = "${var.project_name}-key"
  }
}

resource "local_file" "private_key" {
  content         = tls_private_key.ec2.private_key_openssh
  filename        = "${path.module}/${var.project_name}.pem"
  file_permission = "0400"
}
