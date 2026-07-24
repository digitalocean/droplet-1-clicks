#!/bin/bash
set -euo pipefail

PG_CONFIGURED=false
CONFIG_FILE=/home/superset/superset/superset_config.py

if [ -f "/root/.digitalocean_dbaas_credentials" ]; then
    if grep -q '^db_protocol="postgresql"$' "/root/.digitalocean_dbaas_credentials"; then
        PG_HOST=$(sed -n "s/^db_host=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)
        PG_PORT=$(sed -n "s/^db_port=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)
        PG_USER=$(sed -n "s/^db_username=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)
        PG_DB=$(sed -n "s/^db_database=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)
        PG_PASS=$(sed -n "s/^db_password=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)

        PG_URL="postgresql+psycopg2://${PG_USER}:${PG_PASS}@${PG_HOST}:${PG_PORT}/${PG_DB}?sslmode=require"

        echo "Waiting for your database to become available (this may take a few minutes)"
        while ! pg_isready -h "$PG_HOST" -p "$PG_PORT"; do
            printf .
            sleep 2
        done
        echo ""
        echo "Database available!"

        # Update URI in the shipped config (preserve SECRET_KEY and other settings)
        python3 - "${CONFIG_FILE}" "${PG_URL}" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
uri = sys.argv[2]
text = path.read_text()
text, n = re.subn(
    r"^SQLALCHEMY_DATABASE_URI = .*",
    f'SQLALCHEMY_DATABASE_URI = "{uri}"',
    text,
    count=1,
    flags=re.M,
)
if n != 1:
    raise SystemExit("failed to update SQLALCHEMY_DATABASE_URI in config")
path.write_text(text)
PY
        chown superset:superset "${CONFIG_FILE}"

        systemctl stop postgresql
        systemctl disable postgresql

        sudo -u superset env PASSWORD="${PASSWORD}" bash /var/lib/digitalocean/finish-setup.sh

        PG_CONFIGURED=true
    fi
fi

export PG_CONFIGURED
