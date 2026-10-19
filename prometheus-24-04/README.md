# Prometheus 1-Click Droplet

Packer template for a DigitalOcean Marketplace 1-Click image that runs [Prometheus](https://prometheus.io/) behind Caddy with automatic TLS.

## What's Included

- **Prometheus** `3.14.0` bound to `127.0.0.1:9090`
- **Caddy** reverse proxy with Let's Encrypt short-lived IP/domain certs
- **UFW** allowing SSH (22), HTTP (80), and HTTPS (443) only (port 9090 denied publicly)
- **Ubuntu 24.04 LTS** base image
- Helper scripts under `/opt/` and a `prometheus` systemd unit

## Building

From the `droplet-1-clicks` repository root:

```bash
export DIGITALOCEAN_API_TOKEN="your-token"

packer validate prometheus-24-04/template.json
packer build prometheus-24-04/template.json
```

## How It Works

1. Packer installs base packages, Prometheus, and Caddy.
2. Caddy and Prometheus stay stopped during the image build (no droplet IP yet for certs).
3. On first boot, `001_onboot` unlocks SSH, writes the Caddyfile and Prometheus `--web.external-url` with the public IP, then starts `prometheus` and `caddy`.
4. Users open `https://<droplet-ip>/` for the Prometheus UI/API.

## Files

| Path | Purpose |
|------|---------|
| `template.json` | Packer build template |
| `files/provision.sh` | Install Prometheus + Caddy |
| `files/ufw.sh` | Firewall (22/80/443; deny 9090) |
| `files/etc/caddy/Caddyfile.tmp` | Caddy TLS reverse-proxy template |
| `files/etc/systemd/system/prometheus.service` | systemd unit (loopback + external URL placeholder) |
| `files/etc/update-motd.d/99-one-click-prom` | MOTD with HTTPS URL |
| `files/opt/*.sh` | start / stop / restart / status / domain helpers |
| `files/var/lib/cloud/scripts/per-instance/001_onboot` | First-boot HTTPS wiring |
| `listing.md` | Marketplace catalog copy |

## Smoke Test Checklist

After creating a Droplet from the snapshot:

- [ ] `https://<ip>/` loads the Prometheus UI with a trusted shortlived LE cert
- [ ] Port 9090 is not publicly open (`ufw status` / external probe)
- [ ] `systemctl status prometheus` and `systemctl status caddy` are active
- [ ] MOTD shows the HTTPS URL
- [ ] `sudo /opt/setup-prometheus-domain.sh` configures TLS for a custom domain
