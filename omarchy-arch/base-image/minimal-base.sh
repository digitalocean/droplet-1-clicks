#!/bin/bash
# Minimal droplet-ization of a fresh Omarchy 4.0.3 ISO autoinstall.
# ONLY what must exist before Packer can reach a droplet:
#   1. BIOS boot path (DO custom images boot with BIOS; the ISO installs UEFI-only)
#   2. cloud-init with the DigitalOcean datasource (SSH key injection)
#   3. passwordless sudo (Packer provisioners depend on it)
# Everything else (remote desktop, fail2ban, tuning, onboot) is installed by the
# omarchy-arch Packer builder. Run as arch; bootstrap NOPASSWD sudo first.
set -euo pipefail

echo "==> Passwordless sudo for wheel (Packer provisioners and cloud images rely on it)"
sudo rm -f /etc/sudoers.d/04_arch   # ISO-created password rule; breaks sudo -v (see verifypw below)
printf "%%wheel ALL=(ALL) NOPASSWD: ALL\nDefaults verifypw = any\n" | sudo tee /etc/sudoers.d/99-wheel-nopasswd >/dev/null
sudo chmod 440 /etc/sudoers.d/99-wheel-nopasswd
sudo visudo -c >/dev/null

echo "==> Stock Arch mirrors as fallback (omarchy mirror is a curated subset)"
grep -q rackspace /etc/pacman.d/mirrorlist || sudo tee -a /etc/pacman.d/mirrorlist >/dev/null <<'EOF'
Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
EOF
sudo pacman -Syy >/dev/null

echo "==> cloud-init with DigitalOcean datasource"
sudo pacman -S --noconfirm --needed cloud-init cloud-guest-utils gptfdisk 2>&1 | tail -1
sudo tee /etc/cloud/cloud.cfg.d/90_digitalocean.cfg >/dev/null <<'EOF'
datasource_list: [ ConfigDrive, DigitalOcean, None ]
EOF
sudo tee /etc/cloud/cloud.cfg.d/91_default_user.cfg >/dev/null <<'EOF'
system_info:
  default_user:
    name: omarchy
    groups: [wheel]
    shell: /bin/bash
EOF
sudo systemctl enable cloud-init.target $(ls /usr/lib/systemd/system/ | grep -E "^cloud-(init|config|final)[a-z-]*\.service$" | tr "\n" " ") 2>&1 | tail -1

echo "==> BIOS boot path: BIOS boot partition + limine BIOS stage"
sudo sgdisk -n 3:34:2047 -t 3:ef02 -c 3:"BIOS boot" /dev/vda >/dev/null
sudo partprobe /dev/vda; sleep 1
sudo cp /usr/share/limine/limine-bios.sys /boot/
sudo limine bios-install /dev/vda 2>&1 | tail -1

echo "==> Classic kernel+initramfs entries (UKI cannot boot under BIOS)"
echo "ENABLE_UKI=no" | sudo tee /etc/limine-entry-tool.d/zz-droplet-bios.conf >/dev/null
sudo limine-mkinitcpio 2>&1 | tail -1
sudo rm -rf /boot/EFI/Linux            # remove now-unused UKI
sudo limine-update 2>&1 | tail -1

echo "==> Boot fixup (timeout + default_entry on the linux leaf), re-run on updates"
sudo tee /usr/local/bin/droplet-limine-fixup >/dev/null <<'EOF'
#!/bin/bash
# Re-assert droplet boot settings after limine.conf regeneration:
# boot timeout + default_entry pointed at the first BIOS-bootable
# (protocol: linux) leaf. UKI/EFI entries cannot boot under DO BIOS.
CONF=/boot/limine.conf
[ -f "$CONF" ] || exit 0
sed -i "s/^#\?timeout:.*/timeout: 3/" "$CONF"
grep -q "^timeout:" "$CONF" || sed -i "1i timeout: 3" "$CONF"
IDX=$(awk "/^[[:space:]]*\\/+/{n++} /^[[:space:]]*protocol: linux/{print n; exit}" "$CONF")
[ -n "$IDX" ] && sed -i "s/^default_entry:.*/default_entry: $IDX/" "$CONF"
EOF
sudo chmod 755 /usr/local/bin/droplet-limine-fixup
sudo mkdir -p /etc/pacman.d/hooks
sudo tee /etc/pacman.d/hooks/zz-droplet-limine.hook >/dev/null <<'EOF'
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = linux
Target = limine
Target = limine-*

[Action]
Description = Re-asserting droplet boot settings in limine.conf
When = PostTransaction
Exec = /usr/local/bin/droplet-limine-fixup
EOF
sudo /usr/local/bin/droplet-limine-fixup
sudo grep -E "^timeout|^default_entry" /boot/limine.conf

echo "==> Scrub (fresh-image semantics; journals DELETED, never truncated)"
sudo rm -rf /var/cache/pacman/pkg/* /var/log/journal/*
rm -f ~/.ssh/authorized_keys ~/.bash_history
sudo rm -f /root/.ssh/authorized_keys /root/.bash_history
sudo find /var/log -type f -name "*.log" -exec truncate -s0 {} \; 2>/dev/null || true
sudo shred --remove /etc/ssh/ssh_host_*key 2>/dev/null || true
sudo rm -f /etc/ssh/ssh_host_*key*
sudo rm -rf /var/lib/cloud/instances /var/lib/cloud/instance /var/lib/cloud/data
sudo truncate -s0 /etc/machine-id
sudo fstrim / 2>/dev/null || true
echo "==> MINIMAL_BASE_OK"
