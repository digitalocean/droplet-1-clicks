#!/bin/bash
echo "=== ZeroClaw Service Status ==="
systemctl status zeroclaw --no-pager

echo ""
echo "=== ZeroClaw Version ==="
/usr/local/bin/zeroclaw --version 2>/dev/null || echo "ZeroClaw binary not found"

echo ""
echo "=== Gateway URL ==="
myip=$(hostname -I | awk '{print$1}')
if grep -q "tls" /etc/caddy/Caddyfile 2>/dev/null; then
    echo "https://$myip (proxied via Caddy with TLS)"
else
    echo "http://$myip (proxied via Caddy)"
fi
echo "http://127.0.0.1:42617 (direct, localhost only)"

echo ""
echo "=== Quick Status ==="
su - zeroclaw -c "zeroclaw status" 2>/dev/null || echo "Run setup wizard first: sudo /etc/setup_wizard.sh"

echo ""
echo "=== Gateway Pairing Code ==="
su - zeroclaw -c "zeroclaw gateway get-paircode --new" 2>/dev/null \
  || echo "Run: /opt/zeroclaw-cli.sh gateway get-paircode --new"

echo ""
echo "=== CLI tip ==="
echo "/opt/zeroclaw-cli.sh agent -a assistant -m \"Hello\""
