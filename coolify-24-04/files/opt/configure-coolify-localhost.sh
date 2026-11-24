#!/bin/bash
#
# Coolify localhost repair / re-sync
# Restores SSH key files Coolify expects and re-authorizes them (port 22).

set -e

echo "=================================================="
echo "Coolify Localhost Server Repair"
echo "=================================================="
echo ""

ENV_FILE="/data/coolify/source/.env"
myip=$(hostname -I | awk '{print$1}')

# Check if Coolify is running
if ! systemctl is-active --quiet coolify 2>/dev/null && \
   ! docker compose --env-file "${ENV_FILE}" \
     -f /data/coolify/source/docker-compose.yml \
     -f /data/coolify/source/docker-compose.prod.yml \
     ps 2>/dev/null | grep -q "coolify"; then
    echo "Error: Coolify is not running."
    echo "Please start Coolify first: systemctl start coolify"
    exit 1
fi

chmod +x /opt/coolify-sync-localhost-ssh.sh
/opt/coolify-sync-localhost-ssh.sh

echo ""
echo "Reminder: Coolify UI is http://${myip}:8000 — SSH for Validate is always port 22."
echo "Do not set SSH port to 8000 or 8080."
echo ""
echo "Onboarding check (point 3):"
echo "  ssh -i /data/coolify/ssh/keys/id.root@host.docker.internal -o BatchMode=yes root@localhost true"
echo ""

touch /root/.coolify_localhost_configured

echo "=================================================="
echo "Localhost Repair Complete!"
echo "=================================================="
echo ""
echo "Next steps:"
echo "1. Open http://${myip}:8000"
echo "2. Onboarding / Servers → localhost → SSH port 22 → Check again"
echo "3. If still failing, paste the UI 'Current Public Key' into:"
echo "     /root/.ssh/authorized_keys"
echo "   then run this script once more."
echo ""
