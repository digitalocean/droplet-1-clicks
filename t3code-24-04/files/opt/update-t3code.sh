#!/bin/bash
# Update the T3 Code server to the newest stable release and restart it.
# Provider CLIs stay on the versions baked into the image until you update them.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

echo "Updating T3 Code..."
runuser -u t3 -- env HOME=/home/t3 T3CODE_HOME=/home/t3/.t3 \
  bash -lc 't3 update --yes'
systemctl restart t3code
echo "T3 Code updated and restarted."
echo "Provider CLIs are unchanged. Reinstall a provider with its official installer if you want a newer build."
