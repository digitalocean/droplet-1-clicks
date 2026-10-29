#!/bin/bash
# Retries Serverless Inference apply after cloud-init may have written MODEL_ACCESS_KEY.
set -euo pipefail

set -a
# shellcheck source=/dev/null
source /etc/environment 2>/dev/null || true
set +a

if /opt/apply-inference-from-env.sh; then
  sed -i '/chmod +x \/etc\/setup_wizard\.sh/d' /root/.bashrc 2>/dev/null || true
  sed -i '/\/etc\/setup_wizard\.sh/d' /root/.bashrc 2>/dev/null || true
fi
