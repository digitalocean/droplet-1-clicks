# Hardened Droplet (Ubuntu 24.04)

Packer builder for a Droplet 1-Click that boots with inbound traffic denied except
SSH, moves SSH to Tailscale, and publishes web apps through Cloudflare Tunnel.
`hardened-droplet` is a placeholder slug until Marketplace approval.

## Build

From the repository root:

```bash
export DIGITALOCEAN_API_TOKEN=...
packer build hardened-droplet-24-04/template.json
```

The last provisioner runs the Marketplace `99-img-check.sh`
(`scripts/999-img-check.sh`, vendored from
[marketplace-partners](https://github.com/digitalocean/marketplace-partners/tree/master/scripts)).
It exits non-zero on any failure, so a failing image fails the build.

Versions are pinned in `template.json`: `tailscale_version`, `cloudflared_version`.

## Layout

| Path | Purpose |
|------|---------|
| `scripts/010-hardened-droplet.sh` | Apt repos, Tailscale, cloudflared, `agent` user and sudoers, ufw baseline, metadata block for `agent`, permissions, removes Tailscale state from the image |
| `files/usr/local/bin/hardened` | `setup`, `connect`, `close-ssh`, `open-ssh`, `tunnel`, `welcome on\|off`, `status [--json]` |
| `files/usr/local/bin/expose` | Cloudflare quick tunnel previews (`expose@<port>.service`) |
| `files/etc/setup_wizard.sh` | One-time interactive wizard. Prompts only; work is done by `hardened`. |
| `files/var/lib/cloud/scripts/per-instance/001_onboot` | First boot: SSH baseline, user data (`TAILSCALE_AUTHKEY`, `CLOUDFLARE_TUNNEL_TOKEN`, `HARDENED_CLOSE_SSH`), wizard hook |
| `files/etc/systemd/system/` | `expose@.service`, `cloudflared-tunnel.service`, `hardened-welcome.service` (all `DynamicUser`; token in root-only `/etc/cloudflared/tunnel.env`) |
| `files/var/www/hardened-droplet/` | Welcome page, served on `127.0.0.1:8080` by `python3 -m http.server` when turned on |
| `files/etc/hardened-droplet/` | `AGENTS.md` (copied to `/root` and `/home/agent`), sshd hardening drop-in, agent sudoers source |
| `files/etc/apt/apt.conf.d/52hardened-droplet-unattended-upgrades` | Auto-updates for the Tailscale and cloudflared repos |
| `files/etc/update-motd.d/99-one-click` | MOTD with live status from `hardened status` |

## Behavior

**Image (build time):** ufw denies inbound traffic except `limit 22/tcp`. Tailscale is installed but not logged in, and its state directory is emptied so Droplets don't share a node identity. The `agent` user has a locked password and no keys.

**First boot:**
1. If root has SSH keys, they are copied (never moved: the Marketplace image check reads root's file) to the root-owned `/etc/ssh/authorized_keys.d/agent`, which `05-hardened-droplet.conf` adds to `AuthorizedKeysFile`. Nothing goes in `/home/agent/.ssh`, so agents can't add keys and the image check never sees them. `sshd-hardening.conf` then turns off password login. Without keys, password login stays on.
2. User data is read from the metadata service. Per-instance scripts run before user data scripts, so the script parses the raw `NAME=value` lines itself instead of relying on them having run.
3. With `TAILSCALE_AUTHKEY`: `hardened connect`, then `close-ssh --yes` (unless `HARDENED_CLOSE_SSH=no`). On failure, port 22 stays open and the error goes to `/var/lib/hardened-droplet/last-error` (shown in the MOTD).
4. With `CLOUDFLARE_TUNNEL_TOKEN`: `hardened tunnel`, then `hardened welcome on`, so a hostname pointed at `http://localhost:8080` shows the welcome page right away.
5. Unless already secured, the wizard hook is appended to `/root/.bashrc`. It runs only when stdin and stdout are terminals, so non-interactive SSH never sees it.

**Front door:** every Cloudflare route the image sets up or suggests points at `localhost:8080`. The welcome page holds that port until `hardened welcome off`; the customer's app then takes the port and existing URLs keep working.

**Lockout safety:** `close-ssh` refuses unless Tailscale reports `Running` with a 100.x address. Interactive runs also need a typed `yes`, and the wizard asks the customer to test SSH over Tailscale first. Recovery is the Recovery Console followed by `hardened open-ssh`. The Droplet Console can't be used because `900-cleanup.sh` purges `droplet-agent`.

## Smoke test

On a Droplet created from the snapshot with an SSH key and no user data:

```bash
nc -zv <ip> 22               # open
nc -zv -w3 <ip> 80 443       # closed
ssh root@<ip> true           # returns immediately (wizard must not run)
ssh root@<ip> hardened status --json
ssh root@<ip> "sudo -u agent curl -m3 http://169.254.169.254/metadata/v1/id"   # rejected
ssh root@<ip> "hardened welcome on && expose 8080 --json"   # open the URL: welcome page
ssh root@<ip> "hardened welcome off && expose --stop 8080"
```

With `TAILSCALE_AUTHKEY` in user data: port 22 is closed from outside, and
`ssh root@<tailscale-name> hardened status --json` shows `public_ssh_open: false`.
