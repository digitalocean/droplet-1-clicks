#!/bin/bash
#
# Remote desktop: wayvnc + noVNC, both localhost-only (access via SSH tunnel).
set -euo pipefail

echo "==> Installing wayvnc"
sudo pacman -S --noconfirm --needed wayvnc

echo "==> Installing websockify + noVNC"
# The Omarchy stable mirror is a curated subset without these packages;
# temporarily swap back to the stock Arch mirrors.
sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.omarchy
sudo cp /etc/pacman.d/mirrorlist.orig /etc/pacman.d/mirrorlist
sudo pacman -Syy --noconfirm >/dev/null
sudo pacman -S --noconfirm --needed python-pipx
sudo cp /etc/pacman.d/mirrorlist.omarchy /etc/pacman.d/mirrorlist
sudo pacman -Syy --noconfirm >/dev/null

pipx install websockify
git clone --depth 1 https://github.com/novnc/noVNC ~/novnc
rm -rf ~/novnc/.git

echo "==> wayvnc autostarts with the Hyprland session"
grep -q wayvnc ~/.config/hypr/autostart.conf ||
  echo "exec-once = wayvnc 127.0.0.1 5900" >> ~/.config/hypr/autostart.conf

echo "==> Installing systemd units"
sudo cp /tmp/build-files/etc/systemd/system/novnc.service /etc/systemd/system/
sudo cp /tmp/build-files/etc/systemd/system/ensure-ssh-firewall.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable novnc.service ensure-ssh-firewall.service

echo "==> Enabling MOTD on login (Arch ships PrintMotd no)"
sudo cp /tmp/build-files/etc/ssh/sshd_config.d/10-omarchy-motd.conf /etc/ssh/sshd_config.d/

echo "==> Installing per-instance onboot script (unique password + MOTD per droplet)"
sudo mkdir -p /var/lib/cloud/scripts/per-instance
sudo cp /tmp/build-files/var/lib/cloud/scripts/per-instance/001_onboot /var/lib/cloud/scripts/per-instance/001_onboot
sudo chown root:root /var/lib/cloud/scripts/per-instance/001_onboot
sudo chmod 755 /var/lib/cloud/scripts/per-instance/001_onboot

echo "==> Remote desktop OK"
