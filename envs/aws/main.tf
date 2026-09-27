module "network" {
  source = "../../modules/network"

  name               = var.project_name
  vpc_cidr           = var.vpc_cidr
  az_count           = var.az_count
  enable_nat_gateway = var.enable_nat_gateway
}

module "compute" {
  source = "../../modules/compute"

  name             = var.project_name
  vpc_id           = module.network.vpc_id
  subnet_id        = module.network.public_subnet_ids[0]
  instance_type    = var.instance_type
  allowed_ssh_cidr = var.allowed_ssh_cidr
  enable_ssm       = var.enable_ssm
  private_key_path = "${path.root}/${var.project_name}.pem"

  # With an ALB, only the ALB may reach port 80 (the alb module adds that
  # rule). Without one, open port 80 so the site is still reachable.
  public_http_cidrs = var.create_alb ? [] : ["0.0.0.0/0"]
}

module "alb" {
  source = "../../modules/alb"
  count  = var.create_alb ? 1 : 0

  name                     = var.project_name
  vpc_id                   = module.network.vpc_id
  subnet_ids               = module.network.public_subnet_ids
  target_instance_id       = module.compute.instance_id
  target_security_group_id = module.compute.security_group_id
}

module "database" {
  source = "../../modules/database"
  count  = var.create_rds ? 1 : 0

  name                      = var.project_name
  vpc_id                    = module.network.vpc_id
  subnet_ids                = module.network.private_subnet_ids
  allowed_security_group_id = module.compute.security_group_id
  instance_class            = var.db_instance_class
  password                  = var.db_password
}
