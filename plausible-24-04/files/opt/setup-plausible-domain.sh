#!/bin/bash
set -euo pipefail

PORT=8000
BIND_IP=127.0.0.1
INSTALL_DIR="/docker/plausible"

read -rp "Enter the domain you pointed at this droplet (e.g. analytics.example.com): " DOMAIN
if [ -z "${DOMAIN}" ]; then
	echo "Domain cannot be empty."
	exit 1
fi

if [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]]; then
	echo "Invalid domain format."
	exit 1
fi

read -rp "Enter an email for Let's Encrypt notifications (optional): " EMAIL

cat >/etc/caddy/Caddyfile <<CADDYEOC
${DOMAIN} {
	tls {
		issuer acme {
			dir https://acme-v02.api.letsencrypt.org/directory
			profile shortlived
		}
	}
	reverse_proxy ${BIND_IP}:${PORT}
	header X-DO-MARKETPLACE "plausible"
}
CADDYEOC

if [ -n "${EMAIL}" ]; then
	sed -i "1iemail ${EMAIL}" /etc/caddy/Caddyfile
fi

systemctl enable caddy
systemctl restart caddy

echo "Waiting for HTTPS certificate for ${DOMAIN}..."
tls_ok=false
for _ in $(seq 1 30); do
	if curl -fsS --max-time 5 "https://${DOMAIN}/" >/dev/null 2>&1; then
		tls_ok=true
		break
	fi
	sleep 2
done

if [ "$tls_ok" != true ]; then
	echo "ERROR: TLS for https://${DOMAIN} failed. Check DNS A record and Caddy logs:"
	echo "  journalctl -u caddy -n 50 --no-pager"
	echo "Not falling back to HTTP. Fix DNS/TLS and rerun: /opt/setup-plausible-domain.sh"
	exit 1
fi

if [ -f "${INSTALL_DIR}/.env" ]; then
	sed -i "s|^BASE_URL=.*|BASE_URL=https://${DOMAIN}|" "${INSTALL_DIR}/.env"
	cd "${INSTALL_DIR}"
	docker compose up -d
fi

echo "Caddy is proxying https://${DOMAIN} to ${BIND_IP}:${PORT}."
echo "BASE_URL updated. Open https://${DOMAIN}/register to create the first admin account if needed."
