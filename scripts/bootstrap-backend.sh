#!/usr/bin/env bash
# Creates the S3 bucket and DynamoDB table used for Terraform remote state
# (see backend.tf.example). Run this ONCE, before the first `terraform init`
# that uses the S3 backend. Safe to re-run: every step checks for existence
# first.
#
# Usage: ./scripts/bootstrap-backend.sh [bucket-name] [table-name] [region]
set -euo pipefail

BUCKET_NAME="${1:-tf-freetier-lab-state-$(date +%s)}"
TABLE_NAME="${2:-tf-freetier-lab-lock}"
REGION="${3:-us-east-1}"

echo "[INFO] Bootstrapping Terraform backend"
echo "[INFO]   bucket: ${BUCKET_NAME}"
echo "[INFO]   table:  ${TABLE_NAME}"
echo "[INFO]   region: ${REGION}"

if aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
  echo "[INFO] Bucket ${BUCKET_NAME} already exists, skipping creation"
else
  echo "[INFO] Creating S3 bucket ${BUCKET_NAME}"
  if [ "${REGION}" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "${BUCKET_NAME}" --region "${REGION}"
  else
    aws s3api create-bucket --bucket "${BUCKET_NAME}" --region "${REGION}" \
      --create-bucket-configuration LocationConstraint="${REGION}"
  fi
  aws s3api put-bucket-versioning --bucket "${BUCKET_NAME}" \
    --versioning-configuration Status=Enabled
  aws s3api put-bucket-encryption --bucket "${BUCKET_NAME}" \
    --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
  aws s3api put-public-access-block --bucket "${BUCKET_NAME}" \
    --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
fi

if aws dynamodb describe-table --table-name "${TABLE_NAME}" --region "${REGION}" >/dev/null 2>&1; then
  echo "[INFO] DynamoDB table ${TABLE_NAME} already exists, skipping creation"
else
  echo "[INFO] Creating DynamoDB lock table ${TABLE_NAME}"
  aws dynamodb create-table \
    --table-name "${TABLE_NAME}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${REGION}"
  aws dynamodb wait table-exists --table-name "${TABLE_NAME}" --region "${REGION}"
fi

cat <<EOF

[DONE] Backend resources are ready.

Next steps:
  1. cp backend.tf.example backend.tf
  2. Edit backend.tf:
       bucket         = "${BUCKET_NAME}"
       dynamodb_table = "${TABLE_NAME}"
       region         = "${REGION}"
  3. terraform init   (it will offer to migrate local state to S3 - say yes)

Reminder: this bucket and table are cheap but not free forever if you keep
piling state files into them. Free Tier covers 5GB of S3 and DynamoDB's
pay-per-request mode is effectively free at this scale, but they are still
real AWS resources - they show up in scripts/destroy.sh's manual checklist,
not in `terraform destroy` itself (destroying your own state backend from
inside the thing it's the backend for is a bad idea).
EOF
