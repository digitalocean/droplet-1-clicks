#!/bin/bash
# Prepare DigitalOcean Managed PostgreSQL credentials when provided via
# Marketplace predeploy (Add a Database).
#
# The Supabase stack keeps using its local `db` (supabase/postgres) container.
# Managed DB credentials are validated, waited on, and saved for the user.

set -u

DBAAS_FILE="/root/.digitalocean_dbaas_credentials"
DBAAS_WAIT_SECONDS="${DBAAS_WAIT_SECONDS:-300}"

if [ ! -f "${DBAAS_FILE}" ]; then
  cat >> /root/.digitalocean_passwords <<EOM
SUPABASE_DBAAS=false
EOM
  exit 0
fi

if [ "$(sed -n "s/^db_protocol=\"\(.*\)\"$/\1/p" "${DBAAS_FILE}")" != "postgresql" ]; then
  echo "Managed database protocol is not postgresql; skipping DBaaS setup."
  cat >> /root/.digitalocean_passwords <<EOM
SUPABASE_DBAAS=false
EOM
  exit 0
fi

PG_HOST=$(sed -n "s/^db_host=\"\(.*\)\"$/\1/p" "${DBAAS_FILE}")
PG_PORT=$(sed -n "s/^db_port=\"\(.*\)\"$/\1/p" "${DBAAS_FILE}")
PG_USER=$(sed -n "s/^db_username=\"\(.*\)\"$/\1/p" "${DBAAS_FILE}")
PG_DB=$(sed -n "s/^db_database=\"\(.*\)\"$/\1/p" "${DBAAS_FILE}")
PG_PASS=$(sed -n "s/^db_password=\"\(.*\)\"$/\1/p" "${DBAAS_FILE}")

# URL-encode password for DATABASE_URL
urlencode() {
  if command -v jq >/dev/null 2>&1; then
    jq -nr --arg p "$1" '$p|@uri'
  else
    printf '%s' "$1"
  fi
}

PG_PASS_ENC=$(urlencode "${PG_PASS}")
DATABASE_URL="postgresql://${PG_USER}:${PG_PASS_ENC}@${PG_HOST}:${PG_PORT}/${PG_DB}?sslmode=require"

# Single-quote a value for safe sourcing from MOTD / shell
shell_quote() {
  printf "'"
  printf '%s' "$1" | sed "s/'/'\\\\''/g"
  printf "'"
}

write_dbaas_passwords() {
  local ready="$1"
  cat >> /root/.digitalocean_passwords <<EOM
SUPABASE_DBAAS=true
SUPABASE_DBAAS_READY=${ready}
DB_HOST=$(shell_quote "${PG_HOST}")
DB_PORT=$(shell_quote "${PG_PORT}")
DB_DATABASE=$(shell_quote "${PG_DB}")
DB_USERNAME=$(shell_quote "${PG_USER}")
DB_PASSWORD=$(shell_quote "${PG_PASS}")
DATABASE_URL=$(shell_quote "${DATABASE_URL}")
EOM
}

echo -e "\nWaiting for your managed database to become available (up to ${DBAAS_WAIT_SECONDS}s)"
elapsed=0
until PGPASSWORD="${PG_PASS}" psql \
  "host=${PG_HOST} port=${PG_PORT} user=${PG_USER} dbname=${PG_DB} sslmode=require" \
  -c 'SELECT 1' >/dev/null 2>&1; do
  if [ "${elapsed}" -ge "${DBAAS_WAIT_SECONDS}" ]; then
    echo -e "\nTimed out waiting for managed database. Credentials are still saved; check Trusted Sources and retry connectivity."
    write_dbaas_passwords false
    exit 0
  fi
  printf .
  sleep 2
  elapsed=$((elapsed + 2))
done
echo -e "\nManaged database available!\n"

write_dbaas_passwords true

# Persist DATABASE_URL for shells/apps (Marketplace predeploy convention)
if ! grep -q '^DATABASE_URL=' /etc/environment 2>/dev/null; then
  echo "DATABASE_URL=\"${DATABASE_URL}\"" >> /etc/environment
else
  sed -i "/^DATABASE_URL=/d" /etc/environment
  echo "DATABASE_URL=\"${DATABASE_URL}\"" >> /etc/environment
fi

echo "Managed PostgreSQL credentials saved. Supabase continues to use the local db container."
