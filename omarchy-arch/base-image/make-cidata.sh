#!/bin/bash
#
# Build the cidata autoinstall seed for the Omarchy ISO (see README.md).
# Produces cidata.iso next to this script. Run on the KVM build host.
#
# Usage: ./make-cidata.sh <build-password> <path-to-authorized_keys> [disk-gib]
set -euo pipefail

PASSWORD=${1:?usage: make-cidata.sh <build-password> <authorized_keys> [disk-gib]}
KEYS=${2:?path to authorized_keys required}
DISK_GIB=${3:-60}

HERE=$(cd "$(dirname "$0")" && pwd)
OUT="$HERE/cidata"
rm -rf "$OUT" && mkdir -p "$OUT"

HASH=$(openssl passwd -6 "$PASSWORD")

# archinstall config matching what the Omarchy 4.x configurator writes for a
# full-disk unencrypted install (limine, btrfs subvolumes, 2 GiB ESP).
python3 - "$OUT/user_configuration.json" "$DISK_GIB" <<'PYEOF'
import json, sys
out, disk_gib = sys.argv[1], int(sys.argv[2])
mib = 1024 * 1024; gib = mib * 1024
disk = disk_gib * gib
boot_start, boot_size = mib, 2 * gib
main_start = boot_start + boot_size
main_size = disk - main_start - mib
cfg = {
  "app_config": None, "archinstall-language": "English", "auth_config": {},
  "audio_config": {"audio": "pipewire"},
  "bootloader_config": {"bootloader": "Limine", "uki": False, "removable": False},
  "custom_commands": [],
  "omarchy_install": {"mode": "full_disk", "defer_provisioning": False, "target_mount": "/mnt",
    "boot": {"esp_mount": "/boot", "esp_path": "/EFI/limine", "efi_binary": "limine_x64.efi", "enable_fallback": True},
    "storage": {"kernel": "linux"}},
  "disk_config": {"config_type": "default_layout", "device_modifications": [{
    "device": "/dev/vda", "wipe": True, "partitions": [
      {"btrfs": [], "dev_path": None, "flags": ["boot", "esp"], "fs_type": "fat32", "mount_options": [],
       "mountpoint": "/boot", "obj_id": "ea21d3f2-82bb-49cc-ab5d-6f81ae94e18d",
       "size": {"sector_size": {"unit": "B", "value": 512}, "unit": "B", "value": boot_size},
       "start": {"sector_size": {"unit": "B", "value": 512}, "unit": "B", "value": boot_start},
       "status": "create", "type": "primary"},
      {"btrfs": [{"mountpoint": "/", "name": "@"}, {"mountpoint": "/home", "name": "@home"},
                 {"mountpoint": "/var/log", "name": "@log"}, {"mountpoint": "/var/cache/pacman/pkg", "name": "@pkg"}],
       "dev_path": None, "flags": [], "fs_type": "btrfs", "mount_options": ["compress=zstd"],
       "mountpoint": None, "obj_id": "8c2c2b92-1070-455d-b76a-56263bab24aa",
       "size": {"sector_size": {"unit": "B", "value": 512}, "unit": "B", "value": main_size},
       "start": {"sector_size": {"unit": "B", "value": 512}, "unit": "B", "value": main_start},
       "status": "create", "type": "primary"}]}]},
  "hostname": "omarchy", "kernels": ["linux"],
  "network_config": {"type": "iso"}, "ntp": True, "parallel_downloads": 8,
  "script": None, "services": [], "swap": True, "timezone": "UTC",
  "locale_config": {"kb_layout": "us", "sys_enc": "UTF-8", "sys_lang": "en_US.UTF-8"},
  "mirror_config": {"custom_repositories": [], "custom_servers": [
      {"url": "https://mirror.omarchy.org/$repo/os/$arch"},
      {"url": "https://mirror.rackspace.com/archlinux/$repo/os/$arch"},
      {"url": "https://geo.mirror.pkgbuild.com/$repo/os/$arch"}],
    "mirror_regions": {}, "optional_repositories": []},
  "packages": ["base-devel", "git", "omarchy-keyring", "omarchy-settings", "omarchy"],
  "profile_config": {"gfx_driver": None, "greeter": None, "profile": {}},
  "version": "3.0.9"
}
json.dump(cfg, open(out, "w"), indent=2)
PYEOF

python3 - "$OUT/user_credentials.json" "$HASH" <<'PYEOF'
import json, sys
json.dump({"root_enc_password": sys.argv[2],
           "users": [{"enc_password": sys.argv[2], "groups": [], "sudo": True, "username": "arch"}]},
          open(sys.argv[1], "w"), indent=2)
PYEOF

cp "$KEYS" "$OUT/authorized_keys"
genisoimage -quiet -output "$HERE/cidata.iso" -volid cidata -joliet -rock "$OUT"
echo "cidata.iso written: $(ls -la "$HERE/cidata.iso" | awk '{print $5}') bytes"
