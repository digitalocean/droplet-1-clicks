#!/bin/bash
set -euo pipefail

PORT=8080
BIND_IP=127.0.0.1
SETTINGS_FILE="/home/django/django_project/django_project/settings.py"

read -rp "Enter the domain you pointed at this droplet (e.g. app.example.com): " DOMAIN
if [ -z "${DOMAIN}" ]; then
    echo "Domain cannot be empty."
    exit 1
fi

# Hostname only — reject values that could break the settings.py append.
if ! printf '%s' "${DOMAIN}" | grep -Eq '^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$'; then
    echo "Invalid domain. Use a hostname like app.example.com (letters, digits, dots, hyphens)."
    exit 1
fi

read -rp "Enter an email for Let's Encrypt notifications (optional): " EMAIL

if [ -n "${EMAIL}" ]; then
    # Keep Caddyfile/global options safe: no whitespace or Caddy-significant chars.
    if ! printf '%s' "${EMAIL}" | grep -Eq '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'; then
        echo "Invalid email. Use a simple address like admin@example.com, or leave blank."
        exit 1
    fi
fi

# Caddy v2: `email` is a global option and must live in a top-level `{ }` block.
if [ -n "${EMAIL}" ]; then
    cat > /etc/caddy/Caddyfile << CADDYEOC
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
	header X-DO-MARKETPLACE "django"
}
CADDYEOC
else
    cat > /etc/caddy/Caddyfile << CADDYEOC
${DOMAIN} {
	tls {
		issuer acme {
			dir https://acme-v02.api.letsencrypt.org/directory
			profile shortlived
		}
	}
	reverse_proxy ${BIND_IP}:${PORT}
	header X-DO-MARKETPLACE "django"
}
CADDYEOC
fi

# Append domain to the live settings.py only (shared template .py files stay untouched).
if [ -f "${SETTINGS_FILE}" ] && ! grep -qF "'${DOMAIN}'" "${SETTINGS_FILE}"; then
    if grep -q 'CSRF_TRUSTED_ORIGINS' "${SETTINGS_FILE}"; then
        cat >> "${SETTINGS_FILE}" << PY

# --- DigitalOcean 1-Click: custom domain ${DOMAIN} ---
ALLOWED_HOSTS += ['${DOMAIN}']
CSRF_TRUSTED_ORIGINS += ['https://${DOMAIN}']
PY
    else
        # First-boot proxy inject missing (e.g. custom settings) — define both.
        cat >> "${SETTINGS_FILE}" << PY

# --- DigitalOcean 1-Click: custom domain ${DOMAIN} ---
ALLOWED_HOSTS += ['${DOMAIN}']
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
CSRF_TRUSTED_ORIGINS = ['https://${DOMAIN}']
PY
    fi
fi

systemctl daemon-reload
systemctl enable caddy
systemctl restart caddy

if systemctl is-active --quiet gunicorn; then
    PID=$(systemctl show --value -p MainPID gunicorn.service)
    if [ -n "${PID}" ] && [ "${PID}" != "0" ]; then
        kill -HUP "${PID}" || systemctl restart gunicorn
    else
        systemctl restart gunicorn
    fi
fi

echo "Caddy is now proxying https://${DOMAIN} to ${BIND_IP}:${PORT}."
echo "Updated ALLOWED_HOSTS / CSRF for ${DOMAIN} in ${SETTINGS_FILE}."
