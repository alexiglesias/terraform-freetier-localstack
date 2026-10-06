#!/usr/bin/env bash
# =============================================================================
# tf.sh - one safe entry point for every Terraform action in this repo.
#
# Usage:
#   scripts/tf.sh <localstack|aws> <plan|apply|destroy|output> [--yes]
#
#   plan     show what would change. Changes NOTHING - free, even on AWS.
#   apply    plan -> show summary -> ask -> apply exactly that plan
#   destroy  plan -destroy -> ask -> apply exactly that plan
#   output   print the environment's outputs
#
#   --yes    don't ask (also implied when CI=true) - for pipelines only
#
# Safety built in:
#   - you confirm AFTER seeing the plan, and Terraform applies the saved plan
#     file, so what runs is exactly what you approved
#   - aws: checks you are logged in, and to the account pinned in
#     envs/aws/terraform.tfvars, before touching anything
#   - aws: shows the running cost and reminds you to destroy
# =============================================================================
set -euo pipefail

usage() {
  sed -n '5,13p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
}

TARGET="${1:-}"
ACTION="${2:-}"
AUTO_APPROVE=false
[ "${CI:-}" = "true" ] && AUTO_APPROVE=true
[ "${3:-}" = "--yes" ] && AUTO_APPROVE=true

case "${TARGET}" in localstack|aws) ;; *) usage ;; esac
case "${ACTION}" in plan|apply|destroy|output) ;; *) usage ;; esac

cd "$(dirname "$0")/.."
ENV_DIR="envs/${TARGET}"
INIT_ARGS=()

info() { echo "[INFO] $*"; }
die()  { echo "[ERROR] $*" >&2; exit 1; }
tf()   { terraform -chdir="${ENV_DIR}" "$@"; }

# Ask the user to type a word; skipped with --yes / CI=true.
confirm() {
  local word="$1" prompt="$2" answer
  if [ "${AUTO_APPROVE}" = true ]; then
    info "Auto-approved (--yes / CI)."
    return 0
  fi
  read -r -p "${prompt} Type '${word}' to continue: " answer
  [ "${answer}" = "${word}" ] || { echo "Aborted. Nothing was changed."; exit 1; }
}

# -----------------------------------------------------------------------------
# Pre-flight checks per target
# -----------------------------------------------------------------------------
preflight_aws() {
  [ -f "${ENV_DIR}/terraform.tfvars" ] \
    || die "${ENV_DIR}/terraform.tfvars not found: cp ${ENV_DIR}/terraform.tfvars.example ${ENV_DIR}/terraform.tfvars"
  [ -f "${ENV_DIR}/backend.hcl" ] \
    || die "${ENV_DIR}/backend.hcl not found - run the bootstrap first (terraform -chdir=bootstrap apply)."
  command -v aws >/dev/null 2>&1 || die "AWS CLI not found."

  local identity account arn pinned
  if ! identity="$(aws sts get-caller-identity --query '[Account,Arn]' --output text 2>&1)"; then
    die "Not logged in to AWS (${identity}). Run: aws sso login --profile tf-lab && export AWS_PROFILE=tf-lab"
  fi
  account="$(printf '%s' "${identity}" | cut -f1)"
  arn="$(printf '%s' "${identity}" | cut -f2)"
  pinned="$(sed -n 's/^[[:space:]]*aws_account_id[[:space:]]*=[[:space:]]*"\([0-9]*\)".*/\1/p' "${ENV_DIR}/terraform.tfvars" | head -1)"

  [ -n "${pinned}" ] || die "aws_account_id is not set in ${ENV_DIR}/terraform.tfvars."
  [ "${account}" = "${pinned}" ] \
    || die "Logged in to account ${account}, but terraform.tfvars pins ${pinned}. Wrong AWS_PROFILE?"

  info "AWS account ${account} as ${arn}"
  INIT_ARGS=(-backend-config=backend.hcl)
}

preflight_localstack() {
  local endpoint="${LOCALSTACK_ENDPOINT:-http://localhost:4566}"
  if curl -fs "${endpoint}/_localstack/health" >/dev/null 2>&1; then
    info "LocalStack already running at ${endpoint}"
  else
    ./scripts/localstack-up.sh
  fi
}

# terraform init, quiet unless it fails.
tf_init() {
  local log
  if ! log="$(tf init -input=false ${INIT_ARGS[@]+"${INIT_ARGS[@]}"} 2>&1)"; then
    echo "${log}" >&2
    die "terraform init failed."
  fi
}

# Run a plan into a file. Sets PLAN_RC: 0 = no changes, 2 = changes.
run_plan() {
  local planfile="$1"
  shift
  set +e
  tf plan -input=false -detailed-exitcode -out="${planfile}" "$@"
  PLAN_RC=$?
  set -e
  [ "${PLAN_RC}" -ne 1 ] || die "terraform plan failed."
}

cost_warning() {
  [ "${TARGET}" = "aws" ] || return 0
  echo
  echo "  REAL AWS: EC2 + RDS + ALB + public IPs cost roughly \$0.07/hour (~\$1.60/day)"
  echo "  while they exist. Destroy when you are done:  make destroy ENV=aws"
  echo
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
command -v terraform >/dev/null 2>&1 || die "terraform not found."

if [ "${ACTION}" = "output" ]; then
  [ "${TARGET}" = "aws" ] && [ -f "${ENV_DIR}/backend.hcl" ] && INIT_ARGS=(-backend-config=backend.hcl)
  tf_init
  tf output
  exit 0
fi

"preflight_${TARGET}"
tf_init

case "${ACTION}" in
  plan)
    run_plan tfplan
    rm -f "${ENV_DIR}/tfplan"
    if [ "${PLAN_RC}" -eq 0 ]; then
      info "No changes."
    else
      info "Plan only - nothing was changed."
    fi
    ;;

  apply)
    run_plan tfplan
    if [ "${PLAN_RC}" -eq 0 ]; then
      rm -f "${ENV_DIR}/tfplan"
      info "No changes - infrastructure already matches the code."
      exit 0
    fi
    cost_warning
    confirm "yes" "Apply the plan above to ${TARGET}?"
    tf apply -input=false tfplan
    rm -f "${ENV_DIR}/tfplan"
    cost_warning
    ;;

  destroy)
    run_plan destroy.tfplan -destroy
    if [ "${PLAN_RC}" -eq 0 ]; then
      rm -f "${ENV_DIR}/destroy.tfplan"
      info "Nothing to destroy."
      exit 0
    fi
    confirm "destroy" "DESTROY everything listed above in ${TARGET}?"
    tf apply -input=false destroy.tfplan
    rm -f "${ENV_DIR}/destroy.tfplan"
    if [ "${TARGET}" = "aws" ]; then
      info "Done. bootstrap/ (state bucket + budget) is kept on purpose - it costs ~\$0."
      info "Check the Billing console tomorrow: charges show up with a delay."
    fi
    ;;
esac
