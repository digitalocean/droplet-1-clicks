#!/bin/bash
# Switch Superset metadata to DigitalOcean Managed Postgres when
# /root/.digitalocean_dbaas_credentials has db_protocol="postgresql".
# Invoke with bash. Do not source this file.
# Requires PASSWORD for the admin user. Only SUPERSET__SQLALCHEMY_DATABASE_URI
# is updated (metadata). Analytics databases are added by the user in the UI.
set -euo pipefail

CREDS=/root/.digitalocean_dbaas_credentials
ENV_FILE=/etc/superset/superset.env
METADATA_DB_STATE=/var/lib/digitalocean/superset-metadata-db
VARS_FILE=/etc/superset/dbaas.vars

cleanup_dbaas_vars() {
  rm -f "$VARS_FILE"
}
trap cleanup_dbaas_vars EXIT

mkdir -p /var/lib/digitalocean /etc/superset

keep_local() {
  echo "$1" >&2
  printf '%s\n' local > "$METADATA_DB_STATE"
  exit 0
}

if [[ ! -f "$CREDS" ]]; then
  exit 0
fi

set +e
python3 - "$CREDS" "$VARS_FILE" <<'PY'
import pathlib
import re
import shlex
import sys

text = pathlib.Path(sys.argv[1]).read_text()

def grab(key):
    match = re.search(rf'^{key}="(.*)"\s*$', text, re.M)
    return match.group(1) if match else ""

if grab("db_protocol") != "postgresql":
    sys.exit(1)

needed = ("db_host", "db_port", "db_username", "db_password", "db_database")
if not all(grab(key) for key in needed):
    sys.exit(2)

path = pathlib.Path(sys.argv[2])
path.write_text(
    "\n".join(
        [
            f"PG_HOST={shlex.quote(grab('db_host'))}",
            f"PG_PORT={shlex.quote(grab('db_port'))}",
            f"PG_USER={shlex.quote(grab('db_username'))}",
            f"PG_PASS={shlex.quote(grab('db_password'))}",
            f"PG_DB={shlex.quote(grab('db_database'))}",
            "",
        ]
    )
)
path.chmod(0o600)
PY
parse_rc=$?
set -e

if [[ "$parse_rc" -eq 1 ]]; then
  exit 0
fi
if [[ "$parse_rc" -ne 0 ]]; then
  keep_local "Managed Postgres credentials are present but incomplete. Keeping local PostgreSQL."
fi

# shellcheck disable=SC1090
source "$VARS_FILE"
if [[ ! "$PG_PORT" =~ ^[0-9]+$ ]]; then
  keep_local "Managed Postgres port is not numeric. Keeping local PostgreSQL."
fi

echo "Waiting for Managed Postgres at ${PG_HOST}:${PG_PORT} (up to 10 minutes)"
ready=0
deadline=$((SECONDS + 600))
while [[ "$SECONDS" -lt "$deadline" ]]; do
  if pg_isready -h "$PG_HOST" -p "$PG_PORT" -t 5; then
    ready=1
    break
  fi
  printf .
  sleep 2
done
echo ""

if [[ "$ready" -ne 1 ]]; then
  keep_local "Timed out waiting for managed Postgres at ${PG_HOST}:${PG_PORT}. Keeping local PostgreSQL."
fi

echo "Database available."

# First boot has not migrated the local database yet, so there is nothing to
# copy and the managed switch continues. A later retry copies charts and users
# created while Superset was still on local Postgres. A failed copy stays local
# and does not stop PostgreSQL.
if ! has_local_meta="$(runuser -u postgres -- psql -d superset -Atqc \
  "SELECT CASE WHEN to_regclass('public.alembic_version') IS NULL THEN 'no' ELSE 'yes' END")"; then
  keep_local "Could not read the local metadata database. Keeping local PostgreSQL."
fi
if [[ "$has_local_meta" == "yes" ]]; then
  metadata_dump="$(mktemp)"
  chmod 600 "$metadata_dump"
  copy_ok=0
  if runuser -u postgres -- pg_dump --no-owner --no-acl --no-comments -d superset > "$metadata_dump" \
    && grep -v -E '^CREATE SCHEMA public;$' "$metadata_dump" \
      | PGPASSWORD="$PG_PASS" psql "host=${PG_HOST} port=${PG_PORT} user=${PG_USER} dbname=${PG_DB} sslmode=require" -v ON_ERROR_STOP=1
  then
    copy_ok=1
  fi
  rm -f "$metadata_dump"
  if [[ "$copy_ok" -ne 1 ]]; then
    keep_local "Could not copy the local metadata database into managed Postgres. Keeping local PostgreSQL."
  fi
  echo "Copied the local metadata database into managed ${PG_DB}."
else
  echo "Local metadata database has no Superset tables. Nothing to copy."
fi

managed_conn="host=${PG_HOST} port=${PG_PORT} user=${PG_USER} dbname=${PG_DB} sslmode=require"

other_logins="$(PGPASSWORD="$PG_PASS" psql "$managed_conn" -Atqc \
  "SELECT count(*) FROM pg_roles WHERE rolcanlogin AND rolname <> current_user")" \
  || other_logins=""
if [[ "$other_logins" == "0" ]]; then
  if ! PGPASSWORD="$PG_PASS" psql "$managed_conn" -v ON_ERROR_STOP=1 <<'SQL'
SELECT format('REVOKE CONNECT ON DATABASE %I FROM PUBLIC', current_database())\gexec
SELECT format('GRANT CONNECT ON DATABASE %I TO %I', current_database(), current_user)\gexec
SQL
  then
    echo "Could not lock down CONNECT on the metadata database; keeping local PostgreSQL."
    printf '%s\n' local > "$METADATA_DB_STATE"
    exit 0
  fi
else
  echo "Other login roles exist on managed Postgres; leaving PUBLIC CONNECT in place."
fi

if [[ ! -s "$ENV_FILE" ]]; then
  echo "Missing ${ENV_FILE}; cannot point Superset at managed Postgres." >&2
  exit 1
fi

config_backup="$(mktemp)"
cp "$ENV_FILE" "$config_backup"
chmod 600 "$config_backup"

restore_local_uri() {
  cp "$config_backup" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  printf '%s\n' local > "$METADATA_DB_STATE"
  rm -f "$config_backup"
  echo "Managed Postgres setup failed; restored local PostgreSQL."
}

if ! python3 - "$ENV_FILE" "$PG_USER" "$PG_PASS" "$PG_HOST" "$PG_PORT" "$PG_DB" <<'PY'
import sys
from pathlib import Path
from urllib.parse import quote

path = Path(sys.argv[1])
user, password, host, port, database = sys.argv[2:7]

admin_uri = (
    f"postgresql+psycopg2://{quote(user, safe='')}:{quote(password, safe='')}"
    f"@{host}:{port}/{quote(database, safe='')}"
    "?sslmode=require"
)

prefix = "SUPERSET__SQLALCHEMY_DATABASE_URI="
found = 0
lines = []
for line in path.read_text().splitlines(keepends=True):
    if line.startswith(prefix):
        newline = "\n" if line.endswith("\n") else ""
        lines.append(prefix + admin_uri + newline)
        found += 1
    else:
        lines.append(line)
if found != 1:
    raise SystemExit("failed to update SUPERSET__SQLALCHEMY_DATABASE_URI")
path.write_text("".join(lines))
PY
then
  restore_local_uri
  exit 0
fi
chmod 600 "$ENV_FILE"
rm -f "$VARS_FILE"

if ! env PASSWORD="${PASSWORD:-}" LINK_MANAGED_DATABASE=1 bash /var/lib/digitalocean/finish-setup.sh; then
  restore_local_uri
  exit 0
fi

rm -f "$config_backup"
# Stop only after finish-setup has committed metadata to Managed Postgres.
# The cluster stays installed so a later local fallback can start it again.
if systemctl stop postgresql@16-main \
  && systemctl stop postgresql \
  && systemctl disable postgresql@16-main \
  && systemctl disable postgresql
then
  echo "Local PostgreSQL has been stopped. The cluster is still installed."
else
  echo "Managed Postgres is in use, but local PostgreSQL could not be stopped." >&2
fi
printf '%s\n' managed > "$METADATA_DB_STATE"
echo "Superset metadata uses managed Postgres (${PG_DB})."
