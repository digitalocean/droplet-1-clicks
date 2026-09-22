#!/usr/bin/env bash
set -euo pipefail

SENTINEL="/opt/vybench/.first_boot_done"
CREDENTIALS_FILE="/root/.vybench_credentials"

# The image build appends a ForceCommand so Packer disconnects. Remove it
# before anything else so SSH works while site creation is still running.
if grep -q 'ForceCommand echo "Please wait while we get your droplet ready..."' /etc/ssh/sshd_config; then
  sed -e '/Match User root/d' \
      -e '/.*ForceCommand.*droplet.*/d' \
      -i /etc/ssh/sshd_config
  systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true
fi

if [ -f "$SENTINEL" ]; then
  echo "First boot initialization already completed. Exiting."
  exit 0
fi

# Ensure user lingering is active so snapd user scopes are not killed by systemd-logind
loginctl enable-linger root 2>/dev/null || true

echo "======================================================================"
echo "          Vyogo vybench Droplet - First Boot Initialization          "
echo "======================================================================"

# ── Helper: generate a random alphanumeric string (pipefail-safe) ──
generate_password() {
  local length="${1:-24}"
  openssl rand -hex "$((length / 2 + 1))" | head -c "$length"
}

# ── 1. Read stored MariaDB root password if it exists ──
SNAP_PW_FILE="/var/snap/vybench/common/mariadb/root_password"
DB_ROOT_PASS=""

if [ -f "$SNAP_PW_FILE" ]; then
  DB_ROOT_PASS=$(cat "$SNAP_PW_FILE")
  echo "Found stored MariaDB root password (${#DB_ROOT_PASS} chars)."
fi

# ── 2. Wait for MariaDB to accept connections ──
echo "Waiting for MariaDB to become ready..."
DB_READY=false
for attempt in $(seq 1 60); do
  # Try stored password first (most likely path on snapshot boot)
  if [ -n "$DB_ROOT_PASS" ] && vybench.mysql -u root --password="$DB_ROOT_PASS" -e "SELECT 1;" >/dev/null 2>&1; then
    DB_READY=true
    echo "MariaDB ready (authenticated with stored credentials)."
    break
  fi
  # Try passwordless socket auth (fresh snap with no password set yet)
  if vybench.mysql -u root -e "SELECT 1;" >/dev/null 2>&1; then
    DB_READY=true
    echo "MariaDB ready (no password / socket auth)."
    # Generate and set a root password since none exists
    DB_ROOT_PASS=$(generate_password 24)
    echo "Setting MariaDB root password..."
    vybench.mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASS}'; ALTER USER 'root'@'127.0.0.1' IDENTIFIED BY '${DB_ROOT_PASS}'; FLUSH PRIVILEGES;"
    break
  fi
  echo "MariaDB not ready yet (attempt $attempt/60). Waiting 3s..."
  sleep 3
done

if [ "$DB_READY" = false ]; then
  echo "FATAL: MariaDB did not become ready after 60 attempts (3 min). Aborting."
  echo "Debug: snap services vybench"
  snap services vybench || true
  echo "Debug: journalctl for mariadb"
  journalctl -u snap.vybench.mariadb.service -n 20 --no-pager || true
  exit 1
fi

# ── 3. Generate admin password ──
ADMIN_PASS=$(generate_password 16)

# ── 4. Detect Droplet Public IP from DigitalOcean metadata API ──
echo "Detecting public IP address..."
DROPLET_IP=$(curl -s --connect-timeout 5 http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address || true)
if [ -z "$DROPLET_IP" ]; then
  # Fallback to first interface IP
  DROPLET_IP=$(hostname -I | awk '{print $1}' || true)
fi
if [ -z "$DROPLET_IP" ]; then
  DROPLET_IP="127.0.0.1"
fi
echo "Detected public IP: $DROPLET_IP"

SITE_NAME="$DROPLET_IP"

# ── 5. Create initial ERPNext site ──
echo "Creating primary site ($SITE_NAME) with ERPNext..."
echo "This may take 2-5 minutes depending on the Droplet size."
vybench.bench new-site "$SITE_NAME" \
  --mariadb-root-password "$DB_ROOT_PASS" \
  --admin-password "$ADMIN_PASS" \
  --install-app erpnext \
  --set-default

echo "Setting default site..."
vybench.bench use "$SITE_NAME"

echo "Restarting vybench services..."
snap restart vybench

# ── 6. Write credentials file with restricted permissions ──
cat <<EOF > "$CREDENTIALS_FILE"
======================================================================
             Vyogo ERPNext & Frappe Droplet Credentials
======================================================================

App URL:                 http://${DROPLET_IP}
Administrator Username:  Administrator
Administrator Password:  ${ADMIN_PASS}

MariaDB Root Password:   ${DB_ROOT_PASS}
Primary Site Name:       ${SITE_NAME}

Quick Start:
- Terminal UI:           sudo vybench.tui
- Add a domain:          vybench.bench setup add-domain <domain>
- SSL Setup:             certbot --nginx -d <domain>
- Install FPM apps:      vybench.fpm install <app-name>

Managed Hosting:         https://console.vyogo.cloud
App Catalog:             https://fpm.vyogo.tech
Support:                 support@vyogo.tech
======================================================================
EOF

chmod 0600 "$CREDENTIALS_FILE"

# Display credentials in boot logs
cat "$CREDENTIALS_FILE"

# ── 7. Mark first boot as complete ──
touch "$SENTINEL"
echo "First boot setup completed successfully."
