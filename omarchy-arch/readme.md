# Omarchy 1-Click builder

Builds a DigitalOcean Marketplace snapshot of [Omarchy](https://omarchy.org) — DHH's Arch Linux + Hyprland desktop OS — running natively on a droplet with browser-based remote desktop access.

## ⚠️ How this builder differs from the others in this repo

1. **Arch-based, not Ubuntu.** Omarchy requires vanilla Arch. The builder's base is a **custom image** (the official Arch cloud image uploaded to the team account as image ID `244474342`, variable `base_image_id`), not `ubuntu-24-04-x64`. Consequently the shared `common/scripts/*` (apt/lsb_release-based) are not used; Arch equivalents live in `scripts/`.
2. **SSH user is `arch`, not root.** The Arch cloud image disables root SSH; cloud-init injects keys for the `arch` user (passwordless sudo). All provisioner scripts run as `arch` and `sudo` where needed; files are uploaded to `/tmp/build-files` and moved into place by scripts.
3. **No Caddy / public HTTP.** The web interface (noVNC) is deliberately localhost-only, reached via SSH tunnel — VNC has weak native auth, so the tunnel *is* the security model.

## Base image provenance

The base is the **official Arch Linux cloud image**, built and signed by the Arch
Linux project's [arch-boxes](https://gitlab.archlinux.org/archlinux/arch-boxes)
CI and published on the Arch mirror network:

- Index: <https://geo.mirror.pkgbuild.com/images/> (any Arch mirror carries `images/`)
- File: `Arch-Linux-x86_64-cloudimg.qcow2` — qcow2 disk image with cloud-init,
  default user `arch` (passwordless sudo, no password set), btrfs root
- `images/latest/` is a **moving target** (new build ~monthly). Versioned
  releases live at `images/v<YYYYMMDD.buildid>/`, each with a `.SHA256` checksum
  and a `.sig` GPG signature alongside
- The custom image currently referenced by `base_image_id` (`244474342`,
  named `arch-cloudimg-omarchy` in the team account) was created 2026-09-07
  from the `v20260901.583572` build

To (re)create the custom image — prefer a pinned version over `latest`:

```bash
doctl compute image create arch-cloudimg-omarchy --region nyc3 \
  --image-url "https://geo.mirror.pkgbuild.com/images/v20260901.583572/Arch-Linux-x86_64-cloudimg-20260901.583572.qcow2" \
  --image-distribution "Arch Linux"
```

Wait for its status to become `available` (`doctl compute image get <id>`),
then set `base_image_id` in `template.json`. Note: custom images are
**per-team and per-region** — the ID must exist in the same account and
region (`nyc3`) the build runs in.

## Prerequisites

- `DIGITALOCEAN_API_TOKEN` exported (same as other builders)
- The base custom image available in the account/region (see above)

## Build

From the **repo root** (script paths in `template.json` are repo-relative,
matching the other builders):

```bash
packer build omarchy-arch/template.json
```

Takes ~45–55 minutes (≈950 packages, an 80 GB free-space zero-fill, and
snapshot creation). Build droplet: `s-2vcpu-4gb` (80 GB disk ⇒ snapshot
min-disk 80 GB).

## What the provisioners do

| Script | Purpose |
|---|---|
| `010-omarchy-install.sh` | Omarchy mirror + clone (pinned `omarchy_ref`, default `v3.8.5`) + **6 unattended-droplet patches** + stock installer under a pty |
| `020-remote-desktop.sh` | wayvnc (session autostart) + noVNC/websockify systemd service + per-instance onboot install |
| `030-optimize.sh` | Disable dead-hardware services, no NTP boot-block, journal cap, no screensaver/effects (CPU rendering), 1280x800@60 |
| `040-application-tag.sh` | `/var/lib/digitalocean/application.info` (Arch equivalent of the common script) |
| `900-cleanup.sh` | pacman cache purge, identity/credential scrub, cloud-init instance reset, host-key removal, zero-fill. **Must not use `cloud-init clean`** — it wipes `/var/lib/cloud/scripts/`, deleting the baked per-instance onboot script; it surgically removes `/var/lib/cloud/instances/*` instead (same approach as `common/scripts/900-cleanup.sh`) |

### The 6 installer patches (all in hardware-specific steps)

| File | Why |
|---|---|
| `install/preflight/guard.sh` | Requires limine bootloader / physical-machine layout |
| `install/login/limine-snapper.sh` | **Must not touch the bootloader.** Its own guard is defeated because base packages install the `limine` package |
| `install/login/hibernation.sh` | No hibernation in a VM |
| `install/login/plymouth.sh` | Boot splash invisible on a droplet; avoids initramfs risk |
| `install/first-run/firewall.sh` | First desktop boot enables ufw **deny-all → SSH lockout**; patch inserts `ufw allow 22/tcp` (path is `install/config/firewall.sh` on 4.x) |
| `install/post-install/finished.sh` | Interactive reboot prompt would hang an unattended build |

### First-boot behavior (per droplet)

`files/var/lib/cloud/scripts/per-instance/001_onboot` generates a unique password for the `arch` user (used to unlock the desktop), writes connection instructions + the password to `/etc/motd`, and stores a root-only copy in `/root/.omarchy-credentials`. SSH host keys and the user's SSH keys are provisioned fresh by cloud-init.

## Known limitations / future work

- **Omarchy 4.x**: upstream is rewriting its installer (ISO-first, different layout). This builder pins 3.8.x; expect rework when 4.0 stabilizes.
- CPU-rendered graphics (no video/3D), no audio device.
- `omarchy-update` works in place for packages/kernel (validated), but requires a login shell and interactive prompts; major version jumps should be image rebuilds.
