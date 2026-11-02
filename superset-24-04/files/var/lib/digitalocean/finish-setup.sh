#!/bin/bash
# Migrate metadata and create or reset the admin user.
# 001_onboot runs this against local Postgres. setup-dbaas.sh runs it again
# after SQLALCHEMY_DATABASE_URI points at Managed Postgres.
set -euo pipefail

# shellcheck source=/dev/null
source /opt/superset/lib.sh

if [[ -z "${PASSWORD:-}" ]]; then
  echo "PASSWORD is not set; cannot create admin user." >&2
  exit 1
fi

if [[ "${LINK_MANAGED_DATABASE:-}" == "1" ]]; then
  META_URI="$(sed -n 's/^SUPERSET__SQLALCHEMY_DATABASE_URI=//p' /etc/superset/superset.env | head -n 1)"
  if [[ "$META_URI" != *"?sslmode=require" ]]; then
    echo "Managed metadata URI is missing sslmode=require in /etc/superset/superset.env." >&2
    exit 1
  fi
fi

chown_superset_home

echo "Upgrading the metadata database"
superset_run superset db upgrade

driver="$(superset_run python -c '
from superset.app import create_app
uri = create_app().config["SQLALCHEMY_DATABASE_URI"]
print("SUPERSET_DRIVER=" + uri.split("://", 1)[0])
' | awk -F= '/^SUPERSET_DRIVER=/{print $2}' | tail -n 1)"
if [[ "$driver" != "postgresql+psycopg2" ]]; then
  echo "Refusing to continue: metadata driver is '${driver}'." >&2
  exit 1
fi

admin_log="$(mktemp)"
chmod 600 "$admin_log"
# Flask-AppBuilder create-admin exits 0 when it does not create the user.
superset_run superset fab create-admin \
  --username admin \
  --firstname Superset \
  --lastname Admin \
  --email admin@example.com \
  --password "$PASSWORD" >"$admin_log" 2>&1 || true
cat "$admin_log"
if grep -Fq "Admin User admin created." "$admin_log"; then
  rm -f "$admin_log"
elif grep -Fq "already exists" "$admin_log"; then
  rm -f "$admin_log"
  echo "Admin user already exists; resetting password."
  superset_run superset fab reset-password \
    --username admin \
    --password "$PASSWORD"
else
  rm -f "$admin_log"
  echo "Failed to create Superset admin user." >&2
  exit 1
fi

echo "Initializing Superset roles"
superset_run superset init
