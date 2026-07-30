# LocalStack path — always free, no time limit.
# RDS and ALB are LocalStack Pro-only, so both are switched off here;
# everything else (VPC, subnets, routing, EC2, security groups, key pair)
# runs fine against the free/community LocalStack image.

use_localstack = true
aws_region     = "us-east-1"
project_name   = "tf-freetier-lab-local"

allowed_ssh_cidr    = "0.0.0.0/0" # meaningless against LocalStack, but keep it explicit
enable_nat_gateway  = false

instance_type = "t2.micro"

create_rds = false # LocalStack Pro feature — flip on only if you have a Pro license/auth token
create_alb = false # same as above

# db_password is still a required variable even with create_rds = false,
# since Terraform validates all variables regardless of whether a resource
# using them is created. Any placeholder value works here.
db_password = "localstack-placeholder"
