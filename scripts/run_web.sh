#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$ROOT_DIR/app"
ENV_FILE="${EIGHTUP_ENV_FILE:-}"
APP_ENV="${1:-dev}"

if [[ "$APP_ENV" == "dev" || "$APP_ENV" == "real" ]]; then
  shift || true
else
  APP_ENV="dev"
fi

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

if [[ "$APP_ENV" == "real" ]]; then
  SUPABASE_URL_VALUE="$(read_env_value "SUPABASE_URL_REAL")"
  SUPABASE_ANON_KEY_VALUE="$(read_env_value "SUPABASE_ANON_KEY_REAL")"
  GOOGLE_WEB_CLIENT_ID_VALUE="$(read_env_value "GOOGLE_WEB_CLIENT_ID_REAL")"
  if [[ -z "$GOOGLE_WEB_CLIENT_ID_VALUE" ]]; then
    GOOGLE_WEB_CLIENT_ID_VALUE="$(read_env_value "GOOGLE_WEB_CLIENT_ID")"
  fi
  URL_DEFINE_KEY="SUPABASE_URL_REAL"
  ANON_DEFINE_KEY="SUPABASE_ANON_KEY_REAL"
  GOOGLE_DEFINE_KEY="GOOGLE_WEB_CLIENT_ID_REAL"
else
  SUPABASE_URL_VALUE="$(read_env_value "SUPABASE_URL_DEV")"
  SUPABASE_ANON_KEY_VALUE="$(read_env_value "SUPABASE_ANON_KEY_DEV")"
  GOOGLE_WEB_CLIENT_ID_VALUE="$(read_env_value "GOOGLE_WEB_CLIENT_ID_DEV")"
  if [[ -z "$GOOGLE_WEB_CLIENT_ID_VALUE" ]]; then
    GOOGLE_WEB_CLIENT_ID_VALUE="$(read_env_value "GOOGLE_WEB_CLIENT_ID")"
  fi

  if [[ -z "$SUPABASE_URL_VALUE" ]]; then
    SUPABASE_URL_VALUE="$(read_env_value "SUPABASE_URL")"
  fi
  if [[ -z "$SUPABASE_ANON_KEY_VALUE" ]]; then
    SUPABASE_ANON_KEY_VALUE="$(read_env_value "SUPABASE_ANON_KEY")"
  fi

  URL_DEFINE_KEY="SUPABASE_URL_DEV"
  ANON_DEFINE_KEY="SUPABASE_ANON_KEY_DEV"
  GOOGLE_DEFINE_KEY="GOOGLE_WEB_CLIENT_ID_DEV"
fi

if [[ -z "$SUPABASE_URL_VALUE" || -z "$SUPABASE_ANON_KEY_VALUE" ]]; then
  echo "Missing $APP_ENV Supabase values in $ENV_FILE" >&2
  exit 1
fi

cd "$APP_DIR"

exec flutter run -d chrome \
  --dart-define=APP_ENV="$APP_ENV" \
  --dart-define="${URL_DEFINE_KEY}=${SUPABASE_URL_VALUE}" \
  --dart-define="${ANON_DEFINE_KEY}=${SUPABASE_ANON_KEY_VALUE}" \
  --dart-define="${GOOGLE_DEFINE_KEY}=${GOOGLE_WEB_CLIENT_ID_VALUE}" \
  "$@"
