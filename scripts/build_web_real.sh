#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$ROOT_DIR/app"
ENV_FILE="${EIGHTUP_ENV_FILE:-}"

if [[ -z "$ENV_FILE" ]]; then
  if [[ -f "$ROOT_DIR/.env" ]]; then
    ENV_FILE="$ROOT_DIR/.env"
  elif [[ -f "$APP_DIR/.env" ]]; then
    ENV_FILE="$APP_DIR/.env"
  else
    echo "No .env file found. Set EIGHTUP_ENV_FILE or create .env in the repo root." >&2
    exit 1
  fi
fi

read_env_value() {
  local key="$1"
  local value

  value="$(
    sed -nE "s/^[[:space:]]*${key}[[:space:]]*[:=][[:space:]]*(.*)[[:space:]]*$/\\1/p" "$ENV_FILE" | tail -n 1
  )"
  value="${value%\"}"
  value="${value#\"}"
  value="${value%\'}"
  value="${value#\'}"
  printf '%s' "$value"
}

SUPABASE_URL_REAL_VALUE="$(read_env_value "SUPABASE_URL_REAL")"
SUPABASE_ANON_KEY_REAL_VALUE="$(read_env_value "SUPABASE_ANON_KEY_REAL")"
GOOGLE_WEB_CLIENT_ID_REAL_VALUE="$(read_env_value "GOOGLE_WEB_CLIENT_ID_REAL")"

if [[ -z "$GOOGLE_WEB_CLIENT_ID_REAL_VALUE" ]]; then
  GOOGLE_WEB_CLIENT_ID_REAL_VALUE="$(read_env_value "GOOGLE_WEB_CLIENT_ID")"
fi

if [[ -z "$SUPABASE_URL_REAL_VALUE" || -z "$SUPABASE_ANON_KEY_REAL_VALUE" ]]; then
  echo "Missing real Supabase values in $ENV_FILE" >&2
  exit 1
fi

cd "$APP_DIR"

exec flutter build web \
  --release \
  --dart-define=APP_ENV=real \
  --dart-define=SUPABASE_URL_REAL="$SUPABASE_URL_REAL_VALUE" \
  --dart-define=SUPABASE_ANON_KEY_REAL="$SUPABASE_ANON_KEY_REAL_VALUE" \
  --dart-define=GOOGLE_WEB_CLIENT_ID_REAL="$GOOGLE_WEB_CLIENT_ID_REAL_VALUE" \
  "$@"
