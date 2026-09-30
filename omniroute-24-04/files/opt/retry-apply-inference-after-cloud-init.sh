#!/bin/bash
# Retries Serverless Inference apply after cloud-init may have written MODEL_ACCESS_KEY.
set -euo pipefail

MARKER=/opt/omniroute/.provider-configured
APPLY=/opt/apply-inference-from-env.sh

if [ -f "$MARKER" ]; then
  exit 0
fi

# Wait for cloud-init / user-data to finish writing /etc/environment
for _ in $(seq 1 30); do
  if cloud-init status 2>/dev/null | grep -qi 'done\|disabled'; then
    break
  fi
  sleep 2
done

# Give omniroute.service a chance to become healthy
sleep 5

if [ -x "$APPLY" ] && "$APPLY"; then
  # Remove wizard hook if apply succeeded late
  if [ -f /root/.bashrc ]; then
    sed -i \
      -e '/chmod +x \/etc\/setup_wizard\.sh/d' \
      -e '/\/etc\/setup_wizard\.sh/d' \
      /root/.bashrc
  fi
fi

exit 0
