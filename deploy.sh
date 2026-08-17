#!/usr/bin/env bash
set -euo pipefail

RELAYSEND_BRANCH="${RELAYSEND_BRANCH:-main}"
RELAYSEND_DEPLOY_DIR="${RELAYSEND_DEPLOY_DIR:-relaysend-server}"
RAW_BASE="https://raw.githubusercontent.com/Steve0723/relaysend/${RELAYSEND_BRANCH}"

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required." >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required." >&2
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "docker compose plugin is required." >&2
  exit 1
fi

mkdir -p "${RELAYSEND_DEPLOY_DIR}"
cd "${RELAYSEND_DEPLOY_DIR}"

curl -fsSL "${RAW_BASE}/Dockerfile" -o Dockerfile
curl -fsSL "${RAW_BASE}/docker-compose.yml" -o docker-compose.yml
curl -fsSL "${RAW_BASE}/relay.patch" -o relay.patch

docker compose up -d --build
