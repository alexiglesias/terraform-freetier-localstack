#!/usr/bin/env bash
# Starts LocalStack in Docker and waits until its health endpoint reports
# ready. Requires Docker to be running.
#
# IMPORTANT — read before running:
# LocalStack discontinued its open-source Community Edition on March 23,
# 2026. The current free tier is a "Free" plan that requires a (free)
# LocalStack account and an auth token — it is no longer anonymous,
# no-signup Docker pull it used to be. Sign up at https://app.localstack.cloud
# and export your token before running this script:
#
#   export LOCALSTACK_AUTH_TOKEN="your-token-here"
#
# Which AWS services are included in the free plan has also changed and,
# per LocalStack's own changelog, keeps changing — do not trust the
# SERVICES list below blindly. Check https://docs.localstack.cloud/aws/licensing/
# and https://docs.localstack.cloud/aws/capabilities/support/feature-coverage/
# for the current state before relying on EC2, IAM, or anything beyond core
# storage/messaging services (S3, DynamoDB, SQS, SNS) being free. This
# project's create_rds / create_alb toggles already assume RDS and ALB are
# NOT in the free plan; EC2's status has been reported inconsistently across
# sources as of this writing, so verify it yourself before assuming
# ec2.tf will work here without a paid plan.
set -euo pipefail

echo "[INFO] Starting LocalStack..."

if ! command -v docker >/dev/null 2>&1; then
  echo "[ERROR] Docker is required to run LocalStack. Install Docker first." >&2
  exit 1
fi

if [ -z "${LOCALSTACK_AUTH_TOKEN:-}" ]; then
  echo "[WARN] LOCALSTACK_AUTH_TOKEN is not set. As of the March 2026 pricing"
  echo "[WARN] change this will likely fail or fall back to a very limited"
  echo "[WARN] anonymous mode. Sign up at https://app.localstack.cloud and:"
  echo "[WARN]   export LOCALSTACK_AUTH_TOKEN=\"your-token-here\""
fi

if docker ps --format '{{.Names}}' | grep -q '^localstack$'; then
  echo "[INFO] LocalStack container already running, skipping start"
else
  docker run -d \
    --name localstack \
    -p 4566:4566 \
    -e LOCALSTACK_AUTH_TOKEN="${LOCALSTACK_AUTH_TOKEN:-}" \
    -e SERVICES=ec2,s3,iam,sts,dynamodb,cloudwatch \
    -e DEBUG=0 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    localstack/localstack:latest
fi

echo -n "[INFO] Waiting for LocalStack to be ready"
for _ in $(seq 1 30); do
  if curl -fs http://localhost:4566/_localstack/health >/dev/null 2>&1; then
    echo
    echo "[DONE] LocalStack is up at http://localhost:4566"
    exit 0
  fi
  echo -n "."
  sleep 2
done

echo
echo "[ERROR] LocalStack did not become healthy in time. Check: docker logs localstack" >&2
exit 1
