#!/bin/bash
# Enable or re-enable the HTTPS web console (nginx -> ttyd + Basic Auth + Let's Encrypt).
# Run as root, from an interactive terminal:  /opt/goose/enable-web-console.sh

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root."
    exit 1
fi

if [ ! -t 0 ]; then
    echo "This script must be run interactively (TTY)."
    exit 1
fi

if ! systemctl is-active --quiet ttyd-goose; then
    echo "Starting ttyd (localhost web terminal backend)..."
    systemctl enable --now ttyd-goose
fi

echo ""
echo "=== Goose: HTTPS web console setup ==="
echo "nginx will listen on ports 80 and 443, proxy to ttyd on 127.0.0.1:7681, and use HTTP Basic Auth."
echo ""

while true; do
    read -r -s -p "Choose a web console password (user 'goose', min 8 characters): " WEB_PASS
    echo ""
    read -r -s -p "Confirm password: " WEB_PASS2
    echo ""
    if [ "$WEB_PASS" != "$WEB_PASS2" ]; then
        echo "Passwords do not match. Try again."
        continue
    fi
    if [ -z "$WEB_PASS" ]; then
        echo "Password cannot be empty. To skip the web console, leave nginx disabled (do not run this script)."
        continue
    fi
    if [ "${#WEB_PASS}" -lt 8 ]; then
        echo "Use at least 8 characters."
        continue
    fi
    break
done

umask 077
install -d -m 0700 /root
printf '%s\n' "$WEB_PASS" >/root/.goose_web_console_password.txt
chmod 600 /root/.goose_web_console_password.txt
echo "Saved password copy at /root/.goose_web_console_password.txt (mode 600). Delete when no longer needed."

htpasswd -cb /etc/nginx/.goose-ttyd.htpasswd goose "$WEB_PASS"
chmod 640 /etc/nginx/.goose-ttyd.htpasswd
chown root:www-data /etc/nginx/.goose-ttyd.htpasswd

PUBLIC_IP="$(curl -fsS --retry 3 --retry-connrefused --max-time 3 \
    http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null || true)"
if [ -z "$PUBLIC_IP" ]; then
    PUBLIC_IP="$(hostname -I | awk '{print $1}')"
fi

mkdir -p /etc/ssl/goose /var/www/html/.well-known/acme-challenge

if [ ! -f /etc/ssl/goose/selfsigned.crt ] || [ ! -f /etc/ssl/goose/selfsigned.key ]; then
    openssl req -newkey rsa:2048 -nodes -x509 -days 30 \
        -subj "/CN=${PUBLIC_IP}" \
        -addext "subjectAltName=IP:${PUBLIC_IP}" \
        -keyout /etc/ssl/goose/selfsigned.key \
        -out /etc/ssl/goose/selfsigned.crt 2>/dev/null
    chmod 640 /etc/ssl/goose/selfsigned.key
    chmod 644 /etc/ssl/goose/selfsigned.crt
fi

SSL_CERT=/etc/ssl/goose/selfsigned.crt
SSL_KEY=/etc/ssl/goose/selfsigned.key

sed -e "s/__DROPLET_IP__/${PUBLIC_IP}/g" \
    -e "s|__SSL_CERT__|${SSL_CERT}|g" \
    -e "s|__SSL_KEY__|${SSL_KEY}|g" \
    /opt/goose/nginx-active.conf.tpl >/etc/nginx/sites-available/goose-ttyd

rm -f /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/goose-bootstrap
ln -sf /etc/nginx/sites-available/goose-ttyd /etc/nginx/sites-enabled/goose-ttyd

nginx -t
systemctl enable nginx
systemctl start nginx
systemctl reload nginx

echo ""
echo "Requesting Let's Encrypt certificate for ${PUBLIC_IP} (short-lived IP profile)..."
set +e
/opt/certbot-venv/bin/certbot certonly \
    --webroot -w /var/www/html \
    --preferred-profile shortlived \
    --agree-tos --register-unsafely-without-email \
    --non-interactive \
    --ip-address "${PUBLIC_IP}"
CERT_STATUS=$?
set -e

LE_DIR="/etc/letsencrypt/live/${PUBLIC_IP}"
if [ "$CERT_STATUS" -eq 0 ] && [ ! -f "${LE_DIR}/fullchain.pem" ]; then
    LE_DIR=""
    newest=""
    for d in /etc/letsencrypt/live/*/; do
        [ -f "${d}fullchain.pem" ] || continue
        ts=$(stat -c %Y "${d}fullchain.pem" 2>/dev/null || stat -f %m "${d}fullchain.pem" 2>/dev/null || echo 0)
        if [ -z "$newest" ] || [ "$ts" -gt "$newest" ]; then
            newest=$ts
            LE_DIR=$(dirname "${d}fullchain.pem")
        fi
    done
fi
if [ "$CERT_STATUS" -eq 0 ] && [ -n "$LE_DIR" ] && [ -f "${LE_DIR}/fullchain.pem" ]; then
    SSL_CERT="${LE_DIR}/fullchain.pem"
    SSL_KEY="${LE_DIR}/privkey.pem"
    sed -e "s/__DROPLET_IP__/${PUBLIC_IP}/g" \
        -e "s|__SSL_CERT__|${SSL_CERT}|g" \
        -e "s|__SSL_KEY__|${SSL_KEY}|g" \
        /opt/goose/nginx-active.conf.tpl >/etc/nginx/sites-available/goose-ttyd
    nginx -t
    systemctl reload nginx
    echo "Let's Encrypt certificate installed."
else
    echo "Let's Encrypt issuance did not complete (exit ${CERT_STATUS}). Using self-signed TLS under /etc/ssl/goose/."
    echo "Retry when port 80 is reachable:"
    echo "  /opt/certbot-venv/bin/certbot certonly --webroot -w /var/www/html --preferred-profile shortlived --agree-tos --register-unsafely-without-email --ip-address ${PUBLIC_IP}"
fi

cat >/etc/cron.d/goose-certbot-renew <<CRON
# Renew Let's Encrypt IP certificate (short-lived profile); reload nginx on success
0 2,14 * * * root /opt/certbot-venv/bin/certbot renew -q --deploy-hook "systemctl reload nginx" >>/var/log/goose-certbot.log 2>&1
CRON
chmod 644 /etc/cron.d/goose-certbot-renew

rm -f /root/.goose-web-console-disabled

echo ""
echo "=== Web console enabled ==="
echo "Open: https://${PUBLIC_IP}/  (Basic Auth user: goose)"
echo ""
