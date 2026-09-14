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
sudo find /var/log -type f -mtime -1 -not -path "*/journal/*" -exec truncate -s 0 {} \; 2>/dev/null
sudo rm -rf /var/log/*.gz /var/log/*.[0-9] 2>/dev/null
# journals must be DELETED, never truncated: zero-length .journal files are
# corrupt, and fail2ban's systemd backend dies on them (ENODATA)
sudo rm -rf /var/log/journal/*
# shred (not just rm) the host private keys: fstrim excludes deleted blocks
# from the snapshot, and shredding covers any extent TRIM might skip
sudo shred --remove /etc/ssh/ssh_host_*key 2>/dev/null
sudo rm -f /etc/ssh/ssh_host_*key*
# NOT `cloud-init clean`: it would wipe all of /var/lib/cloud, including the
# baked-in per-instance onboot script.
sudo rm -rf /var/lib/cloud/instances/* /var/lib/cloud/instance /var/lib/cloud/data/*
sudo rm -f /var/log/cloud-init*.log
sudo truncate -s0 /etc/machine-id
history -c || true
unset HISTFILE || true

echo "==> Discarding free space for snapshot compression"
# fstrim, NOT the traditional dd zero-fill. Measured on DO custom-image
# droplets: fstrim snapshots are 6.3 GiB; dd zero-fill balloons them to
# 76 GiB (every touched block counts as allocated, zeros are not compressed
# away). dd also cannot fill a compress=zstd btrfs without nodatacow tricks.
sudo fstrim -v /
sudo sync
sudo bash -c 'cat /dev/null > /var/log/lastlog; cat /dev/null > /var/log/wtmp' 2>/dev/null

echo "==> Cleanup OK"
exit 0
