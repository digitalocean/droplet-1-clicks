# Jellyfin 1-Click Droplet

Packer template for a DigitalOcean Marketplace 1-Click image that runs [Jellyfin](https://jellyfin.org) in Docker behind Caddy with automatic TLS.

## What's Included

- **Jellyfin** `10.11.11` (`jellyfin/jellyfin`) bound to `127.0.0.1:8096`
- **Caddy** reverse proxy with Let's Encrypt short-lived IP/domain certs (enabled on first SSH claim)
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
3. On first boot, `001_onboot` unlocks SSH, writes the Caddyfile and `JELLYFIN_PublishedServerUrl`, starts Jellyfin on localhost, keeps Caddy disabled, and installs a first-SSH claim hook in `/root/.bashrc`.
4. First SSH login runs `/opt/claim-jellyfin-access.sh`, which enables Caddy so HTTPS becomes public.
5. Users complete the Jellyfin setup wizard at `https://<droplet-ip>`.

## Files

| Path | Purpose |
|------|---------|
| `template.json` | Packer build template |
| `scripts/01-setup.sh` | Install Caddy, pull Jellyfin image (start deferred to first boot) |
| `files/etc/caddy/Caddyfile.tmp` | Caddy TLS reverse-proxy template |
| `files/etc/systemd/system/jellyfin.service` | systemd unit (`jellyfin-docker.sh`) |
| `files/etc/update-motd.d/99-one-click` | MOTD with usage instructions |
| `files/opt/jellyfin-docker.sh` | Container start/stop used by systemd |
| `files/opt/claim-jellyfin-access.sh` | First-SSH unlock for public HTTPS |
| `files/opt/*.sh` | start / stop / restart / status / update / domain helpers |
| `files/var/lib/cloud/scripts/per-instance/001_onboot` | First-boot SSH unlock + Caddy IP config |
| `listing.md` | Marketplace catalog copy |

## Smoke Test Checklist

After creating a Droplet from the snapshot:

- [ ] Packer build finished with no interactive/TTY hang
- [ ] Before first SSH, `https://<ip>` is not serving the Jellyfin wizard (Caddy inactive)
- [ ] After first SSH, claim script unlocks HTTPS and `https://<ip>` reaches the wizard
- [ ] Port 8096 is not publicly open (`ufw status` / external probe)
- [ ] `systemctl status jellyfin` and (after claim) `systemctl status caddy` are active
- [ ] MOTD shows claim status, HTTPS URL, and helper commands
- [ ] `sudo /opt/setup-jellyfin-domain.sh` configures TLS for a custom domain
