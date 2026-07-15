#!/bin/bash

set -e

# Claim this Plex server with a token from https://www.plex.tv/claim
# Tokens expire in about 4 minutes.

if [ -z "$1" ]; then
  echo "Usage: $0 <claim-token>"
  echo ""
  echo "1. Open https://www.plex.tv/claim and copy the token"
  echo "2. Run: /opt/claim-plex.sh claim-XXXXXXXX"
  echo ""
  echo "Alternative (local claim via SSH tunnel from your laptop):"
  echo "  ssh -L 8888:127.0.0.1:32400 root@\$(hostname -I | awk '{print \$1}')"
  echo "  Then open http://localhost:8888/web"
  exit 1
fi

CLAIM_TOKEN="$1"
PUBLIC_IP=$(curl -fsSL http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null || hostname -I | awk '{print $1}')

cd /opt/plex

cat > .env <<EOF
ADVERTISE_IP=http://${PUBLIC_IP}:32400/
PLEX_CLAIM=${CLAIM_TOKEN}
EOF

echo "Restarting Plex with claim token..."
systemctl restart plex
sleep 8

# Clear claim token after restart (one-time use)
sed -i '/^PLEX_CLAIM=/d' .env
systemctl restart plex

echo "Claim applied. Open: http://${PUBLIC_IP}:32400/web"
echo "If the UI still asks to claim, wait ~30s and refresh, or use the SSH tunnel method."
