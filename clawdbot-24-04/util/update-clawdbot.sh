#!/bin/sh

# update-clawdbot.sh
# this script is used to update the DigitalOcean 1-Click Clawdbot/Moltbot image
# to the latest openclaw version. It is used to update version 2026.1.24 to 2026.2.3

APP_VERSION="v2026.2.3"
REPO_URL="https://github.com/openclaw/openclaw.git"
REPO_DIR="/opt/openclaw"

# Gateway Configuration
OPENCLAW_GATEWAY_PORT=18789
OPENCLAW_GATEWAY_BIND=lan

# Shutdown clawdbot
systemctl stop clawdbot 2>/dev/null || true
systemctl disable clawdbot 2>/dev/null || true

# Create openclaw user
useradd -m -s /bin/bash openclaw || true
usermod -aG docker openclaw || true

# Clone or update the Openclaw repository
if [ -d "$REPO_DIR/.git" ]; then
    cd "$REPO_DIR"
    git fetch --tags
    if [ "$APP_VERSION" != "Latest" ]; then
        git checkout "$APP_VERSION"
    else
        git pull origin main 2>/dev/null || true
    fi
else
    cd /opt && git clone "$REPO_URL" "$REPO_DIR"
    cd "$REPO_DIR"
    git fetch --tags
    if [ "$APP_VERSION" != "Latest" ]; then
        git checkout "$APP_VERSION"
    fi
fi
cd "$REPO_DIR"

# Set ownership
chown -R openclaw:openclaw "$REPO_DIR"

# Create openclaw home directory and config directory
mkdir -p /home/openclaw/.openclaw
mkdir -p /home/openclaw/clawd
chown -R openclaw:openclaw /home/openclaw/.openclaw
chmod 0700 /home/openclaw/.openclaw
chown -R openclaw:openclaw /home/openclaw/clawd

# Create systemd service file
cat > /etc/systemd/system/openclaw.service << 'EOF'
[Unit]
Description=Openclaw Gateway Service
After=network-online.target docker.service
Wants=network-online.target
Requires=docker.service

[Service]
Type=simple
User=openclaw
Group=openclaw
WorkingDirectory=/opt/openclaw
EnvironmentFile=/opt/openclaw.env
Environment="HOME=/home/openclaw"
Environment="NODE_ENV=production"
Environment="PATH=/home/openclaw/.npm/bin:/home/openclaw/homebrew/bin:/usr/local/bin:/usr/bin:/bin:"

# Start command - uses the gateway executable with allow-unconfigured for initial setup
ExecStart=/usr/bin/node /opt/openclaw/dist/index.js gateway --port ${OPENCLAW_GATEWAY_PORT} --allow-unconfigured

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

# Create openclaw.env: prefer existing clawdbot.env (migration), then image config, then default
if [ -f /opt/clawdbot.env ]; then
    cp /opt/clawdbot.env /opt/openclaw.env
    echo "Copied /opt/clawdbot.env to /opt/openclaw.env (migration)"
elif [ -f /etc/config/openclaw.env ]; then
    cp /etc/config/openclaw.env /opt/openclaw.env
else
    cat > /opt/openclaw.env << ENVEOF
# Openclaw Environment Configuration
OPENCLAW_VERSION=${APP_VERSION}
OPENCLAW_GATEWAY_PORT=18789
OPENCLAW_GATEWAY_BIND=lan
OPENCLAW_GATEWAY_TOKEN=PLACEHOLDER_WILL_BE_REPLACED_ON_FIRST_BOOT
ENVEOF
fi
# Ensure openclaw-specific vars exist for systemd (may be missing if copied from clawdbot.env)
grep -q '^OPENCLAW_GATEWAY_PORT=' /opt/openclaw.env 2>/dev/null || echo "OPENCLAW_GATEWAY_PORT=18789" >> /opt/openclaw.env
grep -q '^OPENCLAW_VERSION=' /opt/openclaw.env 2>/dev/null || echo "OPENCLAW_VERSION=${APP_VERSION}" >> /opt/openclaw.env
grep -q '^OPENCLAW_GATEWAY_BIND=' /opt/openclaw.env 2>/dev/null || echo "OPENCLAW_GATEWAY_BIND=lan" >> /opt/openclaw.env
# Generate gateway token if missing or placeholder
if ! grep -q '^OPENCLAW_GATEWAY_TOKEN=' /opt/openclaw.env 2>/dev/null || grep -q "PLACEHOLDER_WILL_BE_REPLACED_ON_FIRST_BOOT" /opt/openclaw.env 2>/dev/null; then
    NEW_GATEWAY_TOKEN=$(openssl rand -hex 32)
    if grep -q '^OPENCLAW_GATEWAY_TOKEN=' /opt/openclaw.env 2>/dev/null; then
        sed -i "s/^OPENCLAW_GATEWAY_TOKEN=.*/OPENCLAW_GATEWAY_TOKEN=$NEW_GATEWAY_TOKEN/" /opt/openclaw.env
    else
        echo "OPENCLAW_GATEWAY_TOKEN=$NEW_GATEWAY_TOKEN" >> /opt/openclaw.env
    fi
fi
chown openclaw:openclaw /opt/openclaw.env
chmod 0600 /opt/openclaw.env

# Migrate config: check source location first, then copy directory, then migrate config file
CONFIG_MIGRATED=false

# Check if clawdbot config exists in source location before copying
if [ -f /home/clawdbot/.clawdbot/clawdbot.json ]; then
    mkdir -p /home/openclaw/.openclaw
    cp /home/clawdbot/.clawdbot/clawdbot.json /home/openclaw/.openclaw/openclaw.json
    echo "Migrated /home/clawdbot/.clawdbot/clawdbot.json to /home/openclaw/.openclaw/openclaw.json"
    CONFIG_MIGRATED=true
elif [ -f /home/clawdbot/.clawdbot/config.json ]; then
    mkdir -p /home/openclaw/.openclaw
    cp /home/clawdbot/.clawdbot/config.json /home/openclaw/.openclaw/openclaw.json
    echo "Migrated /home/clawdbot/.clawdbot/config.json to /home/openclaw/.openclaw/openclaw.json"
    CONFIG_MIGRATED=true
elif [ -f /home/clawdbot/.clawdbot/openclaw.json ]; then
    mkdir -p /home/openclaw/.openclaw
    cp /home/clawdbot/.clawdbot/openclaw.json /home/openclaw/.openclaw/openclaw.json
    echo "Using existing /home/clawdbot/.clawdbot/openclaw.json"
    CONFIG_MIGRATED=true
fi

# copy the /home/clawdbot/.clawdbot directory to /home/openclaw/.openclaw
cp -r /home/clawdbot/.clawdbot /home/openclaw/.openclaw 2>/dev/null || true
chown -R openclaw:openclaw /home/openclaw/.openclaw
chmod 0700 /home/openclaw/.openclaw

# Migrate config: prefer existing config from clawdbot copy, then image configs, then default
if [ "$CONFIG_MIGRATED" = "true" ]; then
    echo "Config already migrated from source"
elif [ -f /home/openclaw/.openclaw/openclaw.json ]; then
    echo "Using existing openclaw.json from clawdbot migration"
elif [ -f /home/openclaw/.openclaw/clawdbot.json ]; then
    cp /home/openclaw/.openclaw/clawdbot.json /home/openclaw/.openclaw/openclaw.json
    echo "Migrated clawdbot.json to openclaw.json"
elif [ -f /home/openclaw/.openclaw/config.json ]; then
    cp /home/openclaw/.openclaw/config.json /home/openclaw/.openclaw/openclaw.json
    echo "Migrated config.json to openclaw.json"
elif [ -f /etc/config/openclaw.json ]; then
    cp /etc/config/openclaw.json /home/openclaw/.openclaw/openclaw.json
elif [ -f /etc/config/anthropic.json ]; then
    cp /etc/config/anthropic.json /home/openclaw/.openclaw/openclaw.json
elif [ -f /etc/config/openai.json ]; then
    cp /etc/config/openai.json /home/openclaw/.openclaw/openclaw.json
elif [ -f /etc/config/gradientai.json ]; then
    cp /etc/config/gradientai.json /home/openclaw/.openclaw/openclaw.json
else
    echo "Warning: No config found. Run /etc/setup_wizard.sh after deploy to configure."
    printf '%s\n' '{"gateway":{"mode":"local","bind":"loopback","auth":{"token":"${OPENCLAW_GATEWAY_TOKEN}"},"trustedProxies":["127.0.0.1"]}}' > /home/openclaw/.openclaw/openclaw.json
fi
chown openclaw:openclaw /home/openclaw/.openclaw/openclaw.json
chmod 0600 /home/openclaw/.openclaw/openclaw.json

# Create restart helper script
cat > /opt/restart-openclaw.sh << 'EOF'
#!/bin/bash
echo "Restarting Openclaw Gateway..."
systemctl restart openclaw

# Wait a moment for the service to start
sleep 2

# Check status
if systemctl is-active --quiet openclaw; then
    echo "✅ Openclaw restarted successfully!"
    echo "Gateway is running on port 18789"
    echo "View logs with: journalctl -u openclaw -f"
else
    echo "❌ Error: Failed to restart Openclaw"
    echo "Check logs with: journalctl -u openclaw -xe"
    exit 1
fi
EOF

# Create update script
cat > /opt/update-openclaw.sh << 'EOF'
#!/bin/bash
echo "Updating Openclaw..."
cd /opt/openclaw
git fetch --tags
git checkout main
git pull origin main
EOF

# Create status check script
cat > /opt/status-openclaw.sh << 'EOF'
#!/bin/bash
echo "=== Openclaw Gateway Status ==="
systemctl status openclaw --no-pager

echo ""
echo "=== Gateway Token ==="
if [ -f "/opt/openclaw.env" ]; then
    grep "^OPENCLAW_GATEWAY_TOKEN=" /opt/openclaw.env | cut -d'=' -f2
else
    echo "Token not yet generated. Run the onboot script."
fi

echo ""
echo "=== Gateway URL ==="
myip=$(hostname -I | awk '{print$1}')
echo "http://$myip:18789"
EOF

# Create CLI helper script
cat > /opt/openclaw-cli.sh << 'EOF'
#!/bin/bash
# Helper script to run Openclaw CLI commands as the openclaw user
su - openclaw -c "cd /opt/openclaw && node dist/index.js $*"
EOF

# Create TUI helper script
cat > /opt/openclaw-tui.sh << 'EOF'
gateway_token=$(grep "^OPENCLAW_GATEWAY_TOKEN=" /opt/openclaw.env 2>/dev/null | cut -d'=' -f2)

/opt/openclaw-cli.sh tui --token=${gateway_token}
EOF

# Make all scripts executable
chmod +x /opt/restart-openclaw.sh
chmod +x /opt/status-openclaw.sh
chmod +x /opt/update-openclaw.sh
chmod +x /opt/openclaw-cli.sh
chmod +x /opt/setup-openclaw-domain.sh
chmod +x /opt/openclaw-tui.sh

# Build Openclaw as openclaw user
cd /opt/openclaw
su - openclaw -c "cd /opt/openclaw && pnpm install --frozen-lockfile"
su - openclaw -c "cd /opt/openclaw && pnpm build"
su - openclaw -c "cd /opt/openclaw && pnpm ui:install"
su - openclaw -c "cd /opt/openclaw && pnpm ui:build"

# Build the sandbox image
cd /opt/openclaw
bash scripts/sandbox-setup.sh || echo "Warning: Sandbox image build failed, will be built on first use"

# Enable but don't start the service yet (will start after onboot configuration)
systemctl enable openclaw

mkdir -p /home/openclaw/.npm
chown -R openclaw /home/openclaw/.npm
su - openclaw -c "npm config set prefix /home/openclaw/.npm"

# Update MOTD with current dashboard URL and tools
echo "Updating Message of the Day (MOTD)..."
myip=$(hostname -I | awk '{print$1}')
gateway_token=$(grep "^OPENCLAW_GATEWAY_TOKEN=" /opt/openclaw.env 2>/dev/null | cut -d'=' -f2)

cat > /etc/update-motd.d/99-one-click << 'MOTDEOF'
#!/bin/sh
#
# Configured as part of the DigitalOcean 1-Click Image build process

myip=$(hostname -I | awk '{print$1}')
gateway_token=$(grep "^OPENCLAW_GATEWAY_TOKEN=" /opt/openclaw.env 2>/dev/null | cut -d'=' -f2)

cat <<EOF
********************************************************************************

Welcome to OpenClaw - Your Personal AI Assistant

OpenClaw is a personal AI assistant you run on your own devices. It answers you
on the channels you already use (WhatsApp, Telegram, Slack, Discord, and more).

🌐 Control UI & Gateway Access:
  Dashboard URL: https://$myip?token=$gateway_token
  Gateway Token: $gateway_token

📝 Configuration:
  Edit settings: /opt/openclaw.env
  User config: /home/openclaw/.openclaw/openclaw.json
  
🔧 Management Commands:
  Restart service: systemctl restart openclaw
  Check status: systemctl status openclaw
  View logs: journalctl -u openclaw -f
  
  Or use helper scripts:
  - /opt/restart-openclaw.sh   (restart with status check)
  - /opt/status-openclaw.sh    (show status and token)
  - /opt/update-openclaw.sh    (update to latest version)
  - /opt/openclaw-cli.sh       (run CLI commands)
  - /opt/openclaw-tui.sh       (launch TUI interface)

🔒 Enable HTTPS (TLS):
  Point your domain to this droplet, then run:
  sudo /opt/setup-openclaw-domain.sh
  
  This configures Caddy with Let's Encrypt SSL certificates.

📱 Configure Messaging Channels:
  1. Edit /opt/openclaw.env with your channel tokens
  2. Or use CLI: /opt/openclaw-cli.sh channels add
  3. Restart: systemctl restart openclaw

📚 Documentation: https://docs.clawd.bot/
🔗 GitHub: https://github.com/openclaw/openclaw

🔧 You can launch OpenClaw TUI using:
  $ /opt/openclaw-tui.sh

********************************************************************************
To delete this message of the day: rm -rf \$(readlink -f \${0})
EOF
MOTDEOF

chmod +x /etc/update-motd.d/99-one-click

echo "MOTD updated successfully"
echo "Dashboard URL: https://$myip?token=$gateway_token"

systemctl restart ssh
systemctl restart openclaw
systemctl restart caddy 2>/dev/null || true