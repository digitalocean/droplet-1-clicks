#!/bin/bash
#
# DigitalOcean droplet-agent: powers the control panel's in-browser web
# console. No Arch package; install the pinned release binary + the upstream
# systemd unit (release tarball ships only the bare binary).
set -euo pipefail

DROPLET_AGENT_VERSION="1.4.2"

echo "==> Installing droplet-agent ${DROPLET_AGENT_VERSION}"
curl -fsSL "https://github.com/digitalocean/droplet-agent/releases/download/${DROPLET_AGENT_VERSION}/droplet-agent_${DROPLET_AGENT_VERSION}_linux_amd64.tar.gz" -o /tmp/droplet-agent.tgz
sudo mkdir -p /opt/digitalocean/bin
mkdir -p /tmp/da-extract
tar xzf /tmp/droplet-agent.tgz -C /tmp/da-extract
sudo install -m 755 /tmp/da-extract/droplet-agent /opt/digitalocean/bin/droplet-agent
rm -rf /tmp/droplet-agent.tgz /tmp/da-extract
curl -fsSL "https://raw.githubusercontent.com/digitalocean/droplet-agent/${DROPLET_AGENT_VERSION}/packaging/syscfg/systemd/droplet-agent.service" | sudo tee /etc/systemd/system/droplet-agent.service >/dev/null
sudo systemctl daemon-reload
sudo systemctl enable droplet-agent.service
VER=$(/opt/digitalocean/bin/droplet-agent -version 2>&1 || true) && echo "${VER%%$'\n'*}"

echo "==> droplet-agent OK"
