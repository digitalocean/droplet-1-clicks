#!/bin/bash

set -euo pipefail

echo "Starting NemoClaw setup wizard"

# Packer/umask may leave this 0755; onboard requires owner-private 0700.
mkdir -p /root/.nemoclaw
chmod 700 /root/.nemoclaw

# CVE-2026-111497: host Node is patched at Packer time; sandbox Node comes from
# a managed GHCR image and is injected in-place after onboard.
# shellcheck disable=SC1091
[ -f /etc/profile.d/nemoclaw-sandbox-node.sh ] && . /etc/profile.d/nemoclaw-sandbox-node.sh
export NODE_CVE_MIN="${NODE_CVE_MIN:-24.22.1}"

if [ -x /opt/patch-nemoclaw-sandbox-node.sh ]; then
  /opt/patch-nemoclaw-sandbox-node.sh patch "${HOME}/.nemoclaw/source"
fi

nemoclaw onboard

# Overlay Node 24.22.1 into the running sandbox (no container recreate).
if [ -x /opt/patch-nemoclaw-sandbox-node.sh ]; then
  /opt/patch-nemoclaw-sandbox-node.sh remediate-sandbox
fi

cp /etc/skel/.bashrc /root

echo "You may now connect to your NemoClaw instance using 'nemoclaw <your sandbox> connect' and then connect to OpenClaw using 'openclaw tui'"
