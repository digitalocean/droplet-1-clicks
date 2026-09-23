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
# Same reasoning for the remote desktop's TLS keypair. A normal build never
# creates it (001_onboot does, at first boot), but anyone who ran that script
# while debugging on the build droplet would otherwise ship one shared private
# key to every droplet created from the snapshot.
sudo shred --remove /etc/hypr-rdp/tls.key 2>/dev/null
sudo rm -f /etc/hypr-rdp/tls.key /etc/hypr-rdp/tls.crt
# The RDP password lives in tmpfs and so cannot reach the image, but hypr-rdp
# also reads ~/.config/hypr-rdp/config.toml, which accepts a plaintext
# `password` key. That one IS on disk, so anyone who hand-tested with a config
# file would bake their password into the snapshot.
rm -f ~/.config/hypr-rdp/config.toml
sudo rm -rf /run/hypr-rdp
# Clearing the marker puts the setup assistant back in front of the customer's
# first login.
sudo rm -f /var/lib/digitalocean/omarchy_setup_complete
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
