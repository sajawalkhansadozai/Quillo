#!/usr/bin/env bash
# Push recipe API keys from .env to Supabase Edge Function secrets.
# Usage: cp .env.example .env  # fill in values, then:
#        ./scripts/set_edge_secrets.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE"
  echo "Copy .env.example to .env and fill in your API keys first."
  exit 1
fi

# shellcheck disable=SC1090
set -a
source "$ENV_FILE"
set +a

export SUPABASE_ACCESS_TOKEN="${SUPABASE_ACCESS_TOKEN:-$(cat "$HOME/.supabase/access-token" 2>/dev/null || true)}"

if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
  echo "Not logged in. Run: make supabase-login"
  exit 1
fi

ARGS=()

add_secret() {
  local name="$1"
  local value="${!name:-}"
  if [[ -n "$value" ]]; then
    ARGS+=("${name}=${value}")
    echo "  + $name"
  else
    echo "  - $name (skipped — empty in .env)"
  fi
}

echo "Setting Supabase Edge Function secrets from $ENV_FILE:"
add_secret RECIPE_SEARCH_PROVIDER
add_secret SPOONACULAR_API_KEY
add_secret EDAMAM_APP_ID
add_secret EDAMAM_APP_KEY
add_secret BIGOVEN_API_KEY
add_secret BIGOVEN_USER_EMAIL
add_secret BIGOVEN_USER_PASSWORD
add_secret SEED_USER_ID
add_secret ANTHROPIC_API_KEY
add_secret GEMINI_API_KEY
add_secret GEMINI_IMAGE_MODEL
add_secret GEMINI_IMAGE_MAX_PER_SEARCH

if [[ ${#ARGS[@]} -eq 0 ]]; then
  echo "No secrets to set — fill in .env first."
  exit 1
fi

cd "$ROOT"
npx --yes supabase@latest secrets set "${ARGS[@]}"
echo "Done. Verify with: npx supabase@latest secrets list"
