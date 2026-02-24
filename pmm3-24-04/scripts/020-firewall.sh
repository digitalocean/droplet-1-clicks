#!/bin/bash
set -e

# Configure firewall for PMM3
echo "Configuring firewall for PMM3..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp   # SSH
ufw allow 80/tcp   # PMM3 Web Interface (HTTP)
ufw allow 443/tcp  # PMM3 Web Interface (HTTPS)
ufw --force enable

# Install and configure fail2ban
echo "Configuring fail2ban..."
apt-get install -y fail2ban
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
EOF

systemctl enable fail2ban
systemctl restart fail2ban

echo "Firewall configuration completed." 