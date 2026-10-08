#!/bin/bash
set -euo pipefail

if [[ -z "${application_version:-}" ]]; then
  echo "application_version is not set. It must come from template.json." >&2
  exit 1
fi
APP_VERSION="$application_version"
IMAGE_REF="superset-local:${APP_VERSION}"
AMD64_DIGEST="sha256:8b0426ef41beba328549e45371ea181f1c6761a871f167565cdab33c76057fe1"

if ! grep -q "$APP_VERSION" /opt/superset/Dockerfile \
  || ! grep -q "$AMD64_DIGEST" /opt/superset/Dockerfile; then
  echo "Dockerfile digest and application_version ${APP_VERSION} are not the same Superset release." >&2
  exit 1
fi

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list

rm -f /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/gpg.key" \
  | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" \
  > /etc/apt/sources.list.d/caddy-stable.list

apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin caddy

install -d -m 0755 /etc/docker
if [[ ! -f /etc/docker/daemon.json ]]; then
  echo "Missing /etc/docker/daemon.json" >&2
  exit 1
fi

systemctl enable docker
systemctl restart docker
for _ in $(seq 1 30); do
  if ip link show docker0 >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
ip link show docker0 >/dev/null

mkdir -p /var/log/caddy
chown -R caddy:caddy /var/log/caddy
# Caddy is enabled on first boot, after the droplet IP replaces PLACEHOLDER_DOMAIN.
systemctl disable --now caddy || true

sed 's/PLACEHOLDER_DOMAIN/127.0.0.1/' /etc/caddy/Caddyfile.tmp > /tmp/Caddyfile.validate
caddy validate --config /tmp/Caddyfile.validate
rm -f /tmp/Caddyfile.validate

PG_DIR=/etc/postgresql/16/main
install -d -m 0755 "${PG_DIR}/conf.d"
install -m 0644 /opt/superset/postgres/listen.conf "${PG_DIR}/conf.d/superset.conf"
if ! grep -q "^include_dir" "${PG_DIR}/postgresql.conf"; then
  printf "\ninclude_dir = 'conf.d'\n" >> "${PG_DIR}/postgresql.conf"
fi

BRIDGE_GATEWAY="$(docker network inspect bridge --format '{{(index .IPAM.Config 0).Gateway}}')"
if [[ ! "$BRIDGE_GATEWAY" =~ ^[0-9.]+$ ]]; then
  echo "Docker bridge gateway is not an IPv4 address." >&2
  exit 1
fi
sed -i "s/^listen_addresses = .*/listen_addresses = '${BRIDGE_GATEWAY}'/" \
  "${PG_DIR}/conf.d/superset.conf"

systemctl enable postgresql
systemctl restart postgresql

BRIDGE_CIDR="$(docker network inspect bridge --format '{{(index .IPAM.Config 0).Subnet}}')"
install -d -m 0755 /etc/superset
printf '%s\n' "$BRIDGE_CIDR" > /etc/superset/docker-bridge.cidr
printf '%s\n' "$IMAGE_REF" > /etc/superset/image-ref
chmod 644 /etc/superset/docker-bridge.cidr /etc/superset/image-ref

PG_HBA="${PG_DIR}/pg_hba.conf"
if ! grep -q 'BEGIN superset-docker-bridge' "$PG_HBA"; then
  cat >> "$PG_HBA" <<EOF

# BEGIN superset-docker-bridge
host superset superset ${BRIDGE_CIDR} scram-sha-256
host superset_source superset_reader ${BRIDGE_CIDR} scram-sha-256
# END superset-docker-bridge
EOF
fi
systemctl reload postgresql

ufw allow in on docker0 to any port 5432 proto tcp comment 'PostgreSQL from Docker bridge'

echo "Building ${IMAGE_REF} from the digest-pinned official image"
docker build --platform linux/amd64 -t "$IMAGE_REF" /opt/superset

docker run --rm --entrypoint python3 "$IMAGE_REF" -c \
  'import flask_caching, psycopg2, importlib.metadata as m
fc = m.version("Flask-Caching")
pg = m.version("psycopg2-binary")
assert fc == "2.3.1", fc
assert pg == "2.9.9", pg
print("pins ok", fc, pg)'

BUILD_SECRET="$(openssl rand -hex 32)"
docker run --rm \
  -e SUPERSET_SECRET_KEY="$BUILD_SECRET" \
  -e SUPERSET_CONFIG_PATH=/etc/superset/superset_config.py \
  -e SUPERSET__SQLALCHEMY_DATABASE_URI='sqlite:////tmp/superset-config-check.db' \
  -v /etc/superset/superset_config.py:/etc/superset/superset_config.py:ro \
  --entrypoint python3 \
  "$IMAGE_REF" \
  -c 'from superset.app import create_app; app=create_app(); assert app.config["CELERY_CONFIG"] is None; assert app.config["CACHE_CONFIG"]["CACHE_TYPE"]=="FileSystemCache"; assert str(app.config["SQLALCHEMY_DATABASE_URI"]).startswith("sqlite:"); print("config ok")'
unset BUILD_SECRET

systemctl enable fail2ban
systemctl restart fail2ban

chmod 755 /opt/start-superset.sh \
  /opt/stop-superset.sh \
  /opt/restart-superset.sh \
  /opt/status-superset.sh \
  /opt/update-superset.sh \
  /opt/setup-superset-domain.sh \
  /opt/prepare-source-db.sh \
  /opt/bootstrap-superset.sh \
  /opt/superset/lib.sh \
  /var/lib/digitalocean/setup-dbaas.sh \
  /var/lib/digitalocean/finish-setup.sh \
  /etc/update-motd.d/99-one-click \
  /var/lib/cloud/scripts/per-instance/001_onboot

# Do not enable the service in the snapshot. First boot creates the container
# after per-droplet secrets exist, then enables it.
systemctl daemon-reload
systemctl disable superset.service || true

echo "Apache Superset ${APP_VERSION} image build complete."
echo "The service starts on first boot after secrets are generated."
