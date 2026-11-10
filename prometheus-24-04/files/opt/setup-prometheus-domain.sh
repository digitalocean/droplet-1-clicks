#!/bin/bash
set -euo pipefail

PORT=9090
BIND_IP=127.0.0.1

read -rp "Enter the domain you pointed at this droplet (e.g. prometheus.example.com): " DOMAIN
if [ -z "${DOMAIN}" ]; then
  echo "Domain cannot be empty."
  exit 1
fi

read -rp "Enter an email for Let's Encrypt notifications (optional): " EMAIL

{
  cat > /etc/caddy/Caddyfile << CADDYEOC
${DOMAIN} {
    tls {
        issuer acme {
            dir https://acme-v02.api.letsencrypt.org/directory
            profile shortlived
        }
    }
    reverse_proxy ${BIND_IP}:${PORT}
    header X-DO-MARKETPLACE "prometheus"
}
CADDYEOC
  if [ -n "$EMAIL" ]; then
    sed -i "1iemail ${EMAIL}" /etc/caddy/Caddyfile
  fi
}

# Keep Prometheus external URL in sync with the public hostname
if grep -q 'PLACEHOLDER_DOMAIN\|--web.external-url=' /etc/systemd/system/prometheus.service 2>/dev/null; then
  sed -i "s|--web.external-url=https://[^/]*/|--web.external-url=https://${DOMAIN}/|" \
    /etc/systemd/system/prometheus.service
  systemctl daemon-reload
fi

systemctl enable caddy
systemctl restart caddy
systemctl restart prometheus

echo "Caddy is now proxying https://${DOMAIN} to ${BIND_IP}:${PORT}."
echo "Ensure DNS A record for ${DOMAIN} points at this droplet and ports 80/443 are open."
