# Real AWS Free Tier path.
# db_password is deliberately NOT set here — pass it as
# TF_VAR_db_password or in a gitignored terraform.auto.tfvars,
# never commit a real password to a tracked .tfvars file.

use_localstack = false
aws_region     = "us-east-1"
project_name   = "tf-freetier-lab"

# Lock this down to your own IP before applying: `curl -s ifconfig.me`
allowed_ssh_cidr = "0.0.0.0/0" # CHANGE ME to "<your-ip>/32"

# NAT Gateway costs money even within the Free Tier — leave this off
# unless you specifically need outbound internet from the private subnets.
enable_nat_gateway = false

instance_type      = "t2.micro"
db_instance_class  = "db.t3.micro"
create_rds         = true
create_alb         = true

budget_limit_usd    = 1
budget_alert_email  = "" # CHANGE ME — required for the budget alert to notify anyone
