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

if [[ ! -f .env ]]; then
  TURN_REALM="${TURN_REALM:-relaysend.local}"
  TURN_USER="${TURN_USER:-relay}"
  if [[ -n "${TURN_PASSWORD:-}" ]]; then
    TURN_PASSWORD_VALUE="${TURN_PASSWORD}"
  elif command -v openssl >/dev/null 2>&1; then
    TURN_PASSWORD_VALUE="$(openssl rand -hex 18)"
  else
    TURN_PASSWORD_VALUE="$(head -c 24 /dev/urandom | base64 | tr -d '/+=' | head -c 32)"
  fi

  printf 'TURN_REALM=%s\nTURN_USER=%s\nTURN_PASSWORD=%s\n' \
    "$TURN_REALM" "$TURN_USER" "$TURN_PASSWORD_VALUE" > .env
  echo "Created .env with a generated TURN_PASSWORD."
fi

docker compose up -d --build
