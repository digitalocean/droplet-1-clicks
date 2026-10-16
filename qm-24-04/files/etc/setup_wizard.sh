#!/bin/bash
# QM first-login setup wizard — collects the admin account, a model
# provider (DigitalOcean Serverless Inference, Anthropic, or OpenAI — or
# auto-detected from /root/.digitalocean_genai_credentials if DigitalOcean's
# own GenAI automation dropped one, see env-lib.sh), and a sandbox backend
# key (DigitalOcean Managed Agents or e2b), then brings the stack up.

set -euo pipefail

# shellcheck source=/srv/qm/env-lib.sh
source /srv/qm/env-lib.sh

remove_first_login_hook() {
  if [ -f /root/.bashrc ]; then
    sed -i '/chmod +x \/etc\/setup_wizard\.sh/d' /root/.bashrc
    sed -i '/\/etc\/setup_wizard\.sh/d' /root/.bashrc
  fi
}

myip="$(droplet_ip)"

if ! env_is_placeholder AUTH_PASSWORD_USERS && [ "${1:-}" != "--force" ]; then
  echo ""
  echo "QM is already configured for $(read_env_val AUTH_ALLOWED_EMAILS)."
  echo "Dashboard: https://${myip}"
  echo "Re-run with --force to reconfigure: /etc/setup_wizard.sh --force"
  remove_first_login_hook
  exit 0
fi

cat <<EOF

========================================================================
  QM first-login setup
========================================================================

This droplet needs three things it can't generate itself:
  1. Your admin email + a password to sign in with (no email/SSO is set
     up on this droplet — see README.md to add one later).
  2. One model provider — DigitalOcean Serverless Inference, Anthropic,
     or OpenAI, your choice.
  3. A sandbox backend for agent turns to run in — DigitalOcean Managed
     Agents (one DO personal access token, nothing else to set up), or e2b.

Press Ctrl+C any time and re-run this wizard later: /etc/setup_wizard.sh
EOF

read -rp "Admin email: " ADMIN_EMAIL
until [[ "$ADMIN_EMAIL" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]; do
  read -rp "That doesn't look like an email — try again: " ADMIN_EMAIL
done

old_histfile="${HISTFILE-}"
unset HISTFILE
while true; do
  read -rsp "Admin password (min 12 characters): " ADMIN_PASSWORD
  echo ""
  if [ "${#ADMIN_PASSWORD}" -lt 12 ]; then
    echo "Too short — try again."
    continue
  fi
  read -rsp "Confirm password: " CONFIRM
  echo ""
  [ "$ADMIN_PASSWORD" = "$CONFIRM" ] && break
  echo "Passwords didn't match — try again."
done

echo ""
ANTHROPIC_API_KEY=""
OPENAI_API_KEY=""
DO_SERVERLESS_INFERENCE_API_KEY=""
PI_MODEL=""

# DigitalOcean's own GenAI automation may have dropped Serverless Inference
# credentials on this droplet before first login — when present, it always
# wins and the model-provider question is skipped entirely.
if detect_do_genai_credentials; then
  echo "Detected DigitalOcean Serverless Inference credentials at ${DO_GENAI_CREDENTIALS_FILE} (model: ${DO_GENAI_MODEL}) — skipping the model-provider question."
  MODEL_CHOICE=do-inference
  DO_INFERENCE_MODEL_ID="$DO_GENAI_MODEL"
  DO_INFERENCE_MODEL_NAME="$DO_GENAI_MODEL"
  DO_INFERENCE_CONTEXT_WINDOW="$DO_GENERIC_CONTEXT_WINDOW"
  DO_INFERENCE_MAX_TOKENS="$DO_GENERIC_MAX_TOKENS"
  DO_SERVERLESS_INFERENCE_API_KEY="$DO_GENAI_KEY"
else
  echo "Model provider:"
  echo "  1) DigitalOcean Serverless Inference (default) — https://cloud.digitalocean.com/model-studio/manage-keys"
  echo "     (default model: deepseek-v4.1-flash; needs a DO Serverless Inference key, not a droplet API token)"
  echo "  2) Anthropic                      — https://console.anthropic.com/settings/keys"
  echo "  3) OpenAI                         — https://platform.openai.com/api-keys"
  read -rp "Selection [1/2/3, Enter for DigitalOcean Serverless Inference]: " PROVIDER_SEL
  case "$PROVIDER_SEL" in
    2) MODEL_CHOICE=anthropic ;;
    3) MODEL_CHOICE=openai ;;
    *) MODEL_CHOICE=do-inference ;;
  esac
fi

# MODEL_PROVIDER is the real QM env var written to .env — blank for the DO
# path (core runs "modelless" at the provider level, a supported upstream
# configuration; see env.template). MODEL_CHOICE above is this script's own
# branch selector only, never written anywhere.
case "$MODEL_CHOICE" in
  openai)
    MODEL_PROVIDER=openai
    read -rsp "OpenAI API key: " OPENAI_API_KEY
    echo ""
    ;;
  do-inference)
    MODEL_PROVIDER=""
    PI_MODEL="$DO_INFERENCE_MODEL_ID"
    if [ -z "$DO_SERVERLESS_INFERENCE_API_KEY" ]; then
      read -rsp "DigitalOcean Serverless Inference key: " DO_SERVERLESS_INFERENCE_API_KEY
      echo ""
    fi
    # Confirmed live on a real deployment: QM's own "is a model provider
    # configured" check (portal's hard redirect to /admin/onboarding,
    # src/api/routes/surface.ts's modelProviderConfigured) only ever looks at
    # the 3 built-in provider credential slots — it has no awareness of
    # custom model providers at all, even though the custom-provider model
    # itself resolves and answers chat turns correctly. Without this, every
    # admin login redirects to onboarding with no way to dismiss it (the
    # onboarding page's own "configure key" save button 404s for a non
    # built-in provider id). Setting OPENAI_API_KEY to the same key is a
    # bystander credential purely to satisfy that check — it doesn't change
    # which model actually answers (PI_MODEL/the custom provider registration
    # govern that). Side effect: built-in OpenAI-branded models become
    # selectable in the model picker and would fail if manually chosen,
    # since this isn't a real OpenAI key.
    OPENAI_API_KEY="$DO_SERVERLESS_INFERENCE_API_KEY"
    ;;
  *)
    MODEL_PROVIDER=anthropic
    read -rsp "Anthropic API key: " ANTHROPIC_API_KEY
    echo ""
    ;;
esac
echo ""

# DigitalOcean's own internal automation may have injected a Managed
# Agents PAT (same credentials file as the model-provider automation
# above, a separate field) — when present, it always wins and the
# sandbox-backend question is skipped entirely.
if detect_managed_agents_token; then
  echo "Detected an injected DigitalOcean Managed Agents token — skipping the sandbox-backend question."
  SANDBOX_BACKEND="$MANAGED_AGENTS_SANDBOX_BACKEND_VALUE"
  DO_AGENTS_API_TOKEN="$DO_MANAGED_AGENTS_TOKEN"
  E2B_API_KEY=""
else
  echo "Sandbox backend (where agent turns run):"
  echo "  1) DigitalOcean Managed Agents (default) — needs a DigitalOcean personal access token"
  echo "     (cloud.digitalocean.com/account/api/tokens)"
  echo "  2) e2b — https://e2b.dev"
  read -rp "Selection [1/2, Enter for DigitalOcean Managed Agents]: " SANDBOX_SEL
  case "$SANDBOX_SEL" in
    2) SANDBOX_BACKEND=e2b ;;
    *) SANDBOX_BACKEND="$MANAGED_AGENTS_SANDBOX_BACKEND_VALUE" ;;
  esac

  if [ "$SANDBOX_BACKEND" = "$MANAGED_AGENTS_SANDBOX_BACKEND_VALUE" ]; then
    read -rsp "DigitalOcean API token: " DO_AGENTS_API_TOKEN
    echo ""
    E2B_API_KEY=""
  else
    read -rsp "e2b API key: " E2B_API_KEY
    echo ""
    DO_AGENTS_API_TOKEN=""
  fi
fi
[ -n "${old_histfile:-}" ] && export HISTFILE="$old_histfile"

echo ""
echo "Generating the password hash and starting QM..."

PW_HASH="$(printf '%s\n' "$ADMIN_PASSWORD" | python3 /srv/qm/gen-secrets.py hash-password)"
write_env_kv MODEL_PROVIDER "$MODEL_PROVIDER"
write_env_kv ANTHROPIC_API_KEY "$ANTHROPIC_API_KEY"
write_env_kv OPENAI_API_KEY "$OPENAI_API_KEY"
write_env_kv DO_SERVERLESS_INFERENCE_API_KEY "$DO_SERVERLESS_INFERENCE_API_KEY"
write_env_kv PI_MODEL "$PI_MODEL"
write_env_kv SANDBOX_BACKEND "$SANDBOX_BACKEND"
write_env_kv E2B_API_KEY "$E2B_API_KEY"
write_env_kv DO_AGENTS_API_TOKEN "$DO_AGENTS_API_TOKEN"
write_env_kv ADMIN_GRANTS "${ADMIN_EMAIL}:org_admin"
write_env_kv AUTH_ALLOWED_EMAILS "$ADMIN_EMAIL"
write_env_kv OIDC_ALLOWED_EMAILS "$ADMIN_EMAIL"
write_env_kv AUTH_PASSWORD_USERS "${ADMIN_EMAIL}:${PW_HASH}"

(cd /srv/qm && docker compose up -d)

echo ""
echo "Containers are up — giving Postgres + core a moment to finish starting (30s)..."
sleep 30

MODEL_SUMMARY="$MODEL_PROVIDER"
if [ "$MODEL_CHOICE" = do-inference ]; then
  register_do_inference_provider "$DO_SERVERLESS_INFERENCE_API_KEY" || true
  MODEL_SUMMARY="DigitalOcean Serverless Inference (${DO_INFERENCE_MODEL_ID})"
fi

SANDBOX_SUMMARY="e2b"
if [ "$SANDBOX_BACKEND" = "$MANAGED_AGENTS_SANDBOX_BACKEND_VALUE" ]; then
  SANDBOX_SUMMARY="DigitalOcean Managed Agents"
fi

echo ""
echo "========================================================================"
echo "  Setup complete! Your QM is ready."
echo ""
echo "  Dashboard: https://${myip}  (Let's Encrypt short-lived IP cert — your browser may warn on first visit)"
echo "  Sign in:   ${ADMIN_EMAIL}"
echo "  Model:     ${MODEL_SUMMARY}"
echo "  Sandbox:   ${SANDBOX_SUMMARY}"
echo "========================================================================"
echo ""

remove_first_login_hook
exit 0
