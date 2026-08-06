#!/bin/bash
# Configure Supabase to use a DigitalOcean Managed PostgreSQL database when
# credentials are provided via Marketplace predeploy (Add a Database).
#
# When DBaaS credentials are present:
#   - Point Supabase .env at Managed Postgres
#   - Remove the local db (supabase/postgres) service from compose
#   - Bootstrap roles/schemas (incl. auth/storage) needed by Supabase
#   - Enable TLS for analytics/auth/storage/realtime against Managed Postgres
# When absent, keep the local db container (default).

set -uo pipefail

COMPOSE_DIR="/srv/supabase/supabase/docker"
COMPOSE_FILE="${COMPOSE_DIR}/docker-compose.yml"
ENV_FILE="${COMPOSE_DIR}/.env"
DBAAS_FILE="/root/.digitalocean_dbaas_credentials"
DBAAS_WAIT_SECONDS="${DBAAS_WAIT_SECONDS:-300}"

shell_quote() {
  printf "'"
  printf '%s' "$1" | sed "s/'/'\\\\''/g"
  printf "'"
}

update_env_var() {
  local key="$1"
  local value="$2"
  sed -i "/^${key}=/d" "${ENV_FILE}"
  printf '%s=%s\n' "${key}" "${value}" >> "${ENV_FILE}"
}

read_env_var() {
  local key="$1"
  sed -n "s/^${key}=//p" "${ENV_FILE}" | tail -n1
}

using_dbaas=false

if [ -f "${DBAAS_FILE}" ] && [ "$(sed -n "s/^db_protocol=\"\(.*\)\"$/\1/p" "${DBAAS_FILE}")" = "postgresql" ]; then
  using_dbaas=true

  PG_HOST=$(sed -n "s/^db_host=\"\(.*\)\"$/\1/p" "${DBAAS_FILE}")
  PG_PORT=$(sed -n "s/^db_port=\"\(.*\)\"$/\1/p" "${DBAAS_FILE}")
  PG_USER=$(sed -n "s/^db_username=\"\(.*\)\"$/\1/p" "${DBAAS_FILE}")
  PG_DB=$(sed -n "s/^db_database=\"\(.*\)\"$/\1/p" "${DBAAS_FILE}")
  PG_PASS=$(sed -n "s/^db_password=\"\(.*\)\"$/\1/p" "${DBAAS_FILE}")
  PG_PASS_SQL=$(printf '%s' "${PG_PASS}" | sed "s/'/''/g")
  JWT_SECRET=$(read_env_var JWT_SECRET)
  JWT_EXPIRY=$(read_env_var JWT_EXPIRY)
  JWT_EXPIRY="${JWT_EXPIRY:-3600}"

  echo -e "\nWaiting for your managed database to become available (up to ${DBAAS_WAIT_SECONDS}s)"
  elapsed=0
  until PGPASSWORD="${PG_PASS}" psql \
    "host=${PG_HOST} port=${PG_PORT} user=${PG_USER} dbname=${PG_DB} sslmode=require" \
    -c 'SELECT 1' >/dev/null 2>&1; do
    if [ "${elapsed}" -ge "${DBAAS_WAIT_SECONDS}" ]; then
      echo -e "\nTimed out waiting for managed database. Continuing with Managed Postgres config; check Trusted Sources if services fail to connect."
      break
    fi
    printf .
    sleep 2
    elapsed=$((elapsed + 2))
  done
  if [ "${elapsed}" -lt "${DBAAS_WAIT_SECONDS}" ]; then
    echo -e "\nManaged database available!\n"
  fi

  # Point Supabase services at the managed Postgres instance
  update_env_var POSTGRES_HOST "${PG_HOST}"
  update_env_var POSTGRES_PORT "${PG_PORT}"
  update_env_var POSTGRES_DB "${PG_DB}"
  update_env_var POSTGRES_PASSWORD "${PG_PASS}"

  # DO Managed Postgres allows ~25 connections per 1GB RAM, minus 3 reserved
  # for maintenance. Stock Supabase defaults (POOLER_DEFAULT_POOL_SIZE=20 plus
  # PostgREST/Auth/Logflare/…) exhaust a typical Marketplace 1GB DB and surface:
  #   FATAL: remaining connection slots are reserved for roles with the SUPERUSER attribute
  update_env_var POOLER_DEFAULT_POOL_SIZE "5"
  update_env_var POOLER_MAX_CLIENT_CONN "50"
  update_env_var POOLER_DB_POOL_SIZE "2"

  # Remove depends_on entries that require the local db container
  perl -i -0pe 's/\n[ \t]+db:\n[ \t]+# Disable this if you are using an external Postgres database\n[ \t]+condition: service_healthy//g' "${COMPOSE_FILE}"
  perl -i -0pe 's/\n[ \t]+db:\n[ \t]+condition: service_healthy//g' "${COMPOSE_FILE}"
  # Remove empty depends_on keys left behind
  perl -i -0pe 's/\n(    depends_on:)\n(    [a-z#])/\n$2/g' "${COMPOSE_FILE}"

  # Drop only the embedded db service; keep vector (log shipping) and everything after.
  # Upstream places vector between db and the "# Update the DATABASE_URL…" marker — do not
  # cut through that whole region or vector is deleted with db.
  perl -i -0pe 's/\n  # Comment out everything below this point if you are using an external Postgres database\n  db:\n(?:.*\n)*?(?=\n  vector:)//' "${COMPOSE_FILE}"

  # Require SSL for managed database connection strings in compose
  # Ecto uses ssl=true; libpq URLs use sslmode=require (apply ecto first)
  perl -i -pe 's#(ecto://supabase_admin:\$\{POSTGRES_PASSWORD\}@\$\{POSTGRES_HOST\}:\$\{POSTGRES_PORT\}/_supabase)(?!\?ssl=true)#$1?ssl=true#g' "${COMPOSE_FILE}"
  perl -i -pe 's#((?:postgres|postgresql)://[^[:space:]]+@\$\{POSTGRES_HOST\}:\$\{POSTGRES_PORT\}/(?:\$\{POSTGRES_DB\}|_supabase))(?!\?sslmode=require)#$1?sslmode=require#g' "${COMPOSE_FILE}"

  psql_admin() {
    PGPASSWORD="${PG_PASS}" psql \
      "host=${PG_HOST} port=${PG_PORT} user=${PG_USER} dbname=${PG_DB} sslmode=require" "$@"
  }

  # Create roles expected by Supabase services (best-effort on managed Postgres)
  psql_admin -v ON_ERROR_STOP=0 <<SQL || true
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'postgres') THEN
    CREATE ROLE postgres LOGIN PASSWORD '${PG_PASS_SQL}' CREATEDB CREATEROLE;
  ELSE
    BEGIN
      ALTER ROLE postgres WITH LOGIN PASSWORD '${PG_PASS_SQL}';
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticator') THEN
    CREATE ROLE authenticator NOINHERIT LOGIN PASSWORD '${PG_PASS_SQL}';
  ELSE
    ALTER ROLE authenticator WITH LOGIN PASSWORD '${PG_PASS_SQL}';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'pgbouncer') THEN
    CREATE ROLE pgbouncer LOGIN PASSWORD '${PG_PASS_SQL}';
  ELSE
    ALTER ROLE pgbouncer WITH LOGIN PASSWORD '${PG_PASS_SQL}';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'supabase_admin') THEN
    CREATE ROLE supabase_admin LOGIN PASSWORD '${PG_PASS_SQL}' CREATEDB CREATEROLE BYPASSRLS;
  ELSE
    ALTER ROLE supabase_admin WITH LOGIN PASSWORD '${PG_PASS_SQL}' CREATEDB CREATEROLE;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'supabase_auth_admin') THEN
    CREATE ROLE supabase_auth_admin LOGIN PASSWORD '${PG_PASS_SQL}';
  ELSE
    ALTER ROLE supabase_auth_admin WITH LOGIN PASSWORD '${PG_PASS_SQL}';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'supabase_storage_admin') THEN
    CREATE ROLE supabase_storage_admin LOGIN PASSWORD '${PG_PASS_SQL}';
  ELSE
    ALTER ROLE supabase_storage_admin WITH LOGIN PASSWORD '${PG_PASS_SQL}';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'supabase_functions_admin') THEN
    CREATE ROLE supabase_functions_admin LOGIN PASSWORD '${PG_PASS_SQL}';
  ELSE
    ALTER ROLE supabase_functions_admin WITH LOGIN PASSWORD '${PG_PASS_SQL}';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN NOINHERIT;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN NOINHERIT;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role NOLOGIN NOINHERIT BYPASSRLS;
  END IF;
END
\$\$;

GRANT ALL PRIVILEGES ON DATABASE "${PG_DB}" TO postgres;
GRANT ALL PRIVILEGES ON DATABASE "${PG_DB}" TO supabase_admin;
GRANT ALL PRIVILEGES ON DATABASE "${PG_DB}" TO authenticator;
GRANT ALL PRIVILEGES ON DATABASE "${PG_DB}" TO supabase_auth_admin;
GRANT ALL PRIVILEGES ON DATABASE "${PG_DB}" TO supabase_storage_admin;
GRANT ALL ON SCHEMA public TO postgres, supabase_admin, authenticator, supabase_auth_admin, supabase_storage_admin, anon, authenticated, service_role;
GRANT anon, authenticated, service_role TO authenticator;
GRANT ALL ON SCHEMA public TO anon, authenticated, service_role;
SQL

  if ! psql_admin -tAc "SELECT 1 FROM pg_database WHERE datname = '_supabase'" 2>/dev/null | grep -q 1; then
    psql_admin -c "CREATE DATABASE _supabase OWNER supabase_admin;" || true
  fi

  # Schemas the local supabase/postgres image would create via init scripts.
  # auth/storage are required before GoTrue/Storage can migrate on Managed Postgres.
  psql_admin -v ON_ERROR_STOP=0 <<SQL || true
CREATE SCHEMA IF NOT EXISTS _realtime AUTHORIZATION supabase_admin;
CREATE SCHEMA IF NOT EXISTS extensions AUTHORIZATION supabase_admin;
CREATE SCHEMA IF NOT EXISTS auth AUTHORIZATION supabase_auth_admin;
CREATE SCHEMA IF NOT EXISTS storage AUTHORIZATION supabase_storage_admin;
CREATE SCHEMA IF NOT EXISTS graphql_public AUTHORIZATION supabase_admin;
CREATE SCHEMA IF NOT EXISTS realtime AUTHORIZATION supabase_admin;
GRANT ALL ON SCHEMA auth TO postgres, supabase_admin, supabase_auth_admin, authenticator;
GRANT ALL ON SCHEMA storage TO postgres, supabase_admin, supabase_storage_admin, authenticator;
GRANT ALL ON SCHEMA graphql_public TO postgres, supabase_admin, authenticator, anon, authenticated, service_role;
GRANT ALL ON SCHEMA realtime TO postgres, supabase_admin, authenticator;
GRANT ALL ON SCHEMA extensions TO postgres, supabase_admin, authenticator;
GRANT ALL ON SCHEMA _realtime TO postgres, supabase_admin;
SQL

  PGPASSWORD="${PG_PASS}" psql \
    "host=${PG_HOST} port=${PG_PORT} user=${PG_USER} dbname=_supabase sslmode=require" \
    -v ON_ERROR_STOP=0 <<SQL || true
CREATE SCHEMA IF NOT EXISTS _analytics AUTHORIZATION supabase_admin;
CREATE SCHEMA IF NOT EXISTS _supavisor AUTHORIZATION supabase_admin;
GRANT ALL ON SCHEMA _analytics TO supabase_admin;
GRANT ALL ON SCHEMA _supavisor TO supabase_admin;
SQL

  if [ -n "${JWT_SECRET}" ]; then
    psql_admin -v ON_ERROR_STOP=0 \
      -c "ALTER DATABASE \"${PG_DB}\" SET \"app.settings.jwt_secret\" TO '${JWT_SECRET}';" || true
    psql_admin -v ON_ERROR_STOP=0 \
      -c "ALTER DATABASE \"${PG_DB}\" SET \"app.settings.jwt_exp\" TO '${JWT_EXPIRY}';" || true
  fi

  # Apply remaining bundled init SQL when possible (extensions like pg_net may be unavailable)
  for sql in \
    "${COMPOSE_DIR}/volumes/db/roles.sql" \
    "${COMPOSE_DIR}/volumes/db/webhooks.sql"
  do
    if [ -f "${sql}" ]; then
      echo "Applying $(basename "${sql}") to managed database (best-effort)"
      PGPASSWORD="${PG_PASS}" POSTGRES_PASSWORD="${PG_PASS}" POSTGRES_USER=supabase_admin psql \
        "host=${PG_HOST} port=${PG_PORT} user=${PG_USER} dbname=${PG_DB} sslmode=require" \
        -v ON_ERROR_STOP=0 -f "${sql}" || true
    fi
  done

  # Logflare only enables DB SSL when DB_SSL=true AND client cert PEMs exist.
  # DO Managed Postgres uses server TLS without client certs.
  # Prefer the Packer-baked patched runtime.exs; rebuild it if missing.
  ANALYTICS_VOL="${COMPOSE_DIR}/volumes/analytics"
  RUNTIME_EXS="${ANALYTICS_VOL}/runtime.exs"
  VERSION_FILE="${ANALYTICS_VOL}/logflare_version"
  PREPARE="/var/lib/digitalocean/prepare-logflare-ssl.sh"

  if [ ! -x "${PREPARE}" ]; then
    echo "ERROR: missing ${PREPARE}" >&2
    exit 1
  fi
  if ! "${PREPARE}" "${COMPOSE_DIR}"; then
    echo "ERROR: Failed to prepare Logflare SSL patch for Managed Postgres." >&2
    echo "ERROR: Refusing to mark DBaaS setup successful — analytics would block Studio/Kong." >&2
    exit 1
  fi
  if [ ! -f "${RUNTIME_EXS}" ]; then
    echo "ERROR: Logflare runtime.exs missing after prepare step." >&2
    exit 1
  fi

  # Match top-level analytics service only (not nested depends_on: analytics:).
  LOGFLARE_IMAGE=$(awk '
    /^[[:space:]]{2}analytics:[[:space:]]*$/ { f=1; next }
    f && /^[[:space:]]{2}[a-zA-Z0-9_]+:/ { f=0 }
    f && /^[[:space:]]+image:[[:space:]]*/ { print $2; exit }
  ' "${COMPOSE_FILE}")
  LOGFLARE_IMAGE="${LOGFLARE_IMAGE:-supabase/logflare:1.36.1}"
  LOGFLARE_VER="${LOGFLARE_IMAGE##*:}"
  if [ -f "${VERSION_FILE}" ]; then
    LOGFLARE_VER=$(tr -d '[:space:]' < "${VERSION_FILE}")
  fi

  # SSL / TLS for services that talk to Managed Postgres outside URL query params.
  # Cap per-service pools so the stack fits small Managed DB plans.
  # Studio must not wait on analytics healthy — otherwise Logflare issues hide Studio.
  cat > "${COMPOSE_DIR}/docker-compose.dbaas.yml" <<EOF
services:
  realtime:
    environment:
      DB_SSL: "true"
  meta:
    environment:
      PGSSLMODE: require
  rest:
    environment:
      PGRST_DB_POOL: "5"
  analytics:
    environment:
      DB_SSL: "true"
      PGSSLMODE: require
      DB_POOL_SIZE: "3"
    volumes:
      - ./volumes/analytics/runtime.exs:/opt/app/rel/logflare/releases/${LOGFLARE_VER}/runtime.exs:ro
  storage:
    environment:
      NODE_TLS_REJECT_UNAUTHORIZED: "0"
  auth:
    environment:
      GOTRUE_DB_SSLMODE: require
      GOTRUE_DB_MAX_POOL_SIZE: "5"
  studio:
    depends_on:
      analytics:
        condition: service_started
EOF

  # Persist credentials for MOTD / operators
  if command -v jq >/dev/null 2>&1; then
    PG_PASS_ENC=$(jq -nr --arg p "${PG_PASS}" '$p|@uri')
  else
    PG_PASS_ENC="${PG_PASS}"
  fi
  DATABASE_URL="postgresql://${PG_USER}:${PG_PASS_ENC}@${PG_HOST}:${PG_PORT}/${PG_DB}?sslmode=require"

  cat >> /root/.digitalocean_passwords <<EOM
SUPABASE_DBAAS=true
POSTGRES_HOST=$(shell_quote "${PG_HOST}")
POSTGRES_PORT=$(shell_quote "${PG_PORT}")
POSTGRES_DB=$(shell_quote "${PG_DB}")
POSTGRES_USER=$(shell_quote "${PG_USER}")
POSTGRES_PASSWORD=$(shell_quote "${PG_PASS}")
DATABASE_URL=$(shell_quote "${DATABASE_URL}")
EOM

  if ! grep -q '^DATABASE_URL=' /etc/environment 2>/dev/null; then
    echo "DATABASE_URL=\"${DATABASE_URL}\"" >> /etc/environment
  else
    sed -i "/^DATABASE_URL=/d" /etc/environment
    echo "DATABASE_URL=\"${DATABASE_URL}\"" >> /etc/environment
  fi

  echo "Supabase configured to use Managed PostgreSQL at ${PG_HOST}:${PG_PORT}/${PG_DB}"
fi

if [ "${using_dbaas}" = false ]; then
  LOCAL_PG_PASS=$(read_env_var POSTGRES_PASSWORD)
  LOCAL_PG_DB=$(read_env_var POSTGRES_DB)
  LOCAL_PG_DB="${LOCAL_PG_DB:-postgres}"
  cat >> /root/.digitalocean_passwords <<EOM
SUPABASE_DBAAS=false
POSTGRES_HOST='db'
POSTGRES_PORT='5432'
POSTGRES_DB=$(shell_quote "${LOCAL_PG_DB}")
POSTGRES_PASSWORD=$(shell_quote "${LOCAL_PG_PASS}")
EOM
fi
