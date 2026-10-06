#!/usr/bin/env bash
# =============================================================================
# cleanup-aws.sh - emergency "stop paying" script for terraform-freetier-localstack
#
# Removes everything this project may have left running in AWS, even if the
# Terraform state is lost or broken:
#
#   1. terraform destroy of envs/aws (the normal, clean way)
#   2. a sweep for billable leftovers tagged Project=<project>:
#      load balancers, RDS databases + snapshots, EC2 instances,
#      NAT gateways, Elastic IPs
#   3. optional (--include-bootstrap): the state bucket and the budget alert
#      (these cost ~$0.00/month, so normally you keep them)
#   4. removes the local LocalStack container, if any
#
# It then lists anything still tagged with the project. Leftover VPCs,
# subnets, security groups, key pairs and IAM roles are FREE - they are
# reported, not force-deleted.
#
# Usage:
#   aws sso login --profile tf-lab && export AWS_PROFILE=tf-lab
#   ./scripts/cleanup-aws.sh                       # destroy + sweep (asks first)
#   ./scripts/cleanup-aws.sh --dry-run             # only show what it would do
#   ./scripts/cleanup-aws.sh --include-bootstrap   # ...also bucket + budget
#
# Options:
#   --region <region>       default: $AWS_REGION, else us-east-1
#   --project <name>        default: tf-freetier-lab
#   --include-bootstrap     also delete the S3 state bucket and the budget
#   --dry-run               list what would be deleted, change nothing
#   --yes                   don't ask for confirmation (for automation)
#
# Exit code 0 = everything checked and cleaned; 1 = something failed, look
# at the [WARN] lines and check the AWS console.
# =============================================================================
set -euo pipefail

PROJECT="tf-freetier-lab"
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
INCLUDE_BOOTSTRAP=false
DRY_RUN=false
ASSUME_YES=false
FAILED=0

while [ $# -gt 0 ]; do
  case "$1" in
    --region) REGION="$2"; shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    --include-bootstrap) INCLUDE_BOOTSTRAP=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --yes|-y) ASSUME_YES=true; shift ;;
    -h|--help) sed -n '2,35p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1 (see --help)" >&2; exit 1 ;;
  esac
done

cd "$(dirname "$0")/.."
export AWS_PAGER=""   # never open a pager, works on AWS CLI v1 and v2

info() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*" >&2; }
step() { echo; echo "=== $* ==="; }

# aws CLI with the region fixed.
awsr() { aws --region "${REGION}" "$@"; }

# query VAR <aws args...>
# Runs a read-only AWS call and stores the result (one item per line) in VAR.
# If the call FAILS, it warns and marks the run as failed - so a permissions
# or network error is never mistaken for "nothing found".
query() {
  local __var="$1" __out
  shift
  if __out="$(awsr "$@" --output text 2>&1)"; then
    __out="$(printf '%s\n' "${__out}" | tr '\t' '\n' | sed '/^$/d;/^None$/d')"
  else
    warn "Could not check ($1 $2): ${__out}"
    FAILED=1
    __out=""
  fi
  printf -v "${__var}" '%s' "${__out}"
}

# act "description" <command...>
# Runs a deleting command (or only prints it in --dry-run). A failure is
# reported and counted, but the script carries on with the rest.
act() {
  local desc="$1"
  shift
  if [ "${DRY_RUN}" = true ]; then
    echo "  (dry-run) ${desc}"
    return 0
  fi
  info "${desc}"
  if ! "$@" >/dev/null; then
    warn "FAILED: ${desc}"
    FAILED=1
  fi
}

# -----------------------------------------------------------------------------
# 0. Pre-flight: who are we?
# -----------------------------------------------------------------------------
command -v aws >/dev/null 2>&1 || { echo "[ERROR] AWS CLI not found." >&2; exit 1; }

if ! IDENTITY="$(aws sts get-caller-identity --query '[Account,Arn]' --output text 2>&1)"; then
  echo "[ERROR] Not logged in to AWS: ${IDENTITY}" >&2
  echo "[ERROR] Run: aws sso login --profile tf-lab && export AWS_PROFILE=tf-lab" >&2
  exit 1
fi
ACCOUNT="$(printf '%s' "${IDENTITY}" | cut -f1)"
ARN="$(printf '%s' "${IDENTITY}" | cut -f2)"

step "Target"
info "Account : ${ACCOUNT}"
info "Identity: ${ARN}"
info "Region  : ${REGION}"
info "Project : ${PROJECT}"
if [ "${INCLUDE_BOOTSTRAP}" = true ]; then
  info "Bootstrap (state bucket + budget): WILL BE DELETED"
else
  info "Bootstrap (state bucket + budget): kept"
fi
[ "${DRY_RUN}" = true ] && info "DRY RUN - nothing will be changed"

# If the project's tfvars pin an account, refuse to clean a different one.
for f in envs/aws/terraform.tfvars bootstrap/terraform.tfvars; do
  if [ -f "$f" ]; then
    PINNED="$(sed -n 's/^[[:space:]]*aws_account_id[[:space:]]*=[[:space:]]*"\([0-9]*\)".*/\1/p' "$f" | head -1)"
    if [ -n "${PINNED}" ] && [ "${PINNED}" != "${ACCOUNT}" ]; then
      echo "[ERROR] Logged in to ${ACCOUNT}, but $f says ${PINNED}. Wrong AWS_PROFILE?" >&2
      exit 1
    fi
  fi
done

if [ "${ASSUME_YES}" != true ] && [ "${DRY_RUN}" != true ]; then
  echo
  read -r -p "Type the account ID (${ACCOUNT}) to delete this project's resources in it: " CONFIRM
  [ "${CONFIRM}" = "${ACCOUNT}" ] || { echo "Aborted. Nothing was changed."; exit 1; }
fi

# -----------------------------------------------------------------------------
# 1. The clean way: terraform destroy
# -----------------------------------------------------------------------------
step "1/4 terraform destroy (envs/aws)"
if ! command -v terraform >/dev/null 2>&1; then
  warn "terraform not found - skipping; the sweep below still runs."
elif [ ! -f envs/aws/backend.hcl ]; then
  info "envs/aws/backend.hcl not found - no remote state to destroy from; the sweep below still runs."
elif [ "${DRY_RUN}" = true ]; then
  echo "  (dry-run) terraform -chdir=envs/aws destroy"
else
  if terraform -chdir=envs/aws init -input=false -backend-config=backend.hcl >/dev/null \
    && terraform -chdir=envs/aws destroy -auto-approve -input=false -var "aws_account_id=${ACCOUNT}"; then
    info "terraform destroy finished."
  else
    warn "terraform destroy failed - continuing with the sweep."
  fi
fi

# -----------------------------------------------------------------------------
# 2. Sweep billable leftovers (works even with no or broken state)
#    Order matters: load balancer -> RDS -> EC2 -> NAT -> Elastic IP
# -----------------------------------------------------------------------------
step "2/4 Sweep billable leftovers tagged Project=${PROJECT}"
TAG_FILTER="Name=tag:Project,Values=${PROJECT}"

# --- Load balancers + target groups (ALB ~$0.02/h + public IPs) --------------
query LB_ARNS resourcegroupstaggingapi get-resources \
  --resource-type-filters elasticloadbalancing:loadbalancer \
  --tag-filters "Key=Project,Values=${PROJECT}" \
  --query 'ResourceTagMappingList[].ResourceARN'
for arn in ${LB_ARNS}; do
  act "Delete load balancer ${arn#*:loadbalancer/}" awsr elbv2 delete-load-balancer --load-balancer-arn "${arn}"
done
if [ -n "${LB_ARNS}" ] && [ "${DRY_RUN}" != true ]; then
  info "Waiting for load balancers to be deleted..."
  # shellcheck disable=SC2086
  awsr elbv2 wait load-balancers-deleted --load-balancer-arns ${LB_ARNS} || true
fi

query TG_ARNS resourcegroupstaggingapi get-resources \
  --resource-type-filters elasticloadbalancing:targetgroup \
  --tag-filters "Key=Project,Values=${PROJECT}" \
  --query 'ResourceTagMappingList[].ResourceARN'
for arn in ${TG_ARNS}; do
  act "Delete target group ${arn#*:targetgroup/}" awsr elbv2 delete-target-group --target-group-arn "${arn}"
done

# --- RDS (~$0.02/h + storage). Its Secrets Manager secret goes with it. -----
query DB_IDS rds describe-db-instances \
  --query "DBInstances[?contains(DBInstanceIdentifier, '${PROJECT}') && DBInstanceStatus!='deleting'].DBInstanceIdentifier"
for db in ${DB_IDS}; do
  act "Disable deletion protection on ${db}" awsr rds modify-db-instance \
    --db-instance-identifier "${db}" --no-deletion-protection --apply-immediately
  act "Delete RDS instance ${db} (no final snapshot)" awsr rds delete-db-instance \
    --db-instance-identifier "${db}" --skip-final-snapshot --delete-automated-backups
done

# Manual snapshots are billed too.
query SNAP_IDS rds describe-db-snapshots --snapshot-type manual \
  --query "DBSnapshots[?contains(DBInstanceIdentifier, '${PROJECT}')].DBSnapshotIdentifier"
for snap in ${SNAP_IDS}; do
  act "Delete RDS snapshot ${snap}" awsr rds delete-db-snapshot --db-snapshot-identifier "${snap}"
done

# --- EC2 instances (~$0.01/h + public IP + disk) -----------------------------
query INSTANCE_IDS ec2 describe-instances --filters "${TAG_FILTER}" \
  "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].InstanceId'
if [ -n "${INSTANCE_IDS}" ]; then
  # shellcheck disable=SC2086
  act "Terminate EC2 instances: $(echo "${INSTANCE_IDS}" | xargs)" awsr ec2 terminate-instances --instance-ids ${INSTANCE_IDS}
fi

# --- NAT gateways (~$0.045/h - the most expensive thing here) ---------------
query NAT_IDS ec2 describe-nat-gateways --filter "${TAG_FILTER}" \
  "Name=state,Values=pending,available" \
  --query 'NatGateways[].NatGatewayId'
for nat in ${NAT_IDS}; do
  act "Delete NAT gateway ${nat}" awsr ec2 delete-nat-gateway --nat-gateway-id "${nat}"
done

# Wait for what holds Elastic IPs before releasing them.
if [ "${DRY_RUN}" != true ]; then
  if [ -n "${INSTANCE_IDS}" ]; then
    info "Waiting for instances to terminate..."
    # shellcheck disable=SC2086
    awsr ec2 wait instance-terminated --instance-ids ${INSTANCE_IDS} || true
  fi
  if [ -n "${NAT_IDS}" ]; then
    info "Waiting for NAT gateways to be deleted (can take a few minutes)..."
    # shellcheck disable=SC2086
    awsr ec2 wait nat-gateway-deleted --nat-gateway-ids ${NAT_IDS} 2>/dev/null || sleep 60
  fi
fi

# --- Elastic IPs (billed whenever allocated) ---------------------------------
query EIP_IDS ec2 describe-addresses --filters "${TAG_FILTER}" \
  --query 'Addresses[].AllocationId'
for eip in ${EIP_IDS}; do
  act "Release Elastic IP ${eip}" awsr ec2 release-address --allocation-id "${eip}"
done

if [ -z "${LB_ARNS}${TG_ARNS}${DB_IDS}${SNAP_IDS}${INSTANCE_IDS}${NAT_IDS}${EIP_IDS}" ]; then
  if [ "${FAILED}" -eq 0 ]; then
    info "No billable leftovers found."
  else
    warn "Nothing found, BUT some checks failed (see above) - this is not proof that nothing is running."
  fi
fi

# -----------------------------------------------------------------------------
# 3. Optional: bootstrap (state bucket + budget)
# -----------------------------------------------------------------------------
step "3/4 Bootstrap (state bucket + budget)"
BUCKET="${PROJECT}-tfstate-${ACCOUNT}-${REGION}"
BUDGET="${PROJECT}-monthly"

if [ "${INCLUDE_BOOTSTRAP}" != true ]; then
  info "Kept (costs ~\$0.00/month, and the budget keeps alerting). Use --include-bootstrap to remove."
else
  if aws budgets describe-budget --account-id "${ACCOUNT}" --budget-name "${BUDGET}" >/dev/null 2>&1; then
    act "Delete budget ${BUDGET}" aws budgets delete-budget --account-id "${ACCOUNT}" --budget-name "${BUDGET}"
  else
    info "Budget ${BUDGET} not found."
  fi

  if awsr s3api head-bucket --bucket "${BUCKET}" >/dev/null 2>&1; then
    if [ "${DRY_RUN}" = true ]; then
      echo "  (dry-run) Empty and delete bucket ${BUCKET}"
    else
      info "Emptying versioned bucket ${BUCKET} (all versions + delete markers)"
      TMP="$(mktemp)"
      trap 'rm -f "${TMP}"' EXIT
      for kind in Versions DeleteMarkers; do
        while true; do
          awsr s3api list-object-versions --bucket "${BUCKET}" --max-items 500 \
            --query "{Objects: ${kind}[].{Key: Key, VersionId: VersionId}, Quiet: \`true\`}" \
            --output json > "${TMP}"
          grep -q '"Key"' "${TMP}" || break
          awsr s3api delete-objects --bucket "${BUCKET}" --delete "file://${TMP}" >/dev/null
        done
      done
      act "Delete bucket ${BUCKET}" awsr s3api delete-bucket --bucket "${BUCKET}"
      rm -f bootstrap/terraform.tfstate bootstrap/terraform.tfstate.backup envs/aws/backend.hcl
    fi
  else
    info "Bucket ${BUCKET} not found."
  fi
fi

# -----------------------------------------------------------------------------
# 4. LocalStack (free, but tidy up)
# -----------------------------------------------------------------------------
step "4/4 LocalStack"
if command -v docker >/dev/null 2>&1 && docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q '^localstack$'; then
  act "Remove local LocalStack container" docker rm -f localstack
else
  info "No LocalStack container."
fi

# -----------------------------------------------------------------------------
# Report
# -----------------------------------------------------------------------------
step "Still tagged Project=${PROJECT} in ${REGION}"
query REMAINING resourcegroupstaggingapi get-resources \
  --tag-filters "Key=Project,Values=${PROJECT}" \
  --query 'ResourceTagMappingList[].ResourceARN'
if [ -z "${REMAINING}" ]; then
  info "Nothing left."
else
  while IFS= read -r item; do echo "  - ${item}"; done <<< "${REMAINING}"
  echo
  info "Things still shutting down (terminating instances, deleting DBs) disappear on their own."
  info "VPCs, subnets, security groups, route tables, key pairs and IAM roles are FREE."
  info "To remove them too: re-run terraform destroy, or delete the VPC in the console."
fi

echo
if [ "${DRY_RUN}" = true ]; then
  info "Dry run finished - nothing was changed. Run without --dry-run to delete."
  exit "${FAILED}"
fi
if [ "${FAILED}" -ne 0 ]; then
  warn "Some steps FAILED (see [WARN] above). Check EC2, RDS, Load Balancers and"
  warn "VPC > NAT gateways / Elastic IPs in the console (region ${REGION})."
  exit 1
fi
info "Done. Check the Billing console tomorrow - charges show up with a delay."