#!/bin/bash
set -euo pipefail

cd /home/superset/superset-project
# shellcheck disable=SC1091
. superset-env/bin/activate
export SUPERSET_CONFIG_PATH=/home/superset/superset/superset_config.py

# PASSWORD is passed from 001_onboot / setup-dbaas
if [ -z "${PASSWORD:-}" ]; then
    echo "PASSWORD is not set; cannot create admin user" >&2
    exit 1
fi

ADMIN_EMAIL="${ADMIN_EMAIL:-admin@$(hostname -f 2>/dev/null || echo localhost)}"

superset db upgrade

# create-admin fails if the user already exists (e.g. re-run after DBaaS switch)
superset fab create-admin \
    --username admin \
    --firstname Admin \
    --lastname User \
    --email "${ADMIN_EMAIL}" \
    --password "${PASSWORD}" || true

superset init
