#!/bin/bash
set -a
source /etc/environment 2>/dev/null || true
set +a
if /opt/apply-inference-from-env.sh; then
    sed -i '/\/opt\/setup-opencode\.sh/d' /root/.bashrc 2>/dev/null || true
fi
