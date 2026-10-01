#!/bin/bash
set -euo pipefail
cd /srv/qm && docker compose up -d --force-recreate
