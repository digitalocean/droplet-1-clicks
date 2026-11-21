#!/bin/bash
set -euo pipefail

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
  local file="$1" key="$2" val="$3" tmp
  touch "$file"
  tmp="$(mktemp)"
  # Avoid sed replacements: values may contain & \ | etc.
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "${key}="*) ;;
      *) printf '%s\n' "$line" ;;
    esac
  done <"$file" >"$tmp"
  printf '%s=%s\n' "$key" "$val" >>"$tmp"
  mv "$tmp" "$file"
}

write_kv "$ENV_FILE" PAPERCLIP_PUBLIC_URL "$PUBLIC_URL"
write_kv "$ENV_FILE" PAPERCLIP_ALLOWED_HOSTNAMES "$DOMAIN"
chmod 600 "$ENV_FILE"

if [ -f "$INSTANCE_ENV" ]; then
  write_kv "$INSTANCE_ENV" PAPERCLIP_PUBLIC_URL "$PUBLIC_URL"
  write_kv "$INSTANCE_ENV" PAPERCLIP_ALLOWED_HOSTNAMES "$DOMAIN"
  chown paperclip:paperclip "$INSTANCE_ENV"
  chmod 600 "$INSTANCE_ENV"
fi

if [ -f "$CONFIG" ] && command -v python3 >/dev/null 2>&1; then
  python3 - "$CONFIG" "$PUBLIC_URL" "$DOMAIN" <<'PY'
import json, sys
path, public_url, domain = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, encoding="utf-8") as f:
    cfg = json.load(f)
cfg.setdefault("server", {})["allowedHostnames"] = [domain]
cfg.setdefault("auth", {})["baseUrlMode"] = "explicit"
cfg["auth"]["publicBaseUrl"] = public_url
with open(path, "w", encoding="utf-8") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
PY
  chown paperclip:paperclip "$CONFIG"
  chmod 600 "$CONFIG"
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
