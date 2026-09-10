#!/bin/bash
#
# Poll for the detached Omarchy install (launched by 010) on a fresh SSH
# connection, so its mid-install network transition can't abort the build.
set -uo pipefail

echo "==> Waiting for Omarchy install to complete (timeout 40m)"
for i in $(seq 1 240); do
  if [[ -f /tmp/omarchy-build.done ]]; then
    echo "==> Installer finished"
    break
  fi
  if [[ -f /tmp/omarchy-build.failed ]]; then
    echo "ERROR: Omarchy installer reported failure"
    sudo tail -n 40 /tmp/omarchy-install-console.log 2>/dev/null
    exit 1
  fi
  sleep 10
done

if [[ ! -f /tmp/omarchy-build.done ]]; then
  echo "ERROR: timed out waiting for Omarchy install"
  sudo tail -n 40 /tmp/omarchy-install-console.log 2>/dev/null
  exit 1
fi

echo "==> Verifying install"
pacman -Q hyprland
[[ -d /etc/sddm.conf.d ]] || { echo "ERROR: sddm config missing"; exit 1; }
systemctl is-enabled sddm >/dev/null || { echo "ERROR: sddm not enabled"; exit 1; }
echo "==> Omarchy install OK"
