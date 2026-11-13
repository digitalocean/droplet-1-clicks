#!/bin/bash
set -euo pipefail

NOD_DIR="${NOD_DIR:-/opt/nod}"
SELF_HOST_DIR="${NOD_DIR}/deployment/self-host"
ENV_FILE="${SELF_HOST_DIR}/.env"
CADDYFILE="/etc/caddy/Caddyfile"

if [ ! -f "${ENV_FILE}" ]; then
  echo "ERROR: Missing ${ENV_FILE}. Finish first-boot setup first." >&2
  exit 1
fi

read -rp "Enter the domain you pointed at this droplet (e.g. nod.example.com): " DOMAIN
if [ -z "${DOMAIN}" ]; then
  echo "Domain cannot be empty."
  exit 1
fi

DOMAIN="${DOMAIN#http://}"
DOMAIN="${DOMAIN#https://}"
DOMAIN="${DOMAIN%%/*}"
DOMAIN="${DOMAIN%%:*}"
if [ -z "${DOMAIN}" ]; then
  echo "Domain cannot be empty."
  exit 1
fi

PUBLIC_URL="https://${DOMAIN}"

cat > "${CADDYFILE}" <<CADDYEOC
${DOMAIN} {
    tls {
        issuer acme {
            dir https://acme-v02.api.letsencrypt.org/directory
            profile shortlived
        }
    }
    reverse_proxy 127.0.0.1:4310
    header X-DO-MARKETPLACE "nod"
}
CADDYEOC

if grep -qE '^NOD_PUBLIC_URL=' "${ENV_FILE}"; then
  sed -i "s|^NOD_PUBLIC_URL=.*|NOD_PUBLIC_URL=${PUBLIC_URL}|" "${ENV_FILE}"
else
  printf 'NOD_PUBLIC_URL=%s\n' "${PUBLIC_URL}" >> "${ENV_FILE}"
fi
chmod 600 "${ENV_FILE}"

systemctl enable caddy
systemctl restart caddy
/opt/restart-nod.sh

echo
echo "Nod is configured for ${PUBLIC_URL}"
echo "Open that URL and enter NOD_AUTH_TOKEN from ${ENV_FILE}."
