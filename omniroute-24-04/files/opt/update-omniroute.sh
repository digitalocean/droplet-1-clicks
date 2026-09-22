#!/bin/bash
set -euo pipefail

# Update OmniRoute Docker image.
# Usage:
#   /opt/update-omniroute.sh              # pull latest (or current OMNIROUTE_IMAGE tag)
#   /opt/update-omniroute.sh 3.8.50       # pin a SemVer tag
#   /opt/update-omniroute.sh latest       # explicit latest

ENV_FILE=/opt/omniroute/.env
TARGET="${1:-}"

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing ${ENV_FILE}" >&2
  exit 1
fi

if [ -n "$TARGET" ]; then
  NEW_IMAGE="diegosouzapw/omniroute:${TARGET}"
  if grep -q '^OMNIROUTE_IMAGE=' "$ENV_FILE"; then
    sed -i "s|^OMNIROUTE_IMAGE=.*|OMNIROUTE_IMAGE=${NEW_IMAGE}|" "$ENV_FILE"
  else
    echo "OMNIROUTE_IMAGE=${NEW_IMAGE}" >> "$ENV_FILE"
  fi
  echo "Set OMNIROUTE_IMAGE=${NEW_IMAGE}"
fi

/opt/omniroute/run.sh upgrade
systemctl restart caddy || true
echo "OmniRoute update complete."
/opt/status-omniroute.sh
