#!/bin/sh

APP_VERSION="${application_version:-Latest}"

# Open required ports
ufw allow 80
ufw allow 443
ufw limit ssh/tcp
ufw --force enable

# Install Node.js 22 (required for OpenClaw)
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs

# Install Caddy (reverse proxy with automatic TLS)
curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/gpg.key" | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" > /etc/apt/sources.list.d/caddy-stable.list
apt-get update -y
apt-get install -y caddy
mkdir -p /var/log/caddy
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
chmod 0700 /home/openclaw/.openclaw
chown -R openclaw:openclaw /home/openclaw/workspace

# Create environment file (will be configured on first boot)
cat > /opt/openclaw.env << EOF
# OpenClaw Environment Configuration
# 
# After making changes to this file, restart OpenClaw with:
#   systemctl restart openclaw

# Installed OpenClaw version
OPENCLAW_VERSION=${APP_VERSION}

# Gateway Configuration
OPENCLAW_GATEWAY_PORT=18789
OPENCLAW_GATEWAY_BIND=lan

# Gateway token will be auto-generated on first boot
OPENCLAW_GATEWAY_TOKEN=PLACEHOLDER_WILL_BE_REPLACED_ON_FIRST_BOOT

# Model Configuration
# Run the interactive setup script to configure a provider:
#   sudo /etc/token_setup.sh
# This lets you choose between Anthropic, OpenAI, or GradientAI.
#
# Or uncomment and configure your preferred AI model provider:
# For Anthropic Claude (recommended):
# ANTHROPIC_API_KEY=your_api_key_here

# For OpenAI:
# OPENAI_API_KEY=your_api_key_here

# Channel Configuration
# Uncomment and configure messaging channels as needed

# Telegram Bot Token
# TELEGRAM_BOT_TOKEN=your_bot_token_here

# Discord Bot Token
# DISCORD_BOT_TOKEN=your_bot_token_here

# Slack Bot Token and App Token
# SLACK_BOT_TOKEN=your_bot_token_here
# SLACK_APP_TOKEN=your_app_token_here

EOF

# Create systemd service file
cat > /etc/systemd/system/openclaw.service << 'EOF'
[Unit]
Description=OpenClaw Gateway Service
After=network-online.target docker.service
Wants=network-online.target
Requires=docker.service

[Service]
Type=simple
User=openclaw
Group=openclaw
WorkingDirectory=/home/openclaw
EnvironmentFile=/opt/openclaw.env
Environment="HOME=/home/openclaw"
Environment="NODE_ENV=production"
Environment="PATH=/home/openclaw/.npm/bin:/home/openclaw/homebrew/bin:/usr/local/bin:/usr/bin:/bin:"

# Start command - uses the global openclaw command
ExecStart=/usr/bin/openclaw gateway --port ${OPENCLAW_GATEWAY_PORT} --allow-unconfigured

# Restart policy
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Resource limits
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl enable fail2ban
systemctl restart fail2ban

cat > /etc/caddy/Caddyfile << 'EOF'
PLACEHOLDER_DOMAIN {
    tls {
        issuer acme {
            dir https://acme-v02.api.letsencrypt.org/directory
            profile shortlived
        }
    }
    reverse_proxy localhost:18789
    header X-DO-MARKETPLACE "openclaw"
}
EOF

mkdir -p /home/openclaw/.openclaw
cp /etc/config/openclaw.json  /home/openclaw/.openclaw/openclaw.json
chmod 0600 /home/openclaw/.openclaw/openclaw.json

# Make all scripts executable
chmod +x /opt/restart-openclaw.sh
chmod +x /opt/status-openclaw.sh
chmod +x /opt/update-openclaw.sh
chmod +x /opt/openclaw-cli.sh
chmod +x /opt/setup-openclaw-domain.sh
chmod +x /opt/openclaw-tui.sh
chmod +x /etc/token_setup.sh
chmod +x /etc/update-motd.d/99-one-click
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot

# Build the sandbox Docker image if docker-setup script exists
if which openclaw > /dev/null 2>&1; then
    # Run openclaw's docker setup if available
    su - openclaw -c "openclaw docker-setup" || echo "Warning: Sandbox image build failed, will be built on first use"
fi

# Enable but don't start the service yet (will start after onboot configuration)
systemctl enable openclaw

# Setup homebrew for optional tools
su - openclaw -c "mkdir -p ~/homebrew && curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C ~/homebrew" || true
su - openclaw -c "~/homebrew/bin/brew install steipete/tap/wacli" 2>/dev/null || echo "Warning: wacli installation skipped"
su - openclaw -c "~/homebrew/bin/brew link wacli" 2>/dev/null || true
 