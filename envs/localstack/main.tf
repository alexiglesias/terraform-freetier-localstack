# The LocalStack Hobby (free) plan includes EC2 but not RDS or ELB,
# so this environment deploys the network and the instance only.

# LocalStack doesn't have Canonical's real AMIs, only its own set of
# emulated images, so pick whichever Ubuntu image it offers. Filtering
# without an owner is unsafe on real AWS (anyone can publish an AMI called
# "ubuntu"), which is why the provider makes us opt in - fine on an emulator.
data "aws_ami" "ubuntu" {
  most_recent         = true
  allow_unsafe_filter = true

  filter {
    name   = "name"
    values = ["*ubuntu*"]
  }
}

module "network" {
  source = "../../modules/network"

  name     = var.project_name
  vpc_cidr = var.vpc_cidr
  az_count = var.az_count
}

module "compute" {
  source = "../../modules/compute"

  name             = var.project_name
  vpc_id           = module.network.vpc_id
  subnet_id        = module.network.public_subnet_ids[0]
  ami_id           = data.aws_ami.ubuntu.id
  instance_type    = var.instance_type
  allowed_ssh_cidr = var.allowed_ssh_cidr
  enable_ssm       = false # SSM Session Manager is not in the LocalStack Hobby plan
  private_key_path = "${path.root}/${var.project_name}.pem"
}
