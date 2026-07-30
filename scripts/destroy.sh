#!/usr/bin/env bash
# Tears down everything Terraform created. Run this at the end of every
# session against real AWS — do not leave EC2/RDS/ALB running "just in case".
#
# Usage:
#   ./scripts/destroy.sh aws
#   ./scripts/destroy.sh localstack
set -euo pipefail

TARGET="${1:-}"

if [ "${TARGET}" != "aws" ] && [ "${TARGET}" != "localstack" ]; then
  echo "Usage: $0 <aws|localstack>" >&2
  exit 1
fi

cd "$(dirname "$0")/.."

VAR_FILE="environments/${TARGET}.tfvars"

if [ "${TARGET}" = "aws" ] && [ -z "${TF_VAR_db_password:-}" ]; then
  echo "[ERROR] TF_VAR_db_password is not set (Terraform needs it to compute the plan, even for destroy)." >&2
  exit 1
fi

echo "[INFO] About to DESTROY every resource this project manages against: ${TARGET}"
terraform plan -destroy -var-file="${VAR_FILE}"

read -r -p "Type 'destroy' to confirm: " CONFIRM
if [ "${CONFIRM}" != "destroy" ]; then
  echo "Aborted. Nothing was destroyed."
  exit 1
fi

terraform destroy -var-file="${VAR_FILE}" -auto-approve

if [ "${TARGET}" = "aws" ]; then
  cat <<'EOF'

[DONE] terraform destroy complete.

terraform destroy does NOT remove:
  - The S3 bucket / DynamoDB table used as the remote state backend
    (see backend.tf.example and scripts/bootstrap-backend.sh) - that's
    deliberate, destroying your own state backend from inside the run
    that depends on it is asking for trouble. Remove those manually via
    the AWS CLI/console once you're fully done with the project.
  - The AWS Budgets alert (aws_budgets_budget) is destroyed along with
    everything else, but budget ALERTS ARE NOT REFUNDS - go check the
    AWS Billing console directly and confirm actual spend, don't just
    trust that destroy = zero cost.
EOF
fi
