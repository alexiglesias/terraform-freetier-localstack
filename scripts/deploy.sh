#!/usr/bin/env bash
# Deploys this project against either real AWS or LocalStack.
#
# Usage:
#   ./scripts/deploy.sh aws
#   ./scripts/deploy.sh localstack
set -euo pipefail

TARGET="${1:-}"

if [ "${TARGET}" != "aws" ] && [ "${TARGET}" != "localstack" ]; then
  echo "Usage: $0 <aws|localstack>" >&2
  exit 1
fi

cd "$(dirname "$0")/.."

if [ "${TARGET}" = "aws" ]; then
  if [ -z "${TF_VAR_db_password:-}" ]; then
    echo "[ERROR] TF_VAR_db_password is not set." >&2
    echo "[ERROR] export TF_VAR_db_password='something-strong' before deploying to AWS." >&2
    exit 1
  fi
  echo "[INFO] Deploying against REAL AWS. This can incur cost if you exceed"
  echo "[INFO] Free Tier limits or leave resources running. Double-check"
  echo "[INFO] environments/aws.tfvars (region, allowed_ssh_cidr, budget_alert_email)"
  echo "[INFO] before continuing."
  read -r -p "Type 'yes' to continue: " CONFIRM
  if [ "${CONFIRM}" != "yes" ]; then
    echo "Aborted."
    exit 1
  fi
  terraform init
  terraform plan -var-file=environments/aws.tfvars -out=tfplan
  terraform apply tfplan
else
  echo "[INFO] Deploying against LocalStack (http://localhost:4566)"
  ./scripts/localstack-up.sh
  terraform init
  terraform plan -var-file=environments/localstack.tfvars -out=tfplan
  terraform apply tfplan
fi

echo "[DONE] Apply complete. Run 'terraform output' to see the results."
