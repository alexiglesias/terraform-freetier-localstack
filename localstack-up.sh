#!/usr/bin/env bash
# Starts LocalStack (docker-compose.yml) and waits until it is healthy.
#
# Needs Docker running and LOCALSTACK_AUTH_TOKEN set - either exported or in
# a .env file next to docker-compose.yml (see .env.example).
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v docker >/dev/null 2>&1; then
  echo "[ERROR] Docker is not installed." >&2
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  echo "[ERROR] Docker is installed but not running - start Docker Desktop first." >&2
  exit 1
fi

# Token from the environment, or from .env.
if [ -z "${LOCALSTACK_AUTH_TOKEN:-}" ] && ! grep -qE '^LOCALSTACK_AUTH_TOKEN=.+' .env 2>/dev/null; then
  echo "[ERROR] LOCALSTACK_AUTH_TOKEN is not set." >&2
  echo "[ERROR] Get a free token at https://app.localstack.cloud (Settings -> Auth Tokens)," >&2
  echo "[ERROR] then: cp .env.example .env  and paste it there." >&2
  exit 1
fi

echo "[INFO] Starting LocalStack..."
docker compose up -d --wait

echo "[DONE] LocalStack is healthy at http://localhost:4566"
curl -fs http://localhost:4566/_localstack/health \
  | tr ',' '\n' | grep -E '"(ec2|iam|sts)"' || true
