#!/bin/bash
set -euo pipefail
/opt/omniroute/run.sh restart
systemctl restart caddy || true
