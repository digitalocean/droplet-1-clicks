#!/bin/sh

APP_VERSION="${application_version:-Latest}"
REPO_URL="https://github.com/clawdbot/clawdbot.git"
REPO_DIR="/opt/clawdbot"

# Open required ports
ufw allow 80
ufw allow 443
ufw allow 18789
ufw limit ssh/tcp
ufw --force enable

# Install Node.js 22 (required for Clawdbot)
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs

# Enable and configure corepack for pnpm
corepack enable
corepack prepare pnpm@latest --activate

# Create clawdbot user
useradd -m -s /bin/bash clawdbot || true

# Clone the Clawdbot repository
cd /opt && git clone "$REPO_URL" "$REPO_DIR"
cd "$REPO_DIR"
git fetch --tags
if [ "$APP_VERSION" != "Latest" ]; then
    git checkout "$APP_VERSION"
fi

# Set ownership
chown -R clawdbot:clawdbot "$REPO_DIR"

# Create clawdbot home directory and config directory
mkdir -p /home/clawdbot/.clawdbot
mkdir -p /home/clawdbot/clawd
chown -R clawdbot:clawdbot /home/clawdbot/.clawdbot
chown -R clawdbot:clawdbot /home/clawdbot/clawd

# Create environment file (will be configured on first boot)
cat > /opt/clawdbot.env << EOF
# Clawdbot Environment Configuration
# 
# After making changes to this file, restart Clawdbot with:
#   systemctl restart clawdbot

# Installed Clawdbot version
CLAWDBOT_VERSION=${APP_VERSION}

# Gateway Configuration
CLAWDBOT_GATEWAY_PORT=18789
CLAWDBOT_GATEWAY_BIND=lan

# Gateway token will be auto-generated on first boot
CLAWDBOT_GATEWAY_TOKEN=PLACEHOLDER_WILL_BE_REPLACED_ON_FIRST_BOOT

# Model Configuration
# Uncomment and configure your preferred AI model provider
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
cat > /etc/systemd/system/clawdbot.service << 'EOF'
[Unit]
Description=Clawdbot Gateway Service
After=network-online.target docker.service
Wants=network-online.target
Requires=docker.service

[Service]
Type=simple
User=clawdbot
Group=clawdbot
WorkingDirectory=/opt/clawdbot
EnvironmentFile=/opt/clawdbot.env
Environment="HOME=/home/clawdbot"
Environment="NODE_ENV=production"
Environment="PATH=/usr/local/bin:/usr/bin:/bin"

# Start command - uses the gateway executable with allow-unconfigured for initial setup
ExecStart=/usr/bin/node /opt/clawdbot/dist/index.js gateway --port ${CLAWDBOT_GATEWAY_PORT} --bind ${CLAWDBOT_GATEWAY_BIND} --allow-unconfigured

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

# Create restart helper script
cat > /opt/restart-clawdbot.sh << 'EOF'
#!/bin/bash
echo "Restarting Clawdbot Gateway..."
systemctl restart clawdbot

# Wait a moment for the service to start
sleep 2

# Check status
if systemctl is-active --quiet clawdbot; then
    echo "✅ Clawdbot restarted successfully!"
    echo "Gateway is running on port 18789"
    echo "View logs with: journalctl -u clawdbot -f"
else
    echo "❌ Error: Failed to restart Clawdbot"
    echo "Check logs with: journalctl -u clawdbot -xe"
    exit 1
fi
EOF

# Create status check script
cat > /opt/status-clawdbot.sh << 'EOF'
#!/bin/bash
echo "=== Clawdbot Gateway Status ==="
systemctl status clawdbot --no-pager

echo ""
echo "=== Gateway Token ==="
if [ -f "/opt/clawdbot.env" ]; then
    grep "^CLAWDBOT_GATEWAY_TOKEN=" /opt/clawdbot.env | cut -d'=' -f2
else
    echo "Token not yet generated. Run the onboot script."
fi

echo ""
echo "=== Gateway URL ==="
myip=$(hostname -I | awk '{print$1}')
echo "http://$myip:18789"
EOF

# Create update script
cat > /opt/update-clawdbot.sh << 'EOF'
#!/bin/bash

# Clawdbot Update Script
# This script pulls the desired Clawdbot version from GitHub and restarts the service

APP_VERSION="Latest"
if [ -f "/opt/clawdbot.env" ]; then
    APP_VERSION_VALUE=$(grep -E '^CLAWDBOT_VERSION=' /opt/clawdbot.env | tail -n 1 | cut -d'=' -f2-)
    if [ -n "$APP_VERSION_VALUE" ]; then
        APP_VERSION="$APP_VERSION_VALUE"
    fi
fi

echo "Updating Clawdbot (target version: ${APP_VERSION})..."

# Check if Clawdbot installation exists
if [ ! -d "/opt/clawdbot" ]; then
    echo "Error: Clawdbot installation directory not found at /opt/clawdbot"
    exit 1
fi

# Stop the service
echo "Stopping Clawdbot service..."
systemctl stop clawdbot

cd /opt/clawdbot

# Stash any local changes
git stash

echo "Fetching updates from GitHub..."
git fetch --tags --all

if [ "$APP_VERSION" = "Latest" ]; then
    TARGET_REF="main"
    echo "Checking out branch ${TARGET_REF}..."
    git checkout "${TARGET_REF}"
    echo "Pulling latest code from ${TARGET_REF}..."
    git pull origin "${TARGET_REF}"
else
    TARGET_REF="$APP_VERSION"
    echo "Checking out tagged release ${TARGET_REF}..."
    git checkout "${TARGET_REF}"
    git reset --hard "${TARGET_REF}"
fi

if [ $? -eq 0 ]; then
    echo "Code updated successfully. Rebuilding..."
    
    # Install dependencies and rebuild as clawdbot user
    su - clawdbot -c "cd /opt/clawdbot && pnpm install --frozen-lockfile"
    su - clawdbot -c "cd /opt/clawdbot && pnpm build"
    su - clawdbot -c "cd /opt/clawdbot && pnpm ui:install"
    su - clawdbot -c "cd /opt/clawdbot && pnpm ui:build"
    
    # Check if build was successful
    if [ $? -eq 0 ]; then
        # Restart Clawdbot
        echo "Starting Clawdbot with updated code..."
        systemctl start clawdbot
        
        if [ $? -eq 0 ]; then
            echo "✅ Clawdbot updated and restarted successfully!"
        else
            echo "❌ Error: Failed to restart Clawdbot"
            exit 1
        fi
    else
        echo "❌ Error: Failed to rebuild Clawdbot"
        exit 1
    fi
else
    echo "ℹ️  No updates available or update failed."
fi

echo "Update process completed."
EOF

# Create CLI helper script
cat > /opt/clawdbot-cli.sh << 'EOF'
#!/bin/bash
# Helper script to run Clawdbot CLI commands as the clawdbot user
su - clawdbot -c "cd /opt/clawdbot && node dist/index.js $*"
EOF

# Make all scripts executable
chmod +x /opt/restart-clawdbot.sh
chmod +x /opt/status-clawdbot.sh
chmod +x /opt/update-clawdbot.sh
chmod +x /opt/clawdbot-cli.sh

# Build Clawdbot as clawdbot user
cd /opt/clawdbot
su - clawdbot -c "cd /opt/clawdbot && pnpm install --frozen-lockfile"
su - clawdbot -c "cd /opt/clawdbot && pnpm build"
su - clawdbot -c "cd /opt/clawdbot && pnpm ui:install"
su - clawdbot -c "cd /opt/clawdbot && pnpm ui:build"

# Build the sandbox image
cd /opt/clawdbot
bash scripts/sandbox-setup.sh || echo "Warning: Sandbox image build failed, will be built on first use"

# Enable but don't start the service yet (will start after onboot configuration)
systemctl enable clawdbot
