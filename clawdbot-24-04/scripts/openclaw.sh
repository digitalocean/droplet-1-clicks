#!/bin/sh

APP_VERSION="${application_version:-Latest}"

# Open required ports
ufw allow 80
ufw allow 443
ufw limit ssh/tcp
ufw --force enable

# Install Node.js 22 (required for Openclaw)
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs

# Install Caddy (reverse proxy with automatic TLS)
curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/gpg.key" | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" > /etc/apt/sources.list.d/caddy-stable.list
apt-get update -y
apt-get install -y caddy
mkdir -p /var/log/caddy
useradd -m -s /bin/bash caddy || true

chown -R caddy:caddy /var/log/caddy
touch /var/log/caddy/access.json
chown caddy:caddy /var/log/caddy/access.json

# Create openclaw user
useradd -m -s /bin/bash openclaw || true
usermod -aG docker openclaw || true

# Install OpenClaw globally from npm
if [ "$APP_VERSION" != "Latest" ]; then
    npm install -g openclaw@${APP_VERSION}
else
    npm install -g openclaw@latest
fi

# Create openclaw home directory and config directory
mkdir -p /home/openclaw/.openclaw
mkdir -p /home/openclaw/workspace

chown -R openclaw:openclaw /home/openclaw/.openclaw
chown -R openclaw:openclaw /home/openclaw/workspace

chmod 0700 /home/openclaw/.openclaw

systemctl enable fail2ban
systemctl restart fail2ban

cp /etc/config/openclaw.json  /home/openclaw/.openclaw/openclaw.json
chmod 0600 /home/openclaw/.openclaw/openclaw.json

# Make all scripts executable
chmod +x /opt/restart-openclaw.sh
chmod +x /opt/status-openclaw.sh
chmod +x /opt/update-openclaw.sh
chmod +x /opt/openclaw-cli.sh
chmod +x /opt/setup-openclaw-domain.sh
chmod +x /etc/setup_wizard.sh
chmod +x /opt/openclaw-tui.sh

# Build the sandbox image
if which openclaw > /dev/null 2>&1; then
    # Run openclaw's docker setup if available
    su - openclaw -c "openclaw docker-setup" || echo "Warning: Sandbox image build failed, will be built on first use"
fi

# Enable but don't start the service yet (will start after onboot configuration)
systemctl enable openclaw

su - openclaw -c "mkdir -p ~/homebrew && curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C ~/homebrew"
# su - openclaw -c "~/homebrew/bin/brew install steipete/tap/wacli"
# su - openclaw -c "~/homebrew/bin/brew link wacli"

chown -R openclaw /home/openclaw/.npm
su - openclaw -c "npm config set prefix /home/openclaw/.npm"