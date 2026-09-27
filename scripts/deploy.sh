#!/usr/bin/env bash
# Deploys one environment: envs/aws (real AWS) or envs/localstack.
# Each environment is its own Terraform root with its own state.
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
ENV_DIR="envs/${TARGET}"

if [ "${TARGET}" = "aws" ]; then
  if [ ! -f "${ENV_DIR}/terraform.tfvars" ]; then
    echo "[ERROR] ${ENV_DIR}/terraform.tfvars not found." >&2
    echo "[ERROR] cp ${ENV_DIR}/terraform.tfvars.example ${ENV_DIR}/terraform.tfvars and fill it in." >&2
    exit 1
  fi
  echo "[INFO] Deploying against REAL AWS. This can incur cost."
  read -r -p "Type 'yes' to continue: " CONFIRM
  if [ "${CONFIRM}" != "yes" ]; then
    echo "Aborted."
    exit 1
  fi
else
  echo "[INFO] Deploying against LocalStack (http://localhost:4566)"
  ./scripts/localstack-up.sh
fi

terraform -chdir="${ENV_DIR}" init
terraform -chdir="${ENV_DIR}" plan -out=tfplan
terraform -chdir="${ENV_DIR}" apply tfplan

echo "[DONE] Apply complete. Run 'terraform -chdir=${ENV_DIR} output' to see the results."
