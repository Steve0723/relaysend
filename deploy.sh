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

random_secret() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 18
  else
    head -c 24 /dev/urandom | base64 | tr -d '/+=' | head -c 32
  fi
}

if [[ ! -f .env ]]; then
  TURN_REALM="${TURN_REALM:-relaysend.local}"
  TURN_USER="${TURN_USER:-relay}"
  if [[ -n "${TURN_PASSWORD:-}" ]]; then
    TURN_PASSWORD_VALUE="${TURN_PASSWORD}"
  else
    TURN_PASSWORD_VALUE="$(random_secret)"
  fi

  SHARE_AUTH_USERNAME_VALUE="${SHARE_AUTH_USERNAME:-admin}"
  SHARE_AUTH_PASSWORD_VALUE="${SHARE_AUTH_PASSWORD:-$(random_secret)}"

  printf 'TURN_REALM=%s\nTURN_USER=%s\nTURN_PASSWORD=%s\nSHARE_AUTH_USERNAME=%s\nSHARE_AUTH_PASSWORD=%s\n' \
    "$TURN_REALM" "$TURN_USER" "$TURN_PASSWORD_VALUE" \
    "$SHARE_AUTH_USERNAME_VALUE" "$SHARE_AUTH_PASSWORD_VALUE" > .env
  echo "Created .env with a generated TURN_PASSWORD."
  echo "Temporary share login: ${SHARE_AUTH_USERNAME_VALUE} (see ${PWD}/.env for password)"
elif ! grep -Eq '^SHARE_AUTH_PASSWORD=' .env; then
  SHARE_AUTH_USERNAME_VALUE="${SHARE_AUTH_USERNAME:-admin}"
  SHARE_AUTH_PASSWORD_VALUE="${SHARE_AUTH_PASSWORD:-$(random_secret)}"
  printf '\nSHARE_AUTH_USERNAME=%s\nSHARE_AUTH_PASSWORD=%s\n' \
    "$SHARE_AUTH_USERNAME_VALUE" "$SHARE_AUTH_PASSWORD_VALUE" >> .env
  echo "Added generated SHARE_AUTH_USERNAME/SHARE_AUTH_PASSWORD to .env."
  echo "Temporary share login: ${SHARE_AUTH_USERNAME_VALUE} (see ${PWD}/.env for password)"
fi

docker compose up -d --build
