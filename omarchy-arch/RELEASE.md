# Omarchy 1-Click release runbook

The recurring process for refreshing the Omarchy image: extracting a disk
image from the KVM build host, uploading it to DigitalOcean, and shipping a
new Marketplace snapshot.

## Cadence

| Trigger | What to refresh |
|---|---|
| New Omarchy release (watch [omarchy.org](https://omarchy.org) / `basecamp/omarchy` tags) | Base image + Packer snapshot |
| Monthly (security refresh, no Omarchy release) | Packer snapshot only (packages come from the mirrors at build time) |
| 1-Click behavior change (scripts in this directory) | Packer snapshot only |
| do-agent / droplet-agent release worth taking | Bump the pinned version in `scripts/035-*.sh`, Packer snapshot only |

Base rebuilds are the expensive path (~45 min); most releases are
Packer-only (~15 min).

## Prerequisites

- A KVM-capable build host (any droplet with `/dev/kvm`; install
  `qemu-kvm libvirt-daemon-system virtinst ovmf genisoimage libguestfs-tools`)
- `doctl` authenticated against the team that owns the images
- `DIGITALOCEAN_API_TOKEN` exported locally for Packer

## Part 1: Base image (only when Omarchy ships a new version)

Follow [base-image/README.md](base-image/README.md) for the full procedure
(ISO download + checksum, cidata autoinstall seed, unattended VM install,
`minimal-base.sh`, BIOS boot verification). It ends with a powered-off VM
disk at `/var/lib/libvirt/images/<name>.qcow2`. Then extract and upload as
below.

## Part 2: Extract a disk image from the KVM host

Always work from a **shut-down** VM (a live disk snapshot is corrupt):

```bash
virsh shutdown <vm-name>        # wait for "shut off" in `virsh list --all`
qemu-img convert -O qcow2 -c \
  /var/lib/libvirt/images/<vm-name>.qcow2 /root/omarchy-base-<version>.qcow2
qemu-img info /root/omarchy-base-<version>.qcow2   # sanity: virtual 60G, disk size ~4-5G
```

`-c` compresses; a scrubbed + fstrimmed 60 GiB disk lands around 4.5 GiB.
If the size is tens of GiB, the scrub or fstrim step was skipped: boot the
VM, re-run the scrub block of `minimal-base.sh`, shut down, convert again.

## Part 3: Upload the image to DigitalOcean

DO imports custom images by **fetching a URL** (there is no direct file
upload in `doctl`). Two options:

**A. Serve it from the build host (simplest, used for all builds so far):**

```bash
# on the build host
cd /root && python3 -m http.server 8123 &

# from anywhere with doctl
doctl compute image create omarchy-<version>-base --region nyc3 \
  --image-url "http://<build-host-ip>:8123/omarchy-base-<version>.qcow2" \
  --image-distribution "Arch Linux" \
  --image-description "Omarchy <version> minimal base (ISO autoinstall + BIOS boot + cloud-init)"
```

Note the returned image ID, then poll until `available` (import takes
5-15 min; `pending` is normal):

```bash
doctl compute image get <image-id> --format ID,Name,Status
```

Kill the HTTP server afterwards (`pkill -f "http.server 8123"`).

**B. Via Spaces (if the build host is not reachable over HTTP):** upload the
qcow2 to a Space with `s3cmd`/`aws s3`, make the object public (or presign),
and pass that URL to `--image-url`. Remember to delete the object after
import.

Gotchas seen in practice:
- Python's single-threaded `http.server` can drop a connection mid-fetch;
  DO's importer retries, but if the import errs, just create the image again.
- Custom images are **per-team**: the token used by `doctl` decides which
  team owns the image, and Packer's token must match.
- The image must be fetched from a public URL; keep the window short.

## Part 4: Ship the Packer snapshot

```bash
# 1. Point the template at the (new) base image
#    omarchy-arch/template.json -> "base_image_id": "<image-id>"
#    and bump "application_version" if Omarchy changed.

# 2. Build from the repo root
packer build omarchy-arch/template.json
# Known flake: a 422 "invalid key identifiers" within ~10s is a DO API race
# on Packer's temporary SSH key. Retry after 45+ seconds (immediate retries
# can hit the same window).
```

The build prints the snapshot name and ID on success (~15 min).

## Part 5: Validate before touching the listing

Create a droplet from the snapshot and run the acceptance checks. Minimum
bar (all must pass on a fresh droplet, ~2 min after creation):

```bash
doctl compute droplet create omarchy-validate --region nyc3 \
  --size s-4vcpu-8gb --image <snapshot-id> --ssh-keys <your-key-id> --wait
ssh omarchy@<ip> '
  pacman -Q omarchy; pgrep Hyprland && pgrep wayvnc
  systemctl is-active novnc fail2ban do-agent
  systemctl --failed --no-legend | wc -l          # expect 0
  grep -c passwd /etc/motd                        # expect 1, and NO password in it
  sudo ufw status | grep -c "^22"                 # expect >=1
  echo $OMARCHY_PATH                              # expect /usr/share/omarchy
  omarchy-update -y                               # must complete unattended
'
```

Also confirm the snapshot size is in the ~6-7 GiB range (a 70+ GiB snapshot
means the cleanup's fstrim did not run).

## Part 6: Publish and clean up

1. Vendor Portal: update the Omarchy listing's image to the new snapshot ID
   and the version field.
2. Delete the validation droplet.
3. Delete superseded snapshots and, after a new base is proven, the previous
   base image (keep exactly one known-good previous snapshot as rollback).
4. On the build host: remove old qcow2 files and stop any leftover HTTP
   server.
