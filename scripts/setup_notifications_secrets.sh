#!/usr/bin/env bash
# Configure Resend Auth hook + OneSignal Edge secrets for Quillo.
# Usage:
#   export RESEND_API_KEY='re_...'
#   export ONESIGNAL_APP_ID='...'
#   export ONESIGNAL_REST_API_KEY='...'
#   ./scripts/setup_notifications_secrets.sh
#
# Optional:
#   export RESEND_FROM='Quillo <hello@quilloai.co.uk>'

set -euo pipefail
PROJECT_REF="${PROJECT_REF:-klvzgfheneyqrwfxtfyg}"
HOOK_URL="https://${PROJECT_REF}.supabase.co/functions/v1/send-welcome-email"

if [[ -z "${RESEND_API_KEY:-}" ]]; then
  echo "Missing RESEND_API_KEY (from https://resend.com/api-keys)"
  exit 1
fi

# Generate Supabase Send Email hook secret (standardwebhooks format).
HOOK_SECRET_RAW="$(openssl rand -base64 32 | tr -d '\n')"
HOOK_SECRET="v1,whsec_${HOOK_SECRET_RAW}"

echo "Setting Edge secrets..."
ARGS=(
  "RESEND_API_KEY=${RESEND_API_KEY}"
  "SEND_EMAIL_HOOK_SECRET=${HOOK_SECRET}"
  "RESEND_FROM=${RESEND_FROM:-Quillo <hello@quilloai.co.uk>}"
)
if [[ -n "${ONESIGNAL_APP_ID:-}" ]]; then
  ARGS+=("ONESIGNAL_APP_ID=${ONESIGNAL_APP_ID}")
fi
if [[ -n "${ONESIGNAL_REST_API_KEY:-}" ]]; then
  ARGS+=("ONESIGNAL_REST_API_KEY=${ONESIGNAL_REST_API_KEY}")
fi

npx supabase secrets set "${ARGS[@]}" --project-ref "$PROJECT_REF"

echo "Enabling Auth Send Email hook..."
TOKEN="$(
  python3 - <<'PY'
import os
for p in ('~/.supabase/access-token', '~/.config/supabase/access-token'):
  path = os.path.expanduser(p)
  if os.path.exists(path):
    print(open(path).read().strip())
    break
PY
)"
if [[ -z "$TOKEN" ]]; then
  echo "No Supabase access token found. Log in with: npx supabase login"
  exit 1
fi

python3 - <<PY
import json, urllib.request
token = """${TOKEN}"""
payload = {
  "hook_send_email_enabled": True,
  "hook_send_email_uri": "${HOOK_URL}",
  "hook_send_email_secrets": "${HOOK_SECRET}",
}
req = urllib.request.Request(
  "https://api.supabase.com/v1/projects/${PROJECT_REF}/config/auth",
  data=json.dumps(payload).encode(),
  method="PATCH",
  headers={
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json",
  },
)
with urllib.request.urlopen(req) as resp:
  data = json.load(resp)
print("hook_send_email_enabled =", data.get("hook_send_email_enabled"))
print("hook_send_email_uri =", data.get("hook_send_email_uri"))
PY

echo
echo "Done."
echo "- Auth hook → ${HOOK_URL}"
echo "- Resend from: ${RESEND_FROM:-Quillo <hello@quilloai.co.uk>}"
if [[ -n "${ONESIGNAL_APP_ID:-}" ]]; then
  echo "- OneSignal app id set (also pass --dart-define=ONESIGNAL_APP_ID=... in Flutter builds)"
else
  echo "- OneSignal skipped (set ONESIGNAL_APP_ID + ONESIGNAL_REST_API_KEY to enable pushes)"
fi
echo
echo "Test: create a new account and confirm the branded Resend email arrives."
