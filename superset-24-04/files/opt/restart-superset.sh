#!/bin/bash
set -euo pipefail

systemctl restart superset
echo "Superset restarted."
