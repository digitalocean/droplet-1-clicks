# Omarchy 1-Click builder

Builds a DigitalOcean Marketplace snapshot of [Omarchy](https://omarchy.org),
DHH's Arch Linux + Hyprland desktop OS, running natively on a droplet with
browser-based remote desktop access.

## Two-stage pipeline (4.x)

Omarchy 4.x installs exclusively from its ISO; there is no script installer to
run on an existing system (that was the 3.x approach this builder originally
used). The build is therefore split:

| Stage | Where | What |
|---|---|---|
| **Base image** | KVM VM, see [base-image/](base-image/README.md) | Stock ISO autoinstall + only what a droplet needs to boot and be reachable: BIOS boot path, cloud-init (DO datasource), passwordless sudo, scrub |
| **Packer** (this directory) | `packer build omarchy-arch/template.json` | Everything else, reviewable here: remote desktop (wayvnc + noVNC), fail2ban, autologin, cloud tuning, per-instance onboot, application tag, cleanup |

The base image changes only when a new Omarchy version ships; day-to-day
changes to the 1-Click live in the Packer scripts.

## How this builder differs from the others in this repo

1. **Arch/Omarchy-based, not Ubuntu.** The builder's base is a custom image
   (variable `base_image_id`), not `ubuntu-24-04-x64`; the shared
   `common/scripts/*` (apt-based) are not used.
2. **SSH user is `arch`, not root.** cloud-init injects keys for the `arch`
   user (passwordless sudo). Files are uploaded to `/tmp/build-files` and
   moved into place by scripts.
3. **No Caddy / public HTTP.** The web interface (noVNC) is deliberately
   localhost-only, reached via SSH tunnel; VNC has weak native auth, so the
   tunnel is the security model.
4. **Desktop config is Lua** (4.x API): `o.launch_on_start(...)`,
   `o.bind("SUPER + BackSpace", ...)`, `hl.config({...})`. Note the parser
   silently ignores invalid syntax only in .conf files; Lua errors surface as
   a config-error banner in the session.

## Build

From the **repo root**, with `DIGITALOCEAN_API_TOKEN` exported and
`base_image_id` in `template.json` pointing at the current base image:

```bash
packer build omarchy-arch/template.json
```

Takes ~10-15 minutes (packages, config, fstrim, snapshot). Build droplet:
`s-2vcpu-4gb` (80 GB disk ⇒ snapshot min-disk 80 GB).

## What the provisioners do

| Script | Purpose |
|---|---|
| `020-remote-desktop.sh` | SDDM autologin, wayvnc (session autostart, localhost), noVNC/websockify systemd service, MOTD-on-ssh, per-instance onboot install |
| `025-fail2ban.sh` | fail2ban sshd jail (systemd journal backend) + a one-line patch for the fail2ban 1.1.1 / Python 3.14 startup crash (upstream; a fixed package simply overwrites it) |
| `030-optimize.sh` | Disable dead-hardware services, journal cap, **stay-awake** (4.x's idle screensaver renders at 120fps; users re-enable with `omarchy toggle idle`), 1280x800@60 scale 1, no compositor effects, Super+BackSpace close binding |
| `035-do-agent.sh` | DigitalOcean monitoring agent (pinned release tarball; no Arch package, so no repo auto-updates; bump `DO_AGENT_VERSION` on rebuilds) |
| `040-application-tag.sh` | `/var/lib/digitalocean/application.info` |
| `900-cleanup.sh` | pacman cache purge, identity/credential scrub (host keys shredded), cloud-init instance reset, journal **deletion** (truncated journals are corrupt and break fail2ban), fstrim (measured: 6.3 GiB snapshots vs 76 GiB with dd zero-fill on DO). **Must not use `cloud-init clean`**: it wipes `/var/lib/cloud/scripts/`, deleting the baked per-instance onboot script |

### First-boot behavior (per droplet)

`files/var/lib/cloud/scripts/per-instance/001_onboot` sets a random password
for the `arch` user with pwgen so the account never keeps the build password;
it is stored only as a hash in `/etc/shadow`, never in a file or the MOTD;
users choose their own with `passwd` (the MOTD says so). It also writes
connection instructions to `/etc/motd`. SSH host keys and the user's SSH keys
are provisioned fresh by cloud-init.

## What droplets gain vs 3.x

- Omarchy is a pacman package (`omarchy 4.x`): `omarchy-update -y` updates
  non-interactively.
- limine + snapper boot-snapshot integration works (the 3.x build had to skip
  the bootloader entirely); update rollback from the boot menu is available.
- The installer opens SSH itself when built with authorized_keys (no more
  first-boot firewall lockout class of bugs; the `ensure-ssh-firewall`
  boot guard remains as insurance).

## Known limitations

- CPU-rendered graphics (no video/3D), no audio device.
- Marketplace `img_check` rejects non-listed distros (Arch); a policy
  conversation with the Marketplace team, not a technical gap.
