#!/bin/bash

set -euo pipefail

# Claim this Plex server with a token from https://www.plex.tv/claim
# Tokens expire in about 4 minutes.

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <claim-token>"
  echo ""
  echo "1. Open https://www.plex.tv/claim and copy the token"
  echo "2. Run: /opt/claim-plex.sh claim-XXXXXXXX"
  echo ""
  echo "Alternative (local claim via SSH tunnel from your laptop):"
  PUBLIC_IP="$(/opt/plex-get-public-ip.sh 2>/dev/null || hostname -I | awk '{print $1}')"
  echo "  ssh -L 8888:127.0.0.1:32400 root@${PUBLIC_IP}"
  echo "  Then open http://localhost:8888/web"
  echo "  After claiming, run: sudo /opt/enable-plex-proxy.sh"
  exit 1
fi

CLAIM_TOKEN="$1"
PUBLIC_IP="$(/opt/plex-get-public-ip.sh)"

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
sleep 3

# Unlock public HTTPS proxy + remote-access port only after claim
# Retries briefly while Preferences.xml is written
if ! /opt/enable-plex-proxy.sh; then
  echo "Waiting for claim to appear in Preferences.xml..."
  sleep 5
  /opt/enable-plex-proxy.sh
fi

echo "Claim applied."
echo "If the UI still asks to claim, wait ~30s and refresh, or use the SSH tunnel method."
