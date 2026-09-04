#!/bin/bash
set -euo pipefail
cd /docker/plausible
docker compose stop
echo "Plausible stopped."
