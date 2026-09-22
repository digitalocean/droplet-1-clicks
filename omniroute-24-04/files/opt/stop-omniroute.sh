#!/bin/bash
set -euo pipefail
/opt/omniroute/run.sh stop
echo "OmniRoute stopped. Caddy left running (use: systemctl stop caddy)."
