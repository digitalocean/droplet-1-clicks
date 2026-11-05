#!/bin/bash
# Retries Serverless Inference apply after cloud-init may have written MODEL_ACCESS_KEY.
# GitHub setup is separate, so this does not remove the first-login wizard.
set -euo pipefail

if /opt/dsh-superagent/apply-inference-from-env.sh; then
    systemctl restart dsh-superagent.service || true
    /opt/dsh-superagent/push-inference-model.sh || true
fi
