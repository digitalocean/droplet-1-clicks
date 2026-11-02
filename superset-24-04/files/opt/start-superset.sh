#!/bin/bash
set -euo pipefail

# shellcheck source=/dev/null
source /opt/superset/lib.sh

if [[ "${1:-}" == "--foreground" ]]; then
  ensure_superset_container
  exec docker start -a superset
fi

systemctl start superset
echo "Superset start requested."
