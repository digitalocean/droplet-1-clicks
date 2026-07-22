# Jellyfin 1-Click Application

Deploy [Jellyfin](https://jellyfin.org), a free and open-source media system that lets you manage and stream your media library from your own server.

## System Components

| Component | Details |
|-----------|---------|
| Ubuntu | 24.04 LTS |
| Docker | Container runtime (`docker.io`) |
| Jellyfin | `jellyfin/jellyfin:10.11.11` |
| Caddy | Reverse proxy with automatic Let's Encrypt TLS |
| UFW | Firewall (SSH 22, HTTP 80, HTTPS 443) |

## System Requirements

**Minimum Droplet size: `s-1vcpu-2gb` (2 GB RAM).** Jellyfin's media transcoding benefits from additional CPU and memory for larger libraries or concurrent streams.

| Use case | Recommended |
|----------|-------------|
| Light / small library | 2 GB RAM, 1 vCPU |
| Multiple streams / transcoding | 4 GB+ RAM, 2+ vCPU |

## Getting Started

1. **Create a Droplet** from this 1-Click image (use at least **2 GB RAM**).
2. **Open Jellyfin** at `https://your-droplet-ip` and finish the setup wizard right away to create your admin account.
3. **Add media** by uploading or mounting files under `/var/lib/jellyfin/media`, then configure libraries in the Jellyfin UI.

Jellyfin listens on `127.0.0.1:8096` only. Public access is through Caddy on ports 80/443.

### Custom Domain (Recommended)

1. Create a DNS A record pointing your domain to the Droplet IP.
2. SSH in and run:

```bash
sudo /opt/setup-jellyfin-domain.sh
```

3. Visit `https://your-domain` — Caddy obtains a Let's Encrypt certificate automatically.

## Managing Jellyfin

### systemd

```bash
systemctl start jellyfin
systemctl stop jellyfin
systemctl restart jellyfin
systemctl status jellyfin
```

### Helper scripts

```bash
/opt/start-jellyfin.sh
/opt/stop-jellyfin.sh
/opt/restart-jellyfin.sh
/opt/status-jellyfin.sh
sudo /opt/update-jellyfin.sh 10.11.11
```

### Update

```bash
sudo /opt/update-jellyfin.sh <version>
```

This pulls the requested `jellyfin/jellyfin` image tag, recreates the container, and keeps data under `/var/lib/jellyfin`.

## Data Locations

| Path | Purpose |
|------|---------|
| `/var/lib/jellyfin/config` | Server configuration |
| `/var/lib/jellyfin/cache` | Transcoding / metadata cache |
| `/var/lib/jellyfin/media` | Suggested media library root |

## Support

- [Jellyfin Documentation](https://jellyfin.org/docs/)
- [Jellyfin Docker Hub](https://hub.docker.com/r/jellyfin/jellyfin)
- [DigitalOcean Community](https://www.digitalocean.com/community)
