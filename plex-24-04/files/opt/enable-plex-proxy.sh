#!/bin/bash
set -euo pipefail

# Switch from setup-pending Caddy page to reverse-proxying Plex,
# and publish port 32400 publicly for remote access.
#
# Usage:
#   /opt/enable-plex-proxy.sh           # requires a claimed server
#   /opt/enable-plex-proxy.sh --force   # skip claim verification

CLAIMED_MARKER=/opt/plex/.claimed
COMPOSE=/opt/plex/docker-compose.yml
PREFS="/opt/plex/config/Library/Application Support/Plex Media Server/Preferences.xml"
FORCE=false

if [ "${1:-}" = "--force" ]; then
  FORCE=true
elif [ -n "${1:-}" ]; then
  echo "Usage: $0 [--force]"
  exit 1
fi

plex_is_claimed() {
  # Non-empty PlexOnlineToken means the server is linked to a Plex account
  [ -f "${PREFS}" ] && grep -qE 'PlexOnlineToken="[^"]+"' "${PREFS}"
}

if [ "${FORCE}" != true ]; then
  if ! plex_is_claimed; then
    # Brief wait — claim-token flow may still be writing Preferences.xml
    for _ in 1 2 3 4 5; do
      if plex_is_claimed; then
        break
      fi
      sleep 2
    done
  fi

  if ! plex_is_claimed; then
    echo "Plex does not appear to be claimed yet (missing PlexOnlineToken in Preferences.xml)."
    echo ""
    echo "Claim first, then re-run this script:"
    echo "  sudo /opt/claim-plex.sh claim-XXXXXXXX"
    echo "  # or SSH-tunnel claim, then: sudo /opt/enable-plex-proxy.sh"
    echo ""
    echo "To override (reopens public claim risk): sudo /opt/enable-plex-proxy.sh --force"
    exit 1
  fi
else
  echo "WARNING: --force skips claim verification; public claim bypass may be possible if unclaimed."
fi

if [ ! -f /etc/caddy/Caddyfile.tmp ]; then
  echo "Error: /etc/caddy/Caddyfile.tmp not found"
  exit 1
fi

PUBLIC_IP="$(/opt/plex-get-public-ip.sh)"

# Publish Plex on all interfaces for remote access / clients
sed -i 's|"127.0.0.1:32400:32400/tcp"|"32400:32400/tcp"|g' "${COMPOSE}"

# Activate shortlived TLS reverse proxy for this Droplet IP
sed "s/PLACEHOLDER_DOMAIN/${PUBLIC_IP}/" /etc/caddy/Caddyfile.tmp > /etc/caddy/Caddyfile

# Keep advertise URL on the direct Plex port (not Caddy :443)
if [ -f /opt/plex/.env ]; then
  if grep -q '^ADVERTISE_IP=' /opt/plex/.env; then
    sed -i "s|^ADVERTISE_IP=.*|ADVERTISE_IP=http://${PUBLIC_IP}:32400/|" /opt/plex/.env
  else
    echo "ADVERTISE_IP=http://${PUBLIC_IP}:32400/" >> /opt/plex/.env
  fi
else
  echo "ADVERTISE_IP=http://${PUBLIC_IP}:32400/" > /opt/plex/.env
fi

touch "${CLAIMED_MARKER}"

systemctl enable caddy
systemctl restart plex
systemctl restart caddy

echo "Plex HTTPS proxy enabled."
echo "  Web (Caddy):  https://${PUBLIC_IP}"
echo "  Direct:       http://${PUBLIC_IP}:32400/web"
echo ""
echo "For a custom domain: sudo /opt/setup-plex-domain.sh"
