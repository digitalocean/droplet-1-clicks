#!/bin/sh

APP_VERSION="${application_version:-Latest}"
REPO_URL="https://github.com/openclaw/openclaw.git"
REPO_DIR="/opt/openclaw"

# Open required ports
ufw allow 80
ufw allow 443
ufw limit ssh/tcp
ufw --force enable

# Install Node.js 22 (required for OpenClaw)
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs

# Enable and configure corepack for pnpm
corepack enable
corepack prepare pnpm@latest --activate

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

# Clone the OpenClaw repository
cd /opt && git clone "$REPO_URL" "$REPO_DIR"
cd "$REPO_DIR"
git fetch --tags
if [ "$APP_VERSION" != "Latest" ]; then
    git checkout "$APP_VERSION"
fi

# Set ownership
chown -R openclaw:openclaw "$REPO_DIR"

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

# Create restart helper script
cat > /opt/restart-openclaw.sh << 'EOF'
#!/bin/bash
echo "Restarting OpenClaw Gateway..."
systemctl restart openclaw

# Wait a moment for the service to start
sleep 2

# Check status
if systemctl is-active --quiet openclaw; then
    echo "✅ OpenClaw restarted successfully!"
    echo "Gateway is running on port 18789"
    echo "View logs with: journalctl -u openclaw -f"
else
    echo "❌ Error: Failed to restart OpenClaw"
    echo "Check logs with: journalctl -u openclaw -xe"
    exit 1
fi
EOF

# Create status check script
cat > /opt/status-openclaw.sh << 'EOF'
#!/bin/bash
echo "=== OpenClaw Gateway Status ==="
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

# Create update script
cat > /opt/update-openclaw.sh << 'EOF'
#!/bin/bash

# OpenClaw Update Script
# This script pulls the desired OpenClaw version from GitHub and restarts the service

APP_VERSION="Latest"
if [ -f "/opt/openclaw.env" ]; then
    APP_VERSION_VALUE=$(grep -E '^OPENCLAW_VERSION=' /opt/openclaw.env | tail -n 1 | cut -d'=' -f2-)
    if [ -n "$APP_VERSION_VALUE" ]; then
        APP_VERSION="$APP_VERSION_VALUE"
    fi
fi

echo "Updating OpenClaw (target version: ${APP_VERSION})..."

# Check if OpenClaw installation exists
if [ ! -d "/opt/openclaw" ]; then
    echo "Error: OpenClaw installation directory not found at /opt/openclaw"
    exit 1
fi

# Stop the service
echo "Stopping OpenClaw service..."
systemctl stop openclaw

cd /opt/openclaw

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
    
    # Install dependencies and rebuild as openclaw user
    su - openclaw -c "cd /opt/openclaw && pnpm install --frozen-lockfile"
    su - openclaw -c "cd /opt/openclaw && pnpm build"
    su - openclaw -c "cd /opt/openclaw && pnpm ui:build"
    
    # Check if build was successful
    if [ $? -eq 0 ]; then
        # Restart OpenClaw
        echo "Starting OpenClaw with updated code..."
        systemctl start openclaw
        
        if [ $? -eq 0 ]; then
            echo "✅ OpenClaw updated and restarted successfully!"
        else
            echo "❌ Error: Failed to restart OpenClaw"
            exit 1
        fi
    else
        echo "❌ Error: Failed to rebuild OpenClaw"
        exit 1
    fi
else
    echo "ℹ️  No updates available or update failed."
fi

echo "Update process completed."
EOF

# Create CLI helper script
cat > /opt/openclaw-cli.sh << 'EOF'
#!/bin/bash
# Helper script to run OpenClaw CLI commands as the openclaw user
su - openclaw -c "cd /opt/openclaw && node dist/index.js $*"
EOF

cat > /opt/openclaw-tui.sh << 'EOF'
gateway_token=$(grep "^OPENCLAW_GATEWAY_TOKEN=" /opt/openclaw.env 2>/dev/null | cut -d'=' -f2)

/opt/openclaw-cli.sh tui --token=${gateway_token}
EOF

# Create domain setup script
cat > /opt/setup-openclaw-domain.sh << 'EOF'
#!/bin/bash
set -euo pipefail

PORT=18789
BIND_IP=127.0.0.1

read -rp "Enter the domain you pointed at this droplet (e.g. bot.example.com): " DOMAIN
if [ -z "${DOMAIN}" ]; then
    echo "Domain cannot be empty."
    exit 1
fi

read -rp "Enter an email for Let's Encrypt notifications (optional): " EMAIL

if grep -q '^OPENCLAW_GATEWAY_BIND=' /opt/openclaw.env; then
    sed -i "s/^OPENCLAW_GATEWAY_BIND=.*/OPENCLAW_GATEWAY_BIND=${BIND_IP}/" /opt/openclaw.env
else
    echo "OPENCLAW_GATEWAY_BIND=${BIND_IP}" >> /opt/openclaw.env
fi

{
    cat > /etc/caddy/Caddyfile << CADDYEOC
${DOMAIN} {
    tls {
        issuer acme {
            dir https://acme-v02.api.letsencrypt.org/directory
            profile shortlived
        }
    }
    reverse_proxy ${BIND_IP}:${PORT}
}
CADDYEOC
    if [ -n "$EMAIL" ]; then
        # Prepend email directive for Let's Encrypt account binding
        sed -i "1iemail ${EMAIL}" /etc/caddy/Caddyfile
    fi
}

systemctl enable caddy
systemctl restart openclaw

echo "Caddy is now proxying https://${DOMAIN} to ${BIND_IP}:${PORT}."
echo "Gateway bind set to ${BIND_IP}. You can adjust /opt/openclaw.env and rerun this script if needed."
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
chmod +x /etc/token_setup.sh
chmod +x /opt/openclaw-tui.sh

# Build OpenClaw as openclaw user
cd /opt/openclaw
su - openclaw -c "cd /opt/openclaw && pnpm install --frozen-lockfile"
su - openclaw -c "cd /opt/openclaw && pnpm build"
su - openclaw -c "cd /opt/openclaw && pnpm ui:build"

# Build the sandbox image
cd /opt/openclaw
bash scripts/docker-setup.sh || echo "Warning: Sandbox image build failed, will be built on first use"

# Enable but don't start the service yet (will start after onboot configuration)
systemctl enable openclaw

su - openclaw -c "mkdir -p ~/homebrew && curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C ~/homebrew"
su - openclaw -c "~/homebrew/bin/brew install steipete/tap/wacli"
su - openclaw -c "~/homebrew/bin/brew link wacli"

chown -R openclaw /home/openclaw/.npm
su - openclaw -c "npm config set prefix /home/openclaw/.npm"
