#!/bin/bash
set -euo pipefail

# Configure a custom domain with Caddy HTTPS and update Supabase public URLs.

COMPOSE_DIR="/srv/supabase/supabase/docker"
ENV_FILE="${COMPOSE_DIR}/.env"
DOMAIN_TMP="/etc/caddy/Caddyfile.domain.tmp"

echo "This script configures a custom domain and HTTPS for Supabase (Caddy)."
echo "--------------------------------------------------"
echo "Point a DNS A/AAAA record at this Droplet before continuing."
echo "Press Ctrl+C to cancel."
echo "--------------------------------------------------"

if [ ! -f "${DOMAIN_TMP}" ]; then
  echo "ERROR: missing ${DOMAIN_TMP}" >&2
  exit 1
fi

if [ ! -f "${ENV_FILE}" ]; then
  echo "ERROR: missing ${ENV_FILE}" >&2
  exit 1
fi

dom=""
while [ -z "${dom}" ]; do
  read -r -p "Domain/Subdomain name (e.g. supabase.example.com): " dom
  if [ -z "${dom}" ]; then
    echo "Please provide a valid domain or subdomain name, or press Ctrl+C to cancel"
  fi
done

# Strip scheme / trailing slash if pasted by mistake
dom="${dom#http://}"
dom="${dom#https://}"
dom="${dom%%/*}"

read -r -p "Email for Let's Encrypt notifications (optional): " email

shell_quote() {
  printf "'"
  printf '%s' "$1" | sed "s/'/'\\\\''/g"
  printf "'"
}

upsert_env() {
  local key="$1"
  local value="$2"
  sed -i "/^${key}=/d" "${ENV_FILE}"
  printf '%s=%s\n' "${key}" "$(shell_quote "${value}")" >> "${ENV_FILE}"
}

PUBLIC_URL="https://${dom}"
upsert_env SUPABASE_PUBLIC_URL "${PUBLIC_URL}"
upsert_env API_EXTERNAL_URL "${PUBLIC_URL}/auth/v1"
upsert_env SITE_URL "${PUBLIC_URL}"

sed "s/PLACEHOLDER_DOMAIN/${dom}/" "${DOMAIN_TMP}" > /etc/caddy/Caddyfile
if [ -n "${email}" ]; then
  sed -i "1iemail ${email}" /etc/caddy/Caddyfile
fi

systemctl enable caddy

# Apply .env URL changes even if Caddy/ACME is not ready yet (e.g. DNS lag).
COMPOSE_ARGS=(-f docker-compose.yml)
if [ -f "${COMPOSE_DIR}/docker-compose.dbaas.yml" ]; then
  COMPOSE_ARGS+=(-f docker-compose.dbaas.yml)
fi

cd "${COMPOSE_DIR}"
docker compose "${COMPOSE_ARGS[@]}" up -d

set +e
systemctl restart caddy
caddy_rc=$?
set -e

echo ""
echo "Supabase .env public URLs were updated to ${PUBLIC_URL}."
if [ "${caddy_rc}" -ne 0 ]; then
  echo "WARNING: caddy failed to start (rc=${caddy_rc}). Check DNS for ${dom}, ports 80/443, and journalctl -u caddy." >&2
  echo "When DNS is ready: systemctl restart caddy" >&2
else
  echo "Caddy is now proxying ${PUBLIC_URL} to Kong on localhost:8000."
  echo "Ensure DNS for ${dom} points at this Droplet and ports 80/443 are open."
fi
