# Plex Media Server 1-Click Application

Deploy Plex Media Server on DigitalOcean and stream your personal video, music, and photo library to nearly any device. This 1-Click installs the official Plex Docker image with NGINX reverse proxy, firewall rules, and helper scripts for day-to-day management.

## What is Plex Media Server?

Plex organizes your personal media and streams it to phones, tablets, smart TVs, streaming sticks, and browsers. With your own Plex server you keep control of your files while using official Plex clients everywhere.

## Key Features

- Official `plexinc/pms-docker` container
- Web access through NGINX on port 80
- Direct Plex access on port 32400 for remote streaming
- Media storage at `/opt/plex/media`
- Systemd service and start/stop/restart/update helpers
- UFW firewall pre-configured for SSH, HTTP, HTTPS, and Plex
- fail2ban for SSH protection

## System Components

- Ubuntu 24.04 LTS
- Plex Media Server (`plexinc/pms-docker`)
- Docker and Docker Compose
- NGINX reverse proxy
- UFW firewall
- fail2ban
- certbot (optional custom-domain TLS)

## System Requirements

Plex benefits from CPU for transcoding and disk space for your library. Suggested sizes:

| Use case | RAM | CPU | Recommended Droplet |
|----------|-----|-----|---------------------|
| Light / small library | 4GB | 2CPU | s-2vcpu-4gb |
| Medium library / light transcoding | 8GB | 4CPU | s-4vcpu-8gb |
| Large library / frequent transcoding | 16GB+ | 8CPU | s-8vcpu-16gb |

**Minimum recommended:** 4 GB RAM. Attach Block Storage if your media library is large.

## Getting Started

1. Deploy this 1-Click from the DigitalOcean Marketplace (4 GB RAM or larger).
2. Wait 2–5 minutes after the Droplet becomes active for first-boot setup.
3. **Claim the server** (required once — Plex blocks claiming from a public IP):

   **Option A — SSH tunnel (recommended)**  
   From your laptop:
   ```bash
   ssh -L 8888:127.0.0.1:32400 root@YOUR_DROPLET_IP
   ```
   Open `http://localhost:8888/web`, sign in, and finish setup.

   **Option B — Claim token**  
   Open https://www.plex.tv/claim, copy the token, then on the Droplet:
   ```bash
   /opt/claim-plex.sh claim-XXXXXXXX
   ```
   Then open `http://YOUR_DROPLET_IP:32400/web`.

4. Enable remote access in Plex settings and set public port `32400`.
5. Upload media to `/opt/plex/media` and add libraries in the Plex UI (folder `/data`).

### Upload media example

```bash
mkdir -p /opt/plex/media/movies
scp example_video.mp4 root@YOUR_DROPLET_IP:/opt/plex/media/movies/
```

Then add a Movies library pointed at `/data/movies` in the Plex UI (container path for `/opt/plex/media`).

### Optional Block Storage

```bash
mkdir -p /opt/plex/media/volume
mount /dev/disk/by-id/scsi-0DO_Volume_YOUR_VOLUME /opt/plex/media/volume
echo "/dev/disk/by-id/scsi-0DO_Volume_YOUR_VOLUME /opt/plex/media/volume ext4 defaults,nofail,discard 0 0" >> /etc/fstab
docker restart plex
```

## Service Management

| Action | Command |
|--------|---------|
| Start | `/opt/start-plex.sh` or `systemctl start plex` |
| Stop | `/opt/stop-plex.sh` or `systemctl stop plex` |
| Restart | `/opt/restart-plex.sh` or `systemctl restart plex` |
| Update | `/opt/update-plex.sh` |
| Claim | `/opt/claim-plex.sh <token>` |
| Status | `systemctl status plex` |
| Logs | `docker compose -f /opt/plex/docker-compose.yml logs -f` |

## Software Included

| Software | Description |
|----------|-------------|
| Plex Media Server | Streams personal media to Plex clients |
| NGINX | Reverse proxy for HTTP access on port 80 |
| Docker | Runs the official Plex container |
| UFW | Firewall with ports 22, 80, 443, and 32400 open |
| fail2ban | Protects SSH from brute-force attempts |

## Important Ports

| Port | Purpose |
|------|---------|
| 22/tcp | SSH |
| 80/tcp | Web UI via NGINX |
| 443/tcp | HTTPS (optional after TLS setup) |
| 32400/tcp | Direct Plex access / remote streaming |

## Documentation

- [Plex Media Server Docker](https://github.com/plexinc/pms-docker)
- [Akamai / Linode Plex guide](https://www.akamai.com/cloud/marketplace-docs/guides/plex/)
