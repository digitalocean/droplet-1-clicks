#!/bin/bash
#
# Remote desktop for Omarchy 4.x: SDDM autologin into the omarchy session,
# wayvnc + noVNC, both localhost-only (access via SSH tunnel).
set -euo pipefail

echo "==> SDDM autologin (stock 4.x waits at the greeter; a droplet has no keyboard)"
sudo tee /etc/sddm.conf.d/20-autologin.conf >/dev/null <<'EOF'
[Autologin]
User=arch
Session=omarchy
EOF

echo "==> Installing wayvnc + websockify + noVNC"
# websockify lives in a SYSTEM venv and noVNC under /usr/share: service
# dependencies do not belong in a user home (pipx venvs hard-code absolute
# home paths and break if the home ever moves or the user changes).
sudo pacman -S --noconfirm --needed wayvnc python git pwgen 2>&1 | tail -1
sudo python3 -m venv /opt/websockify
sudo /opt/websockify/bin/pip -q install websockify
sudo git clone --depth 1 https://github.com/novnc/noVNC /usr/share/novnc
sudo rm -rf /usr/share/novnc/.git

echo "==> wayvnc autostarts with the session (4.x lua config API)"
grep -q wayvnc ~/.config/hypr/autostart.lua ||
  echo 'o.launch_on_start("wayvnc 127.0.0.1 5900")' >> ~/.config/hypr/autostart.lua

echo "==> Installing systemd units"
sudo cp /tmp/build-files/etc/systemd/system/novnc.service /etc/systemd/system/
sudo cp /tmp/build-files/etc/systemd/system/ensure-ssh-firewall.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable novnc.service ensure-ssh-firewall.service

echo "==> Enabling MOTD on login"
sudo cp /tmp/build-files/etc/ssh/sshd_config.d/10-omarchy-motd.conf /etc/ssh/sshd_config.d/

echo "==> Public HTTPS access: Caddy (LE short-lived IP cert) + setup assistant"
sudo pacman -S --noconfirm --needed caddy 2>&1 | tail -1
# The caddy package ships tmpfiles.d for /var/log/caddy, but that runs from a
# pacman hook; create it here so the build cannot fail on hook ordering.
# The access log must exist before Caddy's first write so fail2ban's
# caddy-auth jail has a file to watch from the moment it starts.
sudo install -d -m 750 -o caddy -g caddy /var/log/caddy
sudo touch /var/log/caddy/access.log
sudo chown caddy:caddy /var/log/caddy/access.log
sudo chmod 640 /var/log/caddy/access.log
sudo mkdir -p /etc/caddy /usr/share/omarchy-droplet/setup-pending
sudo cp /tmp/build-files/etc/caddy/Caddyfile.setup-pending /etc/caddy/
sudo cp /tmp/build-files/etc/caddy/Caddyfile.live /etc/caddy/
sudo chmod 640 /etc/caddy/Caddyfile.setup-pending /etc/caddy/Caddyfile.live
sudo chown root:caddy /etc/caddy/Caddyfile.setup-pending /etc/caddy/Caddyfile.live
sudo cp /tmp/build-files/usr/share/omarchy-droplet/setup-pending/index.html /usr/share/omarchy-droplet/setup-pending/
sudo install -m 755 /tmp/build-files/usr/local/bin/omarchy-droplet-setup /usr/local/bin/
sudo install -m 755 /tmp/build-files/usr/local/bin/omarchy-vnc-password /usr/local/bin/
sudo install -m 644 /tmp/build-files/etc/profile.d/omarchy-first-setup.sh /etc/profile.d/
# no cert attempts at build time: the droplet IP does not exist yet
sudo systemctl disable --now caddy 2>/dev/null || true

echo "==> Installing per-instance onboot script (unique password + MOTD per droplet)"
sudo mkdir -p /var/lib/cloud/scripts/per-instance
sudo cp /tmp/build-files/var/lib/cloud/scripts/per-instance/001_onboot /var/lib/cloud/scripts/per-instance/001_onboot
sudo chown root:root /var/lib/cloud/scripts/per-instance/001_onboot
sudo chmod 755 /var/lib/cloud/scripts/per-instance/001_onboot

echo "==> Remote desktop OK"
