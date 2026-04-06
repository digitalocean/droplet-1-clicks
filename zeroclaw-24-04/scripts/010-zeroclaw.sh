#!/bin/sh

APP_VERSION="${application_version:-v0.1.7-beta.30}"

# Open required ports
ufw allow 80
ufw allow 443
ufw limit ssh/tcp
ufw --force enable

# Install Caddy (reverse proxy with automatic TLS)
curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/gpg.key" | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" > /etc/apt/sources.list.d/caddy-stable.list
apt-get update -y
apt-get install -y caddy

mkdir -p /var/log/caddy
chown -R caddy:caddy /var/log/caddy
touch /var/log/caddy/access.json
chown caddy:caddy /var/log/caddy/access.json

# Create zeroclaw user
useradd -m -s /bin/bash zeroclaw || true

# Detect architecture and download pre-built binary
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  TARGET="x86_64-unknown-linux-gnu" ;;
    aarch64) TARGET="aarch64-unknown-linux-gnu" ;;
    armv7l)  TARGET="armv7-unknown-linux-gnueabihf" ;;
    *)       echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

DOWNLOAD_URL="https://github.com/zeroclaw-labs/zeroclaw/releases/download/${APP_VERSION}/zeroclaw-${TARGET}.tar.gz"
echo "Downloading ZeroClaw ${APP_VERSION} for ${TARGET}..."
curl -fsSLO "$DOWNLOAD_URL"
tar xzf "zeroclaw-${TARGET}.tar.gz"
install -m 0755 zeroclaw /usr/local/bin/zeroclaw
rm -f "zeroclaw-${TARGET}.tar.gz" zeroclaw

# Verify installation
/usr/local/bin/zeroclaw --help > /dev/null 2>&1
echo "ZeroClaw ${APP_VERSION} installed successfully."

# Create ZeroClaw directories
mkdir -p /home/zeroclaw/.zeroclaw
mkdir -p /home/zeroclaw/workspace

chown -R zeroclaw:zeroclaw /home/zeroclaw/.zeroclaw
chown -R zeroclaw:zeroclaw /home/zeroclaw/workspace
chmod 0700 /home/zeroclaw/.zeroclaw

# Enable fail2ban
systemctl enable fail2ban
systemctl restart fail2ban

# Make all scripts executable
chmod +x /opt/restart-zeroclaw.sh
chmod +x /opt/status-zeroclaw.sh
chmod +x /opt/update-zeroclaw.sh
chmod +x /opt/zeroclaw-cli.sh
chmod +x /opt/setup-zeroclaw-domain.sh
chmod +x /etc/setup_wizard.sh
chmod +x /etc/update-motd.d/99-one-click
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot

# Don't enable yet — the setup wizard enables and starts after config is in place
