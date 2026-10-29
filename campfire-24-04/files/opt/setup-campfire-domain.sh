#!/bin/bash
set -euo pipefail

PORT=8080
BIND_IP=127.0.0.1

read -rp "Enter the domain you pointed at this droplet (e.g. chat.example.com): " DOMAIN
if [ -z "${DOMAIN}" ]; then
    echo "Domain cannot be empty."
    exit 1
fi

# Hostname only — reject values that could break the Caddyfile.
if ! printf '%s' "${DOMAIN}" | grep -Eq '^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$'; then
    echo "Invalid domain. Use a hostname like chat.example.com (letters, digits, dots, hyphens)."
    exit 1
fi

read -rp "Enter an email for Let's Encrypt notifications (optional): " EMAIL

if [ -n "${EMAIL}" ]; then
    if ! printf '%s' "${EMAIL}" | grep -Eq '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'; then
        echo "Invalid email. Use a simple address like admin@example.com, or leave blank."
        exit 1
    fi
fi

# Caddy v2: `email` is a global option and must live in a top-level `{ }` block.
if [ -n "${EMAIL}" ]; then
    cat > /etc/caddy/Caddyfile << CADDYEOF
{
	email ${EMAIL}
}

${DOMAIN} {
	tls {
		issuer acme {
			dir https://acme-v02.api.letsencrypt.org/directory
			profile shortlived
		}
	}
	reverse_proxy ${BIND_IP}:${PORT}
	header X-DO-MARKETPLACE "campfire"
}
CADDYEOF
else
    cat > /etc/caddy/Caddyfile << CADDYEOF
${DOMAIN} {
	tls {
		issuer acme {
			dir https://acme-v02.api.letsencrypt.org/directory
			profile shortlived
		}
	}
	reverse_proxy ${BIND_IP}:${PORT}
	header X-DO-MARKETPLACE "campfire"
}
CADDYEOF
fi

systemctl daemon-reload
systemctl enable caddy
systemctl restart caddy

echo "Caddy is now proxying https://${DOMAIN} to ${BIND_IP}:${PORT}."
echo "SSL certificate will be provisioned automatically via Let's Encrypt."
echo "Campfire remains on loopback only; keep DISABLE_SSL=true in /opt/campfire.env."
