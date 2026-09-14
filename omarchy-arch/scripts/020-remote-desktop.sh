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
sudo pacman -S --noconfirm --needed wayvnc python-pipx git pwgen 2>&1 | tail -1
pipx install websockify
git clone --depth 1 https://github.com/novnc/noVNC ~/novnc
rm -rf ~/novnc/.git

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

echo "==> Installing per-instance onboot script (unique password + MOTD per droplet)"
sudo mkdir -p /var/lib/cloud/scripts/per-instance
sudo cp /tmp/build-files/var/lib/cloud/scripts/per-instance/001_onboot /var/lib/cloud/scripts/per-instance/001_onboot
sudo chown root:root /var/lib/cloud/scripts/per-instance/001_onboot
sudo chmod 755 /var/lib/cloud/scripts/per-instance/001_onboot

echo "==> Remote desktop OK"
