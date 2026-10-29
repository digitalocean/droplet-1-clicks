#!/bin/bash
#
# DigitalOcean monitoring agent (droplet graphs + alerting). No official Arch
# package: install the prebuilt binary from the pinned release tarball, which
# ships the /opt layout and systemd unit. The deb/rpm postinstall normally
# creates the service user; do it ourselves.
set -euo pipefail

DO_AGENT_VERSION="3.18.14"

echo "==> Installing do-agent ${DO_AGENT_VERSION}"
curl -fsSL "https://github.com/digitalocean/do-agent/releases/download/${DO_AGENT_VERSION}/do-agent.${DO_AGENT_VERSION}.tar.gz" -o /tmp/do-agent.tgz
sudo tar xzf /tmp/do-agent.tgz -C / --exclude "./usr/share/doc"
rm -f /tmp/do-agent.tgz
sudo useradd -r -M -s /usr/bin/nologin do-agent 2>/dev/null || true
sudo systemctl daemon-reload
sudo systemctl enable do-agent.service
VER=$(/opt/digitalocean/bin/do-agent --version 2>&1) && echo "${VER%%$'\n'*}"

echo "==> do-agent OK"
