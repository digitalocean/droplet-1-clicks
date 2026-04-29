#!/bin/bash
set -euo pipefail

MARKER=/root/.goose-first-login-done
if [ -f "$MARKER" ]; then
    exit 0
fi

if [ ! -t 0 ]; then
    exit 0
fi

echo ""
echo "=== Goose 1-Click: first-time setup ==="
echo ""
echo "Web console: HTTPS in the browser via nginx (HTTP Basic Auth) -> ttyd."
echo "Leave the password empty (press Enter twice) if you do not want nginx or a browser terminal."
echo "You can enable it later with:  /opt/goose/enable-web-console.sh"
echo ""

WEB_SKIP=0
while true; do
    read -r -s -p "Web console password (empty = skip nginx / no HTTPS web UI): " WEB_PASS
    echo ""
    read -r -s -p "Confirm password: " WEB_PASS2
    echo ""
    if [ "$WEB_PASS" != "$WEB_PASS2" ]; then
        echo "Passwords do not match. Try again."
        continue
    fi
    if [ -z "$WEB_PASS" ]; then
        WEB_SKIP=1
        break
    fi
    if [ "${#WEB_PASS}" -lt 8 ]; then
        echo "Use at least 8 characters, or leave both empty to skip the web console."
        continue
    fi
    WEB_SKIP=0
    break
done

PUBLIC_IP="$(curl -fsS --retry 3 --retry-connrefused --max-time 3 \
    http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null || true)"
if [ -z "$PUBLIC_IP" ]; then
    PUBLIC_IP="$(hostname -I | awk '{print $1}')"
fi

if [ "$WEB_SKIP" -eq 1 ]; then
    echo ""
    echo "Skipping nginx and TLS web setup (no HTTP/HTTPS reverse proxy)."
    rm -f /root/.goose_web_console_password.txt
    rm -f /etc/nginx/sites-enabled/goose-ttyd /etc/nginx/sites-enabled/goose-bootstrap /etc/nginx/sites-enabled/default
    systemctl disable nginx --now 2>/dev/null || true
    systemctl stop nginx 2>/dev/null || true
    rm -f /etc/cron.d/goose-certbot-renew
    touch /root/.goose-web-console-disabled
else
    umask 077
    install -d -m 0700 /root
    printf '%s\n' "$WEB_PASS" >/root/.goose_web_console_password.txt
    chmod 600 /root/.goose_web_console_password.txt
    echo "Saved plain-text copy for your records: /root/.goose_web_console_password.txt (mode 600). Delete it after you store the password elsewhere."

    htpasswd -cb /etc/nginx/.goose-ttyd.htpasswd goose "$WEB_PASS"
    chmod 640 /etc/nginx/.goose-ttyd.htpasswd
    chown root:www-data /etc/nginx/.goose-ttyd.htpasswd

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

    rm -f /root/.goose-web-console-disabled

    echo ""
    echo "Requesting Let's Encrypt certificate for this Droplet's public IP (${PUBLIC_IP})..."
    echo "Using Certbot short-lived IP profile (renewal is configured automatically)."
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
        echo "Let's Encrypt certificate installed. HTTPS uses a publicly trusted chain (short-lived profile)."
    else
        echo "Let's Encrypt issuance did not complete (exit ${CERT_STATUS})."
        echo "The web console still uses the temporary self-signed certificate in /etc/ssl/goose/."
        echo "Ensure port 80 is reachable from the internet for HTTP-01 validation, then run:"
        echo "  /opt/certbot-venv/bin/certbot certonly --webroot -w /var/www/html --preferred-profile shortlived --agree-tos --register-unsafely-without-email --ip-address ${PUBLIC_IP}"
    fi

    cat >/etc/cron.d/goose-certbot-renew <<CRON
# Renew Let's Encrypt IP certificate (short-lived profile); reload nginx on success
0 2,14 * * * root /opt/certbot-venv/bin/certbot renew -q --deploy-hook "systemctl reload nginx" >>/var/log/goose-certbot.log 2>&1
CRON
    chmod 644 /etc/cron.d/goose-certbot-renew
fi

echo ""
echo "Installing Goose CLI (official install script; non-interactive configure)..."
export GOOSE_BIN_DIR=/usr/local/bin
export CONFIGURE=false
curl -fsSL https://github.com/aaif-goose/goose/releases/download/stable/download_cli.sh | bash

if ! command -v goose >/dev/null 2>&1; then
    echo "Warning: goose not found on PATH after install. Check /usr/local/bin and ~/.local/bin."
else
    echo "Goose installed: $(goose --version 2>/dev/null || true)"
fi

touch "$MARKER"
sed -i '/# goose-24-04 first-login/,/first-login-setup.sh/d' /root/.bashrc

echo ""
echo "=== Setup complete ==="
if [ "$WEB_SKIP" -eq 1 ]; then
    echo "Web console: disabled (nginx not running)."
    echo "To enable HTTPS + Basic Auth + Let's Encrypt later, run:  /opt/goose/enable-web-console.sh"
else
    echo "Web console: https://${PUBLIC_IP}/  (HTTP Basic user: goose)"
fi
echo "Run 'goose configure' to connect providers, then use the 'goose' command as usual."
echo ""
