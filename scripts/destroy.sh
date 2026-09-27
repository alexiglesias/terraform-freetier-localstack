#!/usr/bin/env bash
# Tears down one environment. Run this at the end of every session against
# real AWS - do not leave EC2/RDS/ALB running "just in case".
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
ENV_DIR="envs/${TARGET}"

INIT_ARGS=()
if [ "${TARGET}" = "aws" ]; then
  INIT_ARGS=(-backend-config=backend.hcl)
fi
terraform -chdir="${ENV_DIR}" init ${INIT_ARGS[@]+"${INIT_ARGS[@]}"}

echo "[INFO] About to DESTROY every resource in ${ENV_DIR}"
terraform -chdir="${ENV_DIR}" plan -destroy

read -r -p "Type 'destroy' to confirm: " CONFIRM
if [ "${CONFIRM}" != "destroy" ]; then
  echo "Aborted. Nothing was destroyed."
  exit 1
fi

terraform -chdir="${ENV_DIR}" destroy -auto-approve

if [ "${TARGET}" = "aws" ]; then
  cat <<'MSG'

[DONE] terraform destroy complete.

Not removed (on purpose): bootstrap/ - the state bucket and the budget
alert. They cost ~nothing and the budget keeps watching for leftovers.
Check the AWS Billing console to confirm spend.
MSG
fi
