# Jellyfin 1-Click Droplet

Packer template for a DigitalOcean Marketplace 1-Click image that runs [Jellyfin](https://jellyfin.org) in Docker behind Caddy with automatic TLS.

## What's Included

- **Jellyfin** `10.11.11` (`jellyfin/jellyfin`) bound to `127.0.0.1:8096`
- **Caddy** reverse proxy with Let's Encrypt short-lived IP/domain certs
- **UFW** allowing SSH (22), HTTP (80), and HTTPS (443) only
- **Ubuntu 24.04 LTS** base image
- Helper scripts under `/opt/` and a `jellyfin` systemd unit

## Droplet Size

Build and recommend **`s-1vcpu-2gb`** (minimum 2 GB RAM). Smaller sizes are not sufficient for typical Jellyfin workloads.

## Building

From the `droplet-1-clicks` repository root:

```bash
export DIGITALOCEAN_API_TOKEN="your-token"

make validate-jellyfin-24-04
make build-jellyfin-24-04
```

Or with Packer directly:

```bash
packer validate jellyfin-24-04/template.json
packer build jellyfin-24-04/template.json
```

## How It Works

1. Packer installs Docker and app dependencies via `apt_packages`.
2. `scripts/01-setup.sh` enables Docker, installs Caddy (left disabled), pulls the pinned Jellyfin image, and prepares data dirs — it does **not** create the container or enable Caddy.
3. On first boot, `001_onboot` unlocks SSH, writes the Caddyfile with the droplet public IP, then enables/starts Jellyfin and Caddy.
4. Users access Jellyfin at `https://<droplet-ip>` and complete the setup wizard.

## Files

| Path | Purpose |
|------|---------|
| `template.json` | Packer build template |
| `scripts/01-setup.sh` | Install Docker app, Caddy, enable services |
| `files/etc/caddy/Caddyfile.tmp` | Caddy TLS reverse-proxy template |
| `files/etc/systemd/system/jellyfin.service` | systemd unit for the container |
| `files/etc/update-motd.d/99-one-click` | MOTD with usage instructions |
| `files/opt/*.sh` | start / stop / restart / status / update / domain helpers |
| `files/var/lib/cloud/scripts/per-instance/001_onboot` | First-boot SSH unlock + Caddy IP config |
| `listing.md` | Marketplace catalog copy |

## Smoke Test Checklist

After creating a Droplet from the snapshot:

- [ ] Packer build finished with no interactive/TTY hang
- [ ] `https://<ip>` reaches the Jellyfin setup wizard
- [ ] Port 8096 is not publicly open (`ufw status` / external probe)
- [ ] `systemctl status jellyfin` and `systemctl status caddy` are active
- [ ] MOTD shows HTTPS URL and helper commands
- [ ] `sudo /opt/setup-jellyfin-domain.sh` configures TLS for a custom domain
