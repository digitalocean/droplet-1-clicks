#!/bin/bash

# Report real Plex health (systemd oneshot + Docker container)

echo "=== systemd ==="
systemctl is-active plex caddy docker fail2ban 2>/dev/null || true
systemctl status plex --no-pager -l | head -12

echo ""
echo "=== docker container ==="
if docker ps --filter name=^plex$ --format '{{.Names}} {{.Status}}' | grep -q .; then
    docker ps --filter name=^plex$ --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
else
    echo "plex container is not running"
    exit 1
fi

echo ""
echo "=== claim / proxy ==="
PUBLIC_IP="$(/opt/plex-get-public-ip.sh)"
PREFS="/opt/plex/config/Library/Application Support/Plex Media Server/Preferences.xml"
if [ -f /opt/plex/.claimed ] && [ -f "${PREFS}" ] && grep -qE 'PlexOnlineToken="[^"]+"' "${PREFS}"; then
    echo "Claimed: yes (HTTPS reverse proxy enabled)"
elif [ -f "${PREFS}" ] && grep -qE 'PlexOnlineToken="[^"]+"' "${PREFS}"; then
    echo "Claimed: yes (Preferences token present; run /opt/enable-plex-proxy.sh if HTTPS still pending)"
else
    echo "Claimed: no (setup-pending page active; run claim or enable-plex-proxy.sh)"
fi

echo ""
echo "=== endpoints ==="
curl -skI "https://${PUBLIC_IP}/" 2>/dev/null | head -3 || echo "HTTPS via Caddy: not ready yet"
curl -sI "http://127.0.0.1:32400/web" 2>/dev/null | head -3 || echo "Plex local: not ready yet"
