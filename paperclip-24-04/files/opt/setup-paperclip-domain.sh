#!/bin/bash
set -euo pipefail

# shellcheck source=/opt/paperclip-safe-file.sh
source /opt/paperclip-safe-file.sh

PORT=3100
BIND_IP=127.0.0.1
ENV_FILE=/opt/paperclip.env
INSTANCE_ENV=/home/paperclip/.paperclip/instances/default/.env
CONFIG=/home/paperclip/.paperclip/instances/default/config.json

read -rp "Enter the domain you pointed at this droplet (e.g. paperclip.example.com): " DOMAIN
if [ -z "${DOMAIN}" ]; then
  echo "Domain cannot be empty."
  exit 1
fi
# Hostname labels only — reject Caddyfile metacharacters / whitespace
if ! printf '%s' "$DOMAIN" | grep -Eq '^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$'; then
  echo "Invalid domain. Use a hostname like paperclip.example.com (letters, digits, dots, hyphens)." >&2
  exit 1
fi

read -rp "Enter an email for Let's Encrypt notifications (optional): " EMAIL
if [ -n "${EMAIL}" ] && ! printf '%s' "$EMAIL" | grep -Eq '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'; then
  echo "Invalid email for Let's Encrypt notifications." >&2
  exit 1
fi

PUBLIC_URL="https://${DOMAIN}"

{
  if [ -n "${EMAIL}" ]; then
    GLOBAL_OPTS="{
	email ${EMAIL}
}
"
  else
    GLOBAL_OPTS=""
  fi
  cat > /etc/caddy/Caddyfile <<CADDYEOC
${GLOBAL_OPTS}${DOMAIN} {
	tls {
		issuer acme {
			dir https://acme-v02.api.letsencrypt.org/directory
			profile shortlived
		}
	}
	reverse_proxy ${BIND_IP}:${PORT}
	header X-DO-MARKETPLACE "paperclip"
}
CADDYEOC
}

write_kv() {
  paperclip_write_env_kv "$1" "$2" "$3"
}

write_kv "$ENV_FILE" PAPERCLIP_PUBLIC_URL "$PUBLIC_URL"
write_kv "$ENV_FILE" PAPERCLIP_ALLOWED_HOSTNAMES "$DOMAIN"

if [ -e "$INSTANCE_ENV" ] || [ -L "$INSTANCE_ENV" ]; then
  paperclip_assert_safe_target "$INSTANCE_ENV" || exit 1
fi
if [ -f "$INSTANCE_ENV" ]; then
  write_kv "$INSTANCE_ENV" PAPERCLIP_PUBLIC_URL "$PUBLIC_URL"
  write_kv "$INSTANCE_ENV" PAPERCLIP_ALLOWED_HOSTNAMES "$DOMAIN"
fi

if [ -e "$CONFIG" ] || [ -L "$CONFIG" ]; then
  paperclip_assert_safe_target "$CONFIG" || exit 1
fi
if [ -f "$CONFIG" ] && command -v python3 >/dev/null 2>&1; then
  cfg_json="$(
    /usr/bin/python3 -I - "$CONFIG" "$PUBLIC_URL" "$DOMAIN" <<'PY'
import json, sys
path, public_url, domain = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, encoding="utf-8") as f:
    cfg = json.load(f)
cfg.setdefault("server", {})["allowedHostnames"] = [domain]
cfg.setdefault("auth", {})["baseUrlMode"] = "explicit"
cfg["auth"]["publicBaseUrl"] = public_url
print(json.dumps(cfg, indent=2))
PY
  )"
  printf '%s\n' "$cfg_json" | paperclip_atomic_write "$CONFIG" 600
else
  # DATABASE_URL is read from /opt/paperclip.env (required for authenticated/public)
  /opt/write-paperclip-config.sh "$PUBLIC_URL" "$DOMAIN"
fi

systemctl enable caddy
systemctl restart caddy
systemctl restart paperclip

echo "Caddy is now proxying ${PUBLIC_URL} to ${BIND_IP}:${PORT}."
echo "Paperclip public URL updated. Re-issue bootstrap invite if needed:"
echo "  su - paperclip -c \"paperclipai auth bootstrap-ceo --force --base-url ${PUBLIC_URL}\""
