#!/bin/sh
set -e

mkdir -p /var/www/html/.well-known/acme-challenge

python3 -m venv /opt/certbot-venv
/opt/certbot-venv/bin/pip install --disable-pip-version-check --no-cache-dir 'certbot>=5.4,<6'

rm -f /etc/nginx/sites-enabled/default

cat >/etc/nginx/sites-available/goose-bootstrap <<'NGINX'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    root /var/www/html;
    location /.well-known/acme-challenge/ {
        try_files $uri =404;
    }
    location / {
        return 200 "Image build: replace this Droplet from snapshot for the full Goose console.\n";
        add_header Content-Type text/plain;
    }
}
NGINX

ln -sf /etc/nginx/sites-available/goose-bootstrap /etc/nginx/sites-enabled/goose-bootstrap
nginx -t
systemctl enable nginx
systemctl restart nginx

systemctl daemon-reload
systemctl enable ttyd-goose

# Goose CLI: install during image build so a broken upstream installer fails Packer, not customer first login.
GOOSE_REL="${application_version:-stable}"
GOOSE_INSTALLER=/tmp/goose-download-cli.sh
rm -f "$GOOSE_INSTALLER"
curl -fsSL "https://github.com/aaif-goose/goose/releases/download/${GOOSE_REL}/download_cli.sh" -o "$GOOSE_INSTALLER"
chmod +x "$GOOSE_INSTALLER"
export GOOSE_BIN_DIR=/usr/local/bin
export CONFIGURE=false
/bin/bash "$GOOSE_INSTALLER"
rm -f "$GOOSE_INSTALLER"
command -v goose >/dev/null 2>&1 || {
    echo "ERROR: goose not found after install (expected in /usr/local/bin)." >&2
    exit 1
}
goose --version 2>/dev/null || true

chmod +x /etc/update-motd.d/99-one-click
chmod +x /opt/goose/first-login-setup.sh
chmod +x /opt/goose/enable-web-console.sh
chmod +x /opt/goose/configure-gradient-key.sh
chmod +x /opt/goose/migrate-gradient-provider-id.sh
chmod 644 /opt/goose/lib-goose-gradient.sh
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot
