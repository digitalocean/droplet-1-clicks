#!/bin/bash
#
# First-login notice: localhost SSH trust was configured on first boot.
# Kept as a one-shot bashrc hook for awareness; no interactive activation.

set -e

# Already shown / cleaned up
if [ -f /root/.coolify_localhost_notice_shown ]; then
    sed -i '/coolify_localhost_setup.sh/d' /root/.bashrc 2>/dev/null || true
    exit 0
fi

# Non-interactive sessions (scp, ansible, CI): clean hook and exit — do not block
if [ ! -t 0 ] || [ ! -t 1 ]; then
    touch /root/.coolify_localhost_notice_shown
    touch /root/.coolify_localhost_configured
    sed -i '/coolify_localhost_setup.sh/d' /root/.bashrc 2>/dev/null || true
    exit 0
fi

myip=$(hostname -I | awk '{print$1}')

clear
cat << EOF
================================================================================
                     Coolify Localhost Ready
================================================================================

Welcome to your Coolify droplet!

Localhost SSH trust was configured automatically on first boot:
  • Key: /data/coolify/ssh/keys/id.root@host.docker.internal
  • Authorized in /root/.ssh/authorized_keys
  • SSH port for Validate: 22 (not 8000 or 8080)

Access Coolify at: http://${myip}:8000

IMPORTANT:
  1. Create your admin account immediately
  2. Servers → localhost → SSH port must be 22
  3. Onboarding "ssh -i … root@localhost" must succeed; if not:
       /opt/configure-coolify-localhost.sh

Note: Deploying apps on the same host as Coolify can cause resource
contention; add remote servers for production workloads.

================================================================================
EOF

# Mark done before optional prompt so Ctrl-D / errors cannot re-trigger the hook
touch /root/.coolify_localhost_notice_shown
touch /root/.coolify_localhost_configured
sed -i '/coolify_localhost_setup.sh/d' /root/.bashrc 2>/dev/null || true

echo ""
read -r -p "Press ENTER to continue..." || true
clear
