# terraform-freetier-localstack

Learn Terraform against real AWS Free Tier infrastructure (EC2 t2.micro, S3, RDS micro) and against LocalStack for local, low/no-cost simulation once the Free Tier runs out. One codebase, two targets, switched by a single variable. Foundational groundwork before layering CI/CD on top of real infrastructure.

## What this deploys

- A VPC with public and private subnets across 2 AZs, an Internet Gateway, and an optional NAT Gateway (off by default — it isn't Free Tier)
- Security groups for a web tier, an ALB, and a database tier, each scoped to only the traffic it actually needs
- An EC2 t2.micro instance running nginx, with a Terraform-generated SSH key pair
- An RDS MySQL db.t3.micro instance in the private subnets *(real AWS only — see LocalStack caveats below)*
- An Application Load Balancer in front of the EC2 instance *(real AWS only — see LocalStack caveats below)*
- An AWS Budget alert that notifies on 80% and 100% of a small monthly ceiling, plus a forecasted-spend check *(real AWS only)*
- An S3 + DynamoDB remote state backend, bootstrapped separately (`backend.tf.example` + `scripts/bootstrap-backend.sh`)

## Two targets, one codebase

Every resource is written once and toggled by `var.use_localstack`, plus `var.create_rds` / `var.create_alb`:

| | Real AWS (`environments/aws.tfvars`) | LocalStack (`environments/localstack.tfvars`) |
|---|---|---|
| VPC, subnets, routing | ✅ | ✅ |
| Security groups | ✅ | ✅ |
| EC2 + key pair | ✅ | ⚠️ see caveat below |
| RDS | ✅ | ❌ off (`create_rds = false`) |
| ALB | ✅ | ❌ off (`create_alb = false`) |
| Budget alert | ✅ | ❌ (not applicable) |
| Cost | Free Tier limits, 12 months | Free/paid LocalStack plan, see caveat |

## Important — read before you start

**LocalStack changed its pricing in 2026.** The old open-source Community Edition (anonymous, no signup, `docker pull` and go) was discontinued on **March 23, 2026**. The current free option is a "Free" plan that requires a LocalStack account and an auth token. Which AWS services are actually included in that free plan has shifted, and sources disagree on exactly where EC2 currently sits — RDS and ALB are confidently Pro/paid-tier features, which is why `create_rds` and `create_alb` default to `false` for the LocalStack path in this project.

**Before running anything against LocalStack:**
1. Sign up at https://app.localstack.cloud and get an auth token.
2. Check the current feature matrix yourself: https://docs.localstack.cloud/aws/capabilities/support/feature-coverage/ and https://docs.localstack.cloud/aws/licensing/ — this project's assumptions may be stale by the time you read this.
3. `export LOCALSTACK_AUTH_TOKEN="your-token-here"` before running `scripts/localstack-up.sh`.

**Before running anything against real AWS:**
1. Set `allowed_ssh_cidr` in `environments/aws.tfvars` to your own IP, not `0.0.0.0/0`.
2. Set `budget_alert_email` in `environments/aws.tfvars` — an alert nobody receives is not an alert.
3. Export a real database password: `export TF_VAR_db_password='something-strong'`. Never commit it.
4. Understand that the AWS Budget alert **notifies**, it does not **stop** spend. There is no "hard cap" API on AWS. Run `scripts/destroy.sh aws` when you're done for the day.

## Project structure

```
terraform-freetier-localstack/
├── versions.tf                  # Terraform + provider version constraints
├── .terraform-version           # tfenv pin
├── providers.tf                 # single AWS provider, toggled for LocalStack
├── variables.tf                 # every input, with defaults and doc strings
├── outputs.tf
├── vpc.tf                       # VPC, subnets, IGW, optional NAT, route tables
├── security_groups.tf           # ALB / EC2 / RDS security groups
├── keypair.tf                   # generates and saves an SSH key pair
├── ec2.tf                       # EC2 instance + Ubuntu AMI lookup
├── rds.tf                       # RDS MySQL (create_rds toggle)
├── alb.tf                       # ALB + target group + listener (create_alb toggle)
├── budget.tf                    # AWS Budget cost-guard (real AWS only)
├── backend.tf.example           # copy to backend.tf after bootstrapping
├── environments/
│   ├── aws.tfvars               # real AWS Free Tier settings
│   └── localstack.tfvars        # LocalStack settings (RDS/ALB off)
└── scripts/
    ├── bootstrap-backend.sh     # one-time: create the S3+DynamoDB backend
    ├── localstack-up.sh         # start LocalStack in Docker
    ├── deploy.sh                # terraform init/plan/apply wrapper
    └── destroy.sh                # terraform destroy wrapper, with a checklist
```

## Prerequisites

- Terraform (version pinned in `.terraform-version` — use `tfenv install` if you use `tfenv`)
- AWS CLI configured (`aws configure`) for the real-AWS path
- Docker, for the LocalStack path
- A LocalStack account + auth token (see the pricing note above) for the LocalStack path

## Usage — real AWS

```bash
# One-time: set up remote state
./scripts/bootstrap-backend.sh my-unique-bucket-name my-lock-table-name us-east-1
cp backend.tf.example backend.tf
# edit backend.tf with the bucket/table names printed above
terraform init

# Set required secrets
export TF_VAR_db_password='something-strong'

# Edit environments/aws.tfvars: allowed_ssh_cidr, budget_alert_email

./scripts/deploy.sh aws
terraform output

# When you're done for the session:
./scripts/destroy.sh aws
```

## Usage — LocalStack

```bash
export LOCALSTACK_AUTH_TOKEN="your-token-here"
./scripts/deploy.sh localstack
terraform output

./scripts/destroy.sh localstack
```

Local state is used for the LocalStack path (no S3 backend) since LocalStack's own state resets on container restart anyway, a remote backend buys nothing there.

## Cost safety checklist

- [ ] `allowed_ssh_cidr` is your IP, not the world
- [ ] `budget_alert_email` is set and you can actually receive that email
- [ ] `enable_nat_gateway` stays `false` unless you specifically need it (NAT Gateways are billed per hour + per GB, Free Tier does not cover them)
- [ ] You ran `./scripts/destroy.sh aws` at the end of the session
- [ ] You checked the AWS Billing console directly at least once, budget alerts are a notification, not a guarantee

## Status

This is an active learning project, not a finished, battle-tested module. No CI is wired up yet — correctness is checked with `terraform validate` / `terraform plan` and manual review. Treat the LocalStack service-coverage assumptions in this README as a starting point to verify, not a fact to trust blindly, since LocalStack's own packaging has changed more than once recently.
