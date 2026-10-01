#!/bin/bash
# Pulls whatever images compose.yml currently pins and recreates the stack.
# To move to a newer QM release, first edit the three image digests in
# /opt/qm/compose.yml — fetch the new release's images.json from
# https://github.com/yc-software/qm/releases and copy its core/web-ui/portal
# digests in — then run this script.
set -euo pipefail
cd /opt/qm
docker compose pull
docker compose up -d
