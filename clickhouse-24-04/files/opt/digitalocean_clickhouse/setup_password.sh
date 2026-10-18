#!/bin/bash
# Generate a per-droplet ClickHouse default password, write it to disk, and start the server.
# Idempotent: safe to call from first-boot onboot and again later.
#
# Do not use pipefail: PASSWORD=$(base64 | head -c8) gets SIGPIPE from head and
# would abort before the password is ever written (seen on live droplets).

set -eu

PASSWORD_FILE=/root/.digitalocean_password
MARKER=/var/lib/digitalocean/clickhouse-password-configured
USERS_XML=/etc/clickhouse-server/users.d/default-password.xml
PID_DIR=/var/run/clickhouse-server

mkdir -p /var/lib/digitalocean
mkdir -p "$PID_DIR"
chown clickhouse:clickhouse "$PID_DIR" 2>/dev/null || true

if [ -f "$MARKER" ]; then
    systemctl start clickhouse-server 2>/dev/null || service clickhouse-server start || true
    exit 0
fi

if [ ! -f "$USERS_XML" ]; then
    echo "ERROR: ClickHouse users config missing: $USERS_XML" >&2
    exit 1
fi

if ! grep -q '<password_sha256_hex>.*</password_sha256_hex>' "$USERS_XML"; then
    echo "ERROR: $USERS_XML has no <password_sha256_hex> tag to update." >&2
    exit 1
fi

# Same generation flow as the original first-login script.
PASSWORD=$(base64 < /dev/urandom | head -c8)
HASHED=$(echo -n "$PASSWORD" | sha256sum | awk '{print $1}')

sed -e "s|<password_sha256_hex>.*</password_sha256_hex>|<password_sha256_hex>${HASHED}</password_sha256_hex>|" \
    -i "$USERS_XML"

if ! grep -q "<password_sha256_hex>${HASHED}</password_sha256_hex>" "$USERS_XML"; then
    echo "ERROR: Failed to write password hash into $USERS_XML" >&2
    exit 1
fi

cat > "$PASSWORD_FILE" <<EOM
clickhouse_default_password="${PASSWORD}"
EOM
chmod 600 "$PASSWORD_FILE"

cat > /var/lib/digitalocean/clickhouse.info <<EOM
ClickHouse is installed and configured.

Default user password is in: ${PASSWORD_FILE}

To rotate the password:
  PASSWORD=\$(base64 < /dev/urandom | head -c8); echo "\$PASSWORD"; echo -n "\$PASSWORD" | sha256sum | awk '{print \$1}'
Then update <password_sha256_hex> in ${USERS_XML} and restart clickhouse-server.
EOM
chmod 600 /var/lib/digitalocean/clickhouse.info

systemctl enable clickhouse-server >/dev/null 2>&1 || true
systemctl start clickhouse-server || service clickhouse-server start || clickhouse start

touch "$MARKER"
