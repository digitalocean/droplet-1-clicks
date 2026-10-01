#!/bin/bash
# QM first-login setup wizard — collects the admin account, a model
# provider key (Anthropic or OpenAI), and an e2b key for agent sandboxes,
# then brings the stack up.

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
  2. One model provider API key — Anthropic or OpenAI, your choice.
  3. An e2b API key for agent sandboxes (https://e2b.dev -> console.e2b.dev
     -> API Keys; new accounts get \$100 in free credits).

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
echo "Model provider:"
echo "  1) Anthropic (default) — https://console.anthropic.com/settings/keys"
echo "  2) OpenAI               — https://platform.openai.com/api-keys"
read -rp "Selection [1/2, Enter for Anthropic]: " PROVIDER_SEL
case "$PROVIDER_SEL" in
  2) MODEL_PROVIDER=openai ;;
  *) MODEL_PROVIDER=anthropic ;;
esac

if [ "$MODEL_PROVIDER" = openai ]; then
  read -rsp "OpenAI API key: " OPENAI_API_KEY
  echo ""
  ANTHROPIC_API_KEY=""
else
  read -rsp "Anthropic API key: " ANTHROPIC_API_KEY
  echo ""
  OPENAI_API_KEY=""
fi
read -rsp "e2b API key: " E2B_API_KEY
echo ""
[ -n "${old_histfile:-}" ] && export HISTFILE="$old_histfile"

echo ""
echo "Generating the password hash and starting QM..."

PW_HASH="$(printf '%s\n' "$ADMIN_PASSWORD" | python3 /srv/qm/gen-secrets.py hash-password)"
write_env_kv MODEL_PROVIDER "$MODEL_PROVIDER"
write_env_kv ANTHROPIC_API_KEY "$ANTHROPIC_API_KEY"
write_env_kv OPENAI_API_KEY "$OPENAI_API_KEY"
write_env_kv E2B_API_KEY "$E2B_API_KEY"
write_env_kv ADMIN_GRANTS "${ADMIN_EMAIL}:org_admin"
write_env_kv AUTH_ALLOWED_EMAILS "$ADMIN_EMAIL"
write_env_kv OIDC_ALLOWED_EMAILS "$ADMIN_EMAIL"
write_env_kv AUTH_PASSWORD_USERS "${ADMIN_EMAIL}:${PW_HASH}"

(cd /srv/qm && docker compose up -d)

echo ""
echo "Containers are up — giving Postgres + core a moment to finish starting (30s)..."
sleep 30

echo ""
echo "========================================================================"
echo "  Setup complete! Your QM is ready."
echo ""
echo "  Dashboard: https://${myip}  (Let's Encrypt short-lived IP cert — your browser may warn on first visit)"
echo "  Sign in:   ${ADMIN_EMAIL}"
echo "  Model:     ${MODEL_PROVIDER}"
echo "========================================================================"
echo ""

remove_first_login_hook
exit 0
