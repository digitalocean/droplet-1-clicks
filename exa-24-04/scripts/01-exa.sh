#!/bin/bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "==> Updating package repository..."
apt-get update && apt-get upgrade -y

echo "==> Installing Node.js and dependencies..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs git unzip curl

echo "==> Installing the Exa MCP Server globally..."
npm install -g exa-mcp-server

echo "==> Creating Exa config directory..."
mkdir -p /etc/exa /var/lib/digitalocean
chmod 700 /etc/exa

echo "==> Setting up first-boot configuration hook..."
cat <<'EOF' > /var/lib/digitalocean/one-click-login-check.sh
#!/bin/bash
if [ ! -f /etc/exa/.configured ]; then
    echo "================================================================"
    echo "       Welcome to the Exa MCP Server 1-Click Droplet!           "
    echo "================================================================"
    echo ""
    echo "To get started, you need an API key from Exa."
    echo "If you don't have one, grab one here: https://dashboard.exa.ai/"
    echo ""
    read -p "Please enter your Exa API Key: " EXA_KEY
    
    if [ -z "$EXA_KEY" ]; then
        echo "Exa API key is required to start the MCP server."
        exit 1
    fi
    
    mkdir -p /etc/exa
    chmod 700 /etc/exa
    umask 077
    echo "EXA_API_KEY=$EXA_KEY" > /etc/exa/mcp.env
    chmod 600 /etc/exa/mcp.env
    touch /etc/exa/.configured
    
    echo "==> Restarting Exa MCP service..."
    systemctl restart exa-mcp
    echo "Exa MCP Server is successfully configured and running!"
fi
EOF

chmod +x /var/lib/digitalocean/one-click-login-check.sh

# Inject first-boot hook into root's .bashrc
echo "/var/lib/digitalocean/one-click-login-check.sh" >> /root/.bashrc

echo "==> Creating systemd service for Exa MCP Server..."
cat <<EOF > /etc/systemd/system/exa-mcp.service
[Unit]
Description=Exa Web Search MCP Server
After=network.target

[Service]
Type=simple
EnvironmentFile=-/etc/exa/mcp.env
ExecStart=/usr/bin/npx -y exa-mcp-server
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable exa-mcp

echo "==> Cleaning up setup environment..."
apt-get autoremove -y
apt-get clean