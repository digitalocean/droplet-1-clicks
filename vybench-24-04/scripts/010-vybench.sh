#!/usr/bin/env bash
set -euo pipefail

echo "==> [010-vybench] Starting vybench 1-Click Droplet Appliance installation..."

# 1. Sysctl tuning for unprivileged port binding (ports 80/443)
echo "==> Configuring unprivileged port binding..."
echo "net.ipv4.ip_unprivileged_port_start=80" > /etc/sysctl.d/99-unprivileged-ports.conf
sysctl -p /etc/sysctl.d/99-unprivileged-ports.conf

# 2. UFW Firewall Setup (22, 80, 443 only) with drop logging disabled
echo "==> Configuring UFW firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw --force enable
ufw logging off

# 3. Configure Fail2ban for SSH
echo "==> Configuring fail2ban..."
cat <<'EOF' > /etc/fail2ban/jail.local
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port = ssh
EOF
systemctl enable fail2ban
systemctl restart fail2ban || true

# 4. Snapd service initialization
echo "==> Initializing snapd..."
systemctl enable --now snapd.socket snapd
snap wait system seed.loaded

# 5. Install vybench snap exclusively from stable channel
echo "==> Installing vybench snap from stable channel..."
snap install vybench --channel=stable &
INSTALL_PID=$!

while kill -0 "$INSTALL_PID" 2>/dev/null; do
  PROGRESS=$(snap changes 2>/dev/null | grep -E 'vybench.*(Doing|Done)' || true)
  if [ -n "$PROGRESS" ]; then
    CHANGE_ID=$(echo "$PROGRESS" | awk '{print $1}')
    PERCENT=$(snap change "$CHANGE_ID" 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)?%' | tail -n 1 || true)
    if [ -n "$PERCENT" ]; then
      echo "  [snap download] vybench progress: $PERCENT"
    else
      echo "  [snap install] working..."
    fi
  else
    echo "  [snap install] initializing download..."
  fi
  sleep 10
done

wait "$INSTALL_PID"
snap list vybench
vybench.bench --version
vybench.fpm --version

# 6. Configure vybench for production mode and Nginx reverse proxy
echo "==> Configuring vybench for production mode..."
mkdir -p /var/snap/vybench/common/nginx/{conf.d,logs,tmp}
chown -R snap_daemon:snap_daemon /var/snap/vybench/common/nginx
chmod 775 /var/snap/vybench/common/nginx

echo "==> Materialising writable bench for marketplace apps..."
snap run --shell vybench.bench -c '
  . /snap/vybench/current/bin/snap-common.sh
  materialise_bench
'

echo "==> Installing latest FPM binary..."
LATEST_FPM_TAG=$(curl -sSL "https://api.github.com/repos/vyogotech/fpm/releases/latest" 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' || true)
if [ -n "$LATEST_FPM_TAG" ]; then
  mkdir -p /var/snap/vybench/common/bin
  ARCH=$(uname -m)
  [ "$ARCH" = "x86_64" ] && ARCH="amd64"
  [ "$ARCH" = "aarch64" ] && ARCH="arm64"
  if curl -sSL -f -o /var/snap/vybench/common/bin/fpm "https://github.com/vyogotech/fpm/releases/download/${LATEST_FPM_TAG}/fpm-linux-${ARCH}"; then
    chown -R snap_daemon:snap_daemon /var/snap/vybench/common/bin 2>/dev/null || true
    chmod 0755 /var/snap/vybench/common/bin/fpm
    cp -f /var/snap/vybench/common/bin/fpm /usr/local/bin/fpm || true
    echo "  Latest FPM (${LATEST_FPM_TAG}) installed to /var/snap/vybench/common/bin/fpm"
  else
    echo "  WARNING: Failed to download FPM release ${LATEST_FPM_TAG}, falling back to bundled FPM."
  fi
fi

snap set vybench mode=production
snap set vybench nginx=true
snap set vybench nginx-port=80
snap set vybench bind=0.0.0.0

echo "==> Restarting vybench snap services..."
snap restart vybench

echo "==> Waiting for all production services to become active..."
REQUIRED_SERVICES=(
  "vybench.mariadb"
  "vybench.redis"
  "vybench.web"
  "vybench.worker"
  "vybench.worker-short"
  "vybench.worker-long"
  "vybench.scheduler"
  "vybench.socketio"
  "vybench.nginx"
)

MAX_RETRIES=15
RETRY_DELAY=3

for svc in "${REQUIRED_SERVICES[@]}"; do
  echo "Checking service: $svc..."
  attempt=1
  until systemctl is-active --quiet "snap.$svc.service"; do
    if [ "$attempt" -ge "$MAX_RETRIES" ]; then
      echo "ERROR: Service snap.$svc.service failed to become active after $((MAX_RETRIES * RETRY_DELAY)) seconds!"
      systemctl status "snap.$svc.service" --no-pager || true
      journalctl -u "snap.$svc.service" -n 50 --no-pager || true
      exit 1
    fi
    echo "Service snap.$svc.service not active yet (attempt $attempt/$MAX_RETRIES). Waiting ${RETRY_DELAY}s..."
    sleep "$RETRY_DELAY"
    attempt=$((attempt + 1))
  done
  echo "Service snap.$svc.service is ACTIVE."
done

snap services vybench

# 7. Configure first-boot service and enable user lingering
echo "==> Setting up first-boot initialization service..."
chmod 0755 /opt/vybench/first_boot.sh /opt/vybench/mount_volume.sh
if [ -f /var/lib/cloud/scripts/per-instance/001_onboot ]; then
  chmod 0755 /var/lib/cloud/scripts/per-instance/001_onboot
fi
rm -f /opt/vybench/.first_boot_done /root/.vybench_credentials

# Order every snap.vybench.*.service behind vybench-volume.service, so a Block
# Storage volume (if attached) is bind-mounted onto /var/snap/vybench/common
# before MariaDB/etc. ever touch it. Strict confinement won't let the mariadb
# service plug removable-media or follow a symlink to /mnt, so this bind-mount
# indirection (done once, on boot, before the services start) is how a
# Block Storage volume's data ends up backing the snap's own data path.
found=0
for unit in /etc/systemd/system/snap.vybench.*.service; do
  [ -e "$unit" ] || continue
  found=1
  name=$(basename "$unit")
  mkdir -p "/etc/systemd/system/${name}.d"
  cat > "/etc/systemd/system/${name}.d/volume.conf" <<'EOF'
[Unit]
After=vybench-volume.service
Wants=vybench-volume.service
EOF
done

if [ "$found" -ne 1 ]; then
  echo "ERROR: no snap.vybench units found to order behind block storage."
  exit 1
fi

systemctl daemon-reload
systemctl enable vybench-first-boot.service
systemctl enable vybench-volume.service

# Enable lingering for root so snapd child scopes under user@0.service are never
# terminated when temporary SSH sessions (e.g. cloud-init, smoke test polling, user logins) disconnect.
loginctl enable-linger root

# 8. Configure login MOTD banner
echo "==> Configuring MOTD banner..."
if [ -f /etc/default/motd-news ]; then
  sed -i 's/ENABLED=1/ENABLED=0/' /etc/default/motd-news
fi

for script in 10-help-text 50-motd-news 80-livepatch; do
  if [ -f "/etc/update-motd.d/$script" ]; then
    chmod -x "/etc/update-motd.d/$script" || true
  fi
done

chmod 0755 /etc/update-motd.d/99-one-click

echo "==> [010-vybench] vybench 1-Click setup completed successfully."
