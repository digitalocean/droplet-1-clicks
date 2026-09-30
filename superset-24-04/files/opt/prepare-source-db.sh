#!/bin/bash
# Grant the read-only role superset_reader on a local PostgreSQL database that
# Superset will query. The metadata database is separate and is not granted.
# This script is only for local PostgreSQL. On a managed cluster, create
# tables in database superset_source as the managed admin user.
#
# Usage: /opt/prepare-source-db.sh [database_name]
# Default database: superset_source
set -euo pipefail

if [[ -f /var/lib/digitalocean/superset-metadata-db ]] \
  && [[ "$(tr -d '[:space:]' < /var/lib/digitalocean/superset-metadata-db)" == "managed" ]]; then
  echo "This script is only for local PostgreSQL. Create tables in the managed database superset_source." >&2
  exit 1
fi

DB_NAME="${1:-superset_source}"
SOURCE_ENV=/etc/superset/source.env
PG_HBA=/etc/postgresql/16/main/pg_hba.conf

if [[ ! "$DB_NAME" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
  echo "Database name must be a simple identifier (letters, numbers, underscore)." >&2
  exit 1
fi

if [[ "$DB_NAME" == "superset" ]]; then
  echo "Refusing to grant superset_reader on the metadata database 'superset'." >&2
  exit 1
fi

mkdir -p /etc/superset
if [[ ! -s "$SOURCE_ENV" ]]; then
  umask 077
  printf 'SUPERSET_READER_PASSWORD=%s\n' "$(openssl rand -hex 24)" > "$SOURCE_ENV"
  chmod 600 "$SOURCE_ENV"
fi

# shellcheck disable=SC1090
source "$SOURCE_ENV"
if [[ -z "${SUPERSET_READER_PASSWORD:-}" ]]; then
  echo "SUPERSET_READER_PASSWORD is missing from ${SOURCE_ENV}." >&2
  exit 1
fi

systemctl enable postgresql
systemctl start postgresql

for _ in $(seq 1 30); do
  if runuser -u postgres -- pg_isready -q; then
    break
  fi
  sleep 1
done
runuser -u postgres -- pg_isready -q

runuser -u postgres -- psql -v ON_ERROR_STOP=1 \
  -v dbname="$DB_NAME" \
  -v reader_pass="$SUPERSET_READER_PASSWORD" <<'SQL'
SELECT format('CREATE ROLE superset_reader LOGIN PASSWORD %L', :'reader_pass')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'superset_reader')\gexec

SELECT format('CREATE DATABASE %I OWNER postgres', :'dbname')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'dbname')\gexec

REVOKE ALL ON DATABASE :"dbname" FROM PUBLIC;
GRANT CONNECT ON DATABASE :"dbname" TO superset_reader;
SQL

if runuser -u postgres -- psql -tAc "SELECT 1 FROM pg_roles WHERE rolname = 'superset'" | grep -qx 1; then
  # psql does not expand :"variables" in -c strings. The name is already validated.
  runuser -u postgres -- psql -v ON_ERROR_STOP=1 \
    -c "REVOKE ALL ON DATABASE \"${DB_NAME}\" FROM superset"
fi

if runuser -u postgres -- psql -tAc "SELECT 1 FROM pg_database WHERE datname = 'superset'" | grep -qx 1; then
  runuser -u postgres -- psql -v ON_ERROR_STOP=1 \
    -c 'REVOKE ALL ON DATABASE superset FROM superset_reader'
fi

runuser -u postgres -- psql -v ON_ERROR_STOP=1 -d "$DB_NAME" <<'SQL'
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO superset_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO superset_reader;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO superset_reader;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT SELECT ON TABLES TO superset_reader;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT SELECT ON SEQUENCES TO superset_reader;
SQL

if cidr="$(docker network inspect bridge --format '{{(index .IPAM.Config 0).Subnet}}' 2>/dev/null)" && [[ -n "$cidr" ]]; then
  BRIDGE_CIDR="$cidr"
  printf '%s\n' "$BRIDGE_CIDR" > /etc/superset/docker-bridge.cidr
elif [[ -s /etc/superset/docker-bridge.cidr ]]; then
  BRIDGE_CIDR="$(tr -d '[:space:]' < /etc/superset/docker-bridge.cidr)"
else
  echo "Docker bridge subnet is unknown. Start Docker and retry." >&2
  exit 1
fi

RULE="host ${DB_NAME} superset_reader ${BRIDGE_CIDR} scram-sha-256"
tmp="$(mktemp)"
grep -vE "^host[[:space:]]+${DB_NAME}[[:space:]]+superset_reader[[:space:]]" "$PG_HBA" > "$tmp" || true
printf '%s\n' "$RULE" >> "$tmp"
cat "$tmp" > "$PG_HBA"
rm -f "$tmp"

systemctl reload postgresql

echo "Granted superset_reader CONNECT and SELECT on database ${DB_NAME}."
echo "Reader password file: ${SOURCE_ENV}"
