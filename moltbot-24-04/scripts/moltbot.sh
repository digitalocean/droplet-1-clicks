#!/bin/sh

# Open required ports
ufw allow 80
ufw allow 443
ufw allow 18789
ufw limit ssh/tcp
ufw --force enable

# Install Caddy for reverse proxy with automatic HTTPS
apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt-get update
apt-get install -y caddy

# Install Node.js 22 (required for Moltbot)
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs

# Enable and configure corepack for pnpm
corepack enable
corepack prepare pnpm@latest --activate

# Create moltbot user
useradd -m -s /bin/bash moltbot || true

# Clone the Moltbot repository
cd /opt && git clone https://github.com/moltbot/moltbot.git

# Set ownership
chown -R moltbot:moltbot /opt/moltbot

# Create moltbot home directory and config directory
mkdir -p /home/moltbot/.moltbot
mkdir -p /home/moltbot/molt
chown -R moltbot:moltbot /home/moltbot/.moltbot
chown -R moltbot:moltbot /home/moltbot/molt

# Create environment file (will be configured on first boot)
cat > /opt/moltbot.env << 'EOF'
# Moltbot Environment Configuration
# 
# After making changes to this file, restart Moltbot with:
#   systemctl restart moltbot

# Gateway Configuration
MOLTBOT_GATEWAY_PORT=18789
MOLTBOT_GATEWAY_BIND=lan

# Gateway token will be auto-generated on first boot
MOLTBOT_GATEWAY_TOKEN=PLACEHOLDER_WILL_BE_REPLACED_ON_FIRST_BOOT

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
cat > /etc/systemd/system/moltbot.service << 'EOF'
[Unit]
Description=Moltbot Gateway Service
After=network-online.target docker.service
Wants=network-online.target
Requires=docker.service

[Service]
Type=simple
User=moltbot
Group=moltbot
WorkingDirectory=/opt/moltbot
EnvironmentFile=/opt/moltbot.env
Environment="HOME=/home/moltbot"
Environment="NODE_ENV=production"
Environment="PATH=/usr/local/bin:/usr/bin:/bin"

# Start command - uses the gateway executable with allow-unconfigured for initial setup
ExecStart=/usr/bin/node /opt/moltbot/dist/index.js gateway --port ${MOLTBOT_GATEWAY_PORT} --bind ${MOLTBOT_GATEWAY_BIND} --allow-unconfigured

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
cat > /opt/restart-moltbot.sh << 'EOF'
#!/bin/bash
echo "Restarting Moltbot Gateway..."
systemctl restart moltbot

# Wait a moment for the service to start
sleep 2

# Check status
if systemctl is-active --quiet moltbot; then
    echo "✅ Moltbot restarted successfully!"
    echo "Gateway is running on port 18789"
    echo "View logs with: journalctl -u moltbot -f"
else
    echo "❌ Error: Failed to restart Moltbot"
    echo "Check logs with: journalctl -u moltbot -xe"
    exit 1
fi
EOF

# Create status check script
cat > /opt/status-moltbot.sh << 'EOF'
#!/bin/bash
echo "=== Moltbot Gateway Status ==="
systemctl status moltbot --no-pager

echo ""
echo "=== Gateway Access ==="
myip=$(hostname -I | awk '{print$1}')
if [ -f "/opt/moltbot.env" ]; then
    token=$(grep "^MOLTBOT_GATEWAY_TOKEN=" /opt/moltbot.env | cut -d'=' -f2)
    echo "Gateway URL (with token):"
    echo "  http://$myip:18789?token=$token"
    echo ""
    echo "Or for localhost (via SSH tunnel):"
    echo "  http://localhost:18789?token=$token"
    echo ""
    echo "Token only: $token"
else
    echo "Token not yet generated. Run the onboot script."
fi
EOF

# Create update script
cat > /opt/update-moltbot.sh << 'EOF'
#!/bin/bash

# Moltbot Update Script
# This script pulls the latest Moltbot code from GitHub and restarts the service

echo "Updating Moltbot to latest version..."

# Check if Moltbot installation exists
if [ ! -d "/opt/moltbot" ]; then
    echo "Error: Moltbot installation directory not found at /opt/moltbot"
    exit 1
fi

# Stop the service
echo "Stopping Moltbot service..."
systemctl stop moltbot

# Navigate to Moltbot directory
cd /opt/moltbot

# Stash any local changes
git stash

# Pull latest code from GitHub
echo "Pulling latest code from GitHub..."
git pull origin main

# Check if there were any updates
if [ $? -eq 0 ]; then
    echo "Code updated successfully. Rebuilding..."
    
    # Install dependencies and rebuild as moltbot user
    su - moltbot -c "cd /opt/moltbot && pnpm install --frozen-lockfile"
    su - moltbot -c "cd /opt/moltbot && pnpm build"
    su - moltbot -c "cd /opt/moltbot && pnpm ui:install"
    su - moltbot -c "cd /opt/moltbot && pnpm ui:build"
    
    # Check if build was successful
    if [ $? -eq 0 ]; then
        # Restart Moltbot
        echo "Starting Moltbot with updated code..."
        systemctl start moltbot
        
        if [ $? -eq 0 ]; then
            echo "✅ Moltbot updated and restarted successfully!"
        else
            echo "❌ Error: Failed to restart Moltbot"
            exit 1
        fi
    else
        echo "❌ Error: Failed to rebuild Moltbot"
        exit 1
    fi
else
    echo "ℹ️  No updates available or update failed."
fi

echo "Update process completed."
EOF

# Create CLI helper script
cat > /opt/moltbot-cli.sh << 'EOF'
#!/bin/bash
# Helper script to run Moltbot CLI commands as the moltbot user
su - moltbot -c "cd /opt/moltbot && node dist/index.js $*"
EOF

# Create HTTPS setup script
cat > /opt/enable-https-moltbot.sh << 'EOF'
#!/bin/bash

# Moltbot HTTPS Setup Script
# This script configures Caddy reverse proxy with automatic Let's Encrypt SSL

set -e

echo "=== Moltbot HTTPS Setup ==="
echo ""
echo "This script will configure Caddy reverse proxy with automatic Let's Encrypt SSL."
echo "Before continuing, ensure:"
echo "  1. You have a domain name pointed to this server's IP"
echo "  2. DNS propagation is complete (check with: dig +short yourdomain.com)"
echo "  3. Ports 80 and 443 are open (already configured by this 1-Click)"
echo ""

read -p "Enter your domain name (e.g., moltbot.example.com): " DOMAIN

if [ -z "$DOMAIN" ]; then
    echo "Error: Domain name is required"
    exit 1
fi

echo ""
echo "Using domain: $DOMAIN"
echo ""

# Create Caddyfile
cat > /etc/caddy/Caddyfile << CADDY_EOF
$DOMAIN {
    reverse_proxy localhost:18789
    
    # Enable WebSocket support
    @websocket {
        header Connection *Upgrade*
        header Upgrade websocket
    }
    reverse_proxy @websocket localhost:18789
}
CADDY_EOF

# Update Moltbot to bind to localhost since Caddy will handle external access
sed -i 's/MOLTBOT_GATEWAY_BIND=lan/MOLTBOT_GATEWAY_BIND=loopback/' /opt/moltbot.env

# Reload Caddy and restart Moltbot
echo "Reloading Caddy configuration..."
systemctl reload caddy

echo "Restarting Moltbot..."
systemctl restart moltbot

# Wait for services
sleep 3

# Check status
if systemctl is-active --quiet caddy && systemctl is-active --quiet moltbot; then
    echo ""
    echo "✅ HTTPS setup complete!"
    echo ""
    echo "Your Moltbot Gateway is now accessible at:"
    echo "  https://$DOMAIN"
    echo ""
    echo "Caddy will automatically obtain and renew Let's Encrypt SSL certificates."
    echo ""
    echo "Note: It may take a few moments for the SSL certificate to be issued."
    echo "If you see a certificate error, wait 30 seconds and refresh."
else
    echo ""
    echo "❌ Error: Services failed to start"
    echo "Check Caddy logs: journalctl -u caddy -n 50"
    echo "Check Moltbot logs: journalctl -u moltbot -n 50"
    exit 1
fi
EOF

# Make all scripts executable
chmod +x /opt/restart-moltbot.sh
chmod +x /opt/status-moltbot.sh
chmod +x /opt/update-moltbot.sh
chmod +x /opt/moltbot-cli.sh
chmod +x /opt/enable-https-moltbot.sh

# Build Moltbot as moltbot user
cd /opt/moltbot
su - moltbot -c "cd /opt/moltbot && pnpm install --frozen-lockfile"
su - moltbot -c "cd /opt/moltbot && pnpm build"
su - moltbot -c "cd /opt/moltbot && pnpm ui:install"
su - moltbot -c "cd /opt/moltbot && pnpm ui:build"

# Build the sandbox image
cd /opt/moltbot
bash scripts/sandbox-setup.sh || echo "Warning: Sandbox image build failed, will be built on first use"

# Enable but don't start the services yet (will start after onboot configuration)
systemctl enable moltbot
systemctl enable caddy
