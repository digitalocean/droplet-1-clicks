#!/bin/bash
#
# Arch port of common/scripts/900-cleanup.sh (which is apt-based).
set -uo pipefail

echo "==> Purging package cache and temp files"
sudo rm -rf /var/cache/pacman/pkg/* /tmp/build-files /var/tmp/*
sudo journalctl --vacuum-size=32M >/dev/null 2>&1

echo "==> Scrubbing identity and credentials"
rm -f ~/.ssh/authorized_keys ~/.bash_history ~/.zsh_history
sudo rm -f /root/.ssh/authorized_keys /root/.bash_history
sudo find /var/log -type f -mtime -1 -exec truncate -s 0 {} \; 2>/dev/null
sudo rm -rf /var/log/*.gz /var/log/*.[0-9] 2>/dev/null
sudo rm -f /etc/ssh/ssh_host_*key*
# NOT `cloud-init clean`: it would wipe all of /var/lib/cloud, including the
# baked-in per-instance onboot script.
sudo rm -rf /var/lib/cloud/instances/* /var/lib/cloud/instance /var/lib/cloud/data/*
sudo rm -f /var/log/cloud-init*.log
sudo truncate -s0 /etc/machine-id
history -c || true
unset HISTFILE || true

echo "==> Zero-filling free space for snapshot compression"
sudo dd if=/dev/zero of=/zerofile bs=4M 2>/dev/null || true
sudo sync
sudo rm -f /zerofile
sudo sync
sudo bash -c 'cat /dev/null > /var/log/lastlog; cat /dev/null > /var/log/wtmp' 2>/dev/null

echo "==> Cleanup OK"
exit 0
