#!/usr/bin/env bash
# Put vybench data on a DigitalOcean Block Storage volume when one is attached.
#
# Strict confinement lets MariaDB and the workers write only under
# /var/snap/vybench/common. A symlink to /mnt is denied, and the mariadb service
# does not plug removable-media. Bind-mounting the volume onto that path keeps
# the path the snap is allowed to use and stores the bytes on the volume.
#
# With no volume, this exits 0 and leaves data on the Droplet disk.
set -euo pipefail

COMMON=/var/snap/vybench/common
MARKER=.vybench-on-volume
FSTAB=/etc/fstab

log() { echo "==> [mount-volume] $*"; }

volume_mounts() {
  # Find the mountpoint(s) of any attached DO Block Storage volume by asking
  # the kernel, not by guessing a directory-naming convention. DigitalOcean's
  # own automount names the mountpoint after the volume, but systemd mount
  # units can't contain a literal "-" (it's the path-separator escape), so a
  # volume named "vybench-test-vol" ends up mounted at
  # /mnt/vybench_test_vol -- hyphens become underscores. A glob like
  # /mnt/vybench-* silently misses that. Querying findmnt against the actual
  # by-id device is correct regardless of what DO (or the operator, for a
  # manually-mounted volume) named the mountpoint.
  local link dev mp
  shopt -s nullglob
  for link in /dev/disk/by-id/scsi-0DO_Volume_*; do
    case "$link" in
      *-part*) continue ;;
    esac
    if [ -e "${link}-part1" ]; then
      dev=$(readlink -f "${link}-part1")
    else
      dev=$(readlink -f "$link")
    fi
    [ -b "$dev" ] || continue
    mp=$(findmnt -n -o TARGET -S "$dev" 2>/dev/null | head -n1)
    [ -n "$mp" ] || continue
    printf '%s\n' "$mp"
  done
}

largest_mount() {
  local best="" best_kb=0 m kb
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    kb=$(df -P -k "$m" | awk 'NR==2 {print $2}')
    if [ "$kb" -gt "$best_kb" ]; then
      best_kb=$kb
      best=$m
    fi
  done < <(volume_mounts)
  printf '%s' "$best"
}

mount_unmounted_devices() {
  local link dev mp uuid fstype
  shopt -s nullglob
  for link in /dev/disk/by-id/scsi-0DO_Volume_*; do
    case "$link" in
      *-part*) continue ;;
    esac
    if [ -e "${link}-part1" ]; then
      dev=$(readlink -f "${link}-part1")
    else
      dev=$(readlink -f "$link")
    fi
    [ -b "$dev" ] || continue
    if findmnt -n -S "$dev" >/dev/null 2>&1; then
      continue
    fi
    fstype=$(blkid -o value -s TYPE "$dev" 2>/dev/null || true)
    if [ -z "$fstype" ]; then
      log "Formatting $dev (ext4)..."
      mkfs.ext4 -F -L vybench "$dev"
      fstype=ext4
    fi
    mp="/mnt/vybench-$(basename "$dev")"
    mkdir -p "$mp"
    log "Mounting $dev on $mp..."
    mount -o defaults,nofail,discard,noatime "$dev" "$mp"
    uuid=$(blkid -o value -s UUID "$dev" 2>/dev/null || true)
    if [ -n "$uuid" ] && ! grep -q "UUID=${uuid}" "$FSTAB"; then
      printf 'UUID=%s %s %s defaults,nofail,discard,noatime 0 2\n' "$uuid" "$mp" "$fstype" >> "$FSTAB"
    fi
    break
  done
}

ensure_bind_fstab() {
  local src=$1
  if grep -qE '[[:space:]]/var/snap/vybench/common[[:space:]]' "$FSTAB"; then
    return 0
  fi
  printf '%s %s none bind,nofail 0 0\n' "$src" "$COMMON" >> "$FSTAB"
}

if [ -f "$COMMON/$MARKER" ]; then
  log "Site data is already on block storage."
  exit 0
fi

udevadm settle || true

tries=2
if [ ! -f /opt/vybench/.first_boot_done ]; then
  tries=15
fi
# Tests set this so a machine with no volume does not sit through the boot wait.
if [ "${VYBENCH_VOLUME_WAIT:-}" = "0" ]; then
  tries=1
fi

# Prefer DigitalOcean's own automount (/mnt/volume_*). Only format and mount
# ourselves if a volume device is present and still unmounted after the wait.
mp=""
i=0
while [ "$i" -lt "$tries" ]; do
  mp=$(largest_mount)
  if [ -n "$mp" ]; then
    break
  fi
  if ! compgen -G '/dev/disk/by-id/scsi-0DO_Volume_*' >/dev/null && [ "$i" -ge 2 ]; then
    break
  fi
  i=$((i + 1))
  if [ "$i" -lt "$tries" ]; then
    log "Waiting for a Block Storage volume ($i/$tries)..."
    sleep 3
  fi
done

if [ -z "$mp" ]; then
  mount_unmounted_devices
  mp=$(largest_mount)
fi

if [ -z "$mp" ]; then
  log "No Block Storage volume attached. Data stays on the Droplet disk."
  exit 0
fi

DATA="$mp/vybench-common"
log "Using volume mounted at $mp."

size_kb=$(df -P -k "$mp" | awk 'NR==2 {print $2}')
if [ "$size_kb" -lt 26214400 ]; then
  log "Volume is under 25 GB. A production ERPNext site usually wants more."
fi

need_kb=$(du -sk "$COMMON" | awk '{print $1}')
have_kb=$(df -P -k "$mp" | awk 'NR==2 {print $4}')
if [ "$have_kb" -lt $((need_kb + 102400)) ]; then
  log "Volume has ${have_kb} KB free; vybench data needs about ${need_kb} KB. Leaving data on the Droplet disk."
  exit 0
fi

restart=0
if systemctl is-active --quiet snap.vybench.mariadb.service 2>/dev/null; then
  log "Stopping vybench so data can move..."
  snap stop vybench
  restart=1
fi

if [ ! -f "$DATA/$MARKER" ]; then
  log "Copying $COMMON to $DATA..."
  rm -rf "$DATA"
  mkdir -p "$DATA"
  # Skip runtime sockets; the services recreate $COMMON/run.
  tar -C "$COMMON" --one-file-system --exclude='./run' -cf - . | tar -C "$DATA" -xf -
  mkdir -p "$DATA/run"
  touch "$DATA/$MARKER"
fi

if ! mountpoint -q "$COMMON"; then
  log "Bind-mounting $DATA onto $COMMON..."
  mount --bind "$DATA" "$COMMON"
fi

ensure_bind_fstab "$DATA"

if [ "$restart" = 1 ]; then
  log "Starting vybench..."
  snap start vybench
fi

log "Persistent storage is $DATA."
