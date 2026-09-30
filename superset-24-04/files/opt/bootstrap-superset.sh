#!/bin/bash
# Prepare local PostgreSQL, Caddy, and the Superset env file. Metadata
# migrations and the admin user run in /var/lib/digitalocean/finish-setup.sh.
# Managed Postgres, when attached, is applied later by setup-dbaas.sh.
set -euo pipefail

# shellcheck source=/dev/null
source /opt/superset/lib.sh

mkdir -p /etc/superset \
  /var/lib/digitalocean \
  /var/lib/superset/home/cache/metadata \
  /var/lib/superset/home/cache/data \
  /var/log

echo "=== $(date -Is) Apache Superset bootstrap ==="

droplet_ip() {
  local pub
  pub="$(curl -fsS --retry 10 --retry-connrefused --max-time 2 \
    http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null || true)"
  if [[ -n "$pub" ]]; then
    printf '%s\n' "$pub"
    return 0
  fi
  hostname -I | awk '{print $1}'
}

configure_caddy() {
  local ip
  ip="$(droplet_ip)"
  if [[ -z "$ip" ]]; then
    echo "Could not determine the droplet IP address for Caddy." >&2
    return 1
  fi
  if [[ -f /etc/caddy/Caddyfile.tmp ]]; then
    mv /etc/caddy/Caddyfile.tmp /etc/caddy/Caddyfile
  fi
  if [[ -f /etc/caddy/Caddyfile ]]; then
    local site
    site="$(awk 'NR==1 { gsub(/\{/, ""); print $1 }' /etc/caddy/Caddyfile)"
    if [[ "$site" == "PLACEHOLDER_DOMAIN" || ( "$site" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ && "$site" != "$ip" ) ]]; then
      sed -i "1s|${site}|${ip}|" /etc/caddy/Caddyfile
      echo "Caddy site address set to ${ip}."
    fi
  fi
  systemctl enable caddy
  systemctl restart caddy
  systemctl is-active --quiet caddy
}

ensure_hex_file() {
  local path="$1"
  local nbytes="$2"
  if [[ ! -s "$path" ]]; then
    umask 077
    openssl rand -hex "$nbytes" | tr -d '\n' > "$path"
    chmod 600 "$path"
  fi
}

ensure_docker_bridge() {
  systemctl enable docker
  systemctl start docker
  local cidr=""
  local _
  for _ in $(seq 1 30); do
    if ip link show docker0 >/dev/null 2>&1; then
      cidr="$(docker network inspect bridge --format '{{(index .IPAM.Config 0).Subnet}}' 2>/dev/null || true)"
      if [[ -n "$cidr" ]]; then
        break
      fi
    fi
    sleep 1
  done
  if [[ -z "$cidr" && -s /etc/superset/docker-bridge.cidr ]]; then
    cidr="$(tr -d '[:space:]' < /etc/superset/docker-bridge.cidr)"
  fi
  if [[ -z "$cidr" ]]; then
    echo "Docker bridge is not available." >&2
    return 1
  fi
  printf '%s\n' "$cidr" > /etc/superset/docker-bridge.cidr

  local gateway
  gateway="$(docker network inspect bridge --format '{{(index .IPAM.Config 0).Gateway}}' 2>/dev/null || true)"
  if [[ ! "$gateway" =~ ^[0-9.]+$ ]]; then
    echo "Docker bridge gateway is not an IPv4 address." >&2
    return 1
  fi
  local listen_conf=/etc/postgresql/16/main/conf.d/superset.conf
  local listen_changed=0
  if grep -qx "listen_addresses = '${gateway}'" "$listen_conf"; then
    listen_changed=0
  elif grep -q '^listen_addresses' "$listen_conf"; then
    sed -i "s/^listen_addresses = .*/listen_addresses = '${gateway}'/" "$listen_conf"
    listen_changed=1
  else
    printf "listen_addresses = '%s'\n" "$gateway" >> "$listen_conf"
    listen_changed=1
  fi

  if ! ufw status verbose | grep -q 'PostgreSQL from Docker bridge'; then
    ufw allow in on docker0 to any port 5432 proto tcp comment 'PostgreSQL from Docker bridge'
  fi

  local pg_hba=/etc/postgresql/16/main/pg_hba.conf
  local rule="host superset superset ${cidr} scram-sha-256"
  local tmp
  tmp="$(mktemp)"
  grep -vE '^host[[:space:]]+superset[[:space:]]+superset[[:space:]]' "$pg_hba" > "$tmp" || true
  printf '%s\n' "$rule" >> "$tmp"
  cat "$tmp" > "$pg_hba"
  rm -f "$tmp"
  # listen_addresses is applied only by a restart. A reload is enough for pg_hba.
  if [[ "$listen_changed" -eq 1 ]]; then
    systemctl restart postgresql
  else
    systemctl reload postgresql || systemctl restart postgresql
  fi
}

ensure_local_metadata_db() {
  ensure_hex_file /etc/superset/metadata.password 24
  local pass
  pass="$(cat /etc/superset/metadata.password)"
  runuser -u postgres -- psql -v ON_ERROR_STOP=1 -v meta_pass="$pass" <<'SQL'
SELECT format('CREATE ROLE superset LOGIN PASSWORD %L', :'meta_pass')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'superset')\gexec
SELECT 'CREATE DATABASE superset OWNER superset'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'superset')\gexec
REVOKE ALL ON DATABASE superset FROM PUBLIC;
GRANT ALL ON DATABASE superset TO superset;
SQL
  printf '%s\n' local > /var/lib/digitalocean/superset-metadata-db
}

systemctl enable postgresql
systemctl start postgresql
configure_caddy
ensure_docker_bridge

if [[ -f /var/lib/superset/setup-complete ]]; then
  echo "Setup already completed. Starting services."
  systemctl enable superset
  systemctl restart superset
  exit 0
fi

echo "Using local PostgreSQL 16 for the metadata database."
ensure_local_metadata_db
META_URI="$(postgres_uri \
  superset \
  "$(cat /etc/superset/metadata.password)" \
  host.docker.internal \
  5432 \
  superset \
  "")"

/opt/prepare-source-db.sh superset_source
# shellcheck disable=SC1091
source /etc/superset/source.env
SOURCE_URI="$(postgres_uri \
  superset_reader \
  "$SUPERSET_READER_PASSWORD" \
  host.docker.internal \
  5432 \
  superset_source \
  "")"

ensure_hex_file /etc/superset/secret_key 32
ensure_hex_file /etc/superset/admin.password 16
SECRET_KEY="$(cat /etc/superset/secret_key)"

umask 077
{
  printf '%s=%s\n' SUPERSET_SECRET_KEY "$SECRET_KEY"
  printf '%s=%s\n' SUPERSET_CONFIG_PATH /etc/superset/superset_config.py
  printf '%s=%s\n' SUPERSET_CACHE_DIR /app/superset_home/cache
  printf '%s=%s\n' SUPERSET__SQLALCHEMY_DATABASE_URI "$META_URI"
  printf '%s=%s\n' SUPERSET__SQLALCHEMY_EXAMPLES_URI "$SOURCE_URI"
  printf '%s=%s\n' SUPERSET_ENV production
  printf '%s=%s\n' SERVER_WORKER_AMOUNT 2
  printf '%s=%s\n' SERVER_THREADS_AMOUNT 8
  printf '%s=%s\n' GUNICORN_TIMEOUT 120
} > /etc/superset/superset.env
chmod 600 /etc/superset/superset.env /etc/superset/secret_key /etc/superset/admin.password
echo "=== $(date -Is) local PostgreSQL prepared ==="
