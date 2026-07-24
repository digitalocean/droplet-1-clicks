# Plex Media Server 1-Click Application

Deploy Plex Media Server on DigitalOcean and stream your personal video, music, and photo library to nearly any device. This 1-Click installs the official Plex Docker image with Caddy (automatic TLS), firewall rules, and helper scripts for day-to-day management.

## What is Plex Media Server?

Plex organizes your personal media and streams it to phones, tablets, smart TVs, streaming sticks, and browsers. With your own Plex server you keep control of your files while using official Plex clients everywhere.

## Key Features

- Official `plexinc/pms-docker` container
- HTTPS gated behind a setup-pending page until the server is claimed (prevents public claim takeover)
- After claim: HTTPS via Caddy (Let's Encrypt shortlived TLS) + direct access on port 32400
- Media storage at `/opt/plex/media`
- Systemd service and start/stop/restart/update/claim/status helpers
- UFW firewall pre-configured for SSH, HTTP, HTTPS, and Plex
- fail2ban for SSH protection

## System Components

- Ubuntu 24.04 LTS
- Plex Media Server (`plexinc/pms-docker`)
- Docker and Docker Compose
- Caddy reverse proxy with Let's Encrypt
- UFW firewall
- fail2ban

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
3. **Claim the server** (required — HTTPS proxy stays gated until claim):

   Visit `https://YOUR_DROPLET_IP` to see claim instructions.

   **Option A — SSH tunnel**  
   From your laptop:
   ```bash
   ssh -L 8888:127.0.0.1:32400 root@YOUR_DROPLET_IP
   ```
   Open `http://localhost:8888/web`, sign in, and finish setup. Then unlock HTTPS:
   ```bash
   sudo /opt/enable-plex-proxy.sh
   ```

   **Option B — Claim token**  
   Open https://www.plex.tv/claim, copy the token, then on the Droplet:
   ```bash
   /opt/claim-plex.sh claim-XXXXXXXX
   ```
   This claims the server and enables HTTPS automatically. Then open `https://YOUR_DROPLET_IP`.

4. Enable remote access in Plex settings and set public port `32400`.
5. Upload media to `/opt/plex/media` and add libraries in the Plex UI (folder `/data`).

### Custom domain (HTTPS)

After claim, point your domain’s A record at the Droplet, then run:

```bash
sudo /opt/setup-plex-domain.sh
```

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
| Unlock HTTPS | `/opt/enable-plex-proxy.sh` (after SSH-tunnel claim; verifies `PlexOnlineToken`, use `--force` to override) |
| Status | `/opt/status-plex.sh` (checks Docker container health) |
| Domain TLS | `/opt/setup-plex-domain.sh` (after claim) |
| Logs | `docker compose -f /opt/plex/docker-compose.yml logs -f` |

> Note: `plex.service` is a oneshot unit that starts Docker Compose. Prefer `/opt/status-plex.sh` over `systemctl is-active plex` to confirm the container is still healthy.

## Software Included

| Software | Description |
|----------|-------------|
| Plex Media Server | Streams personal media to Plex clients |
| Caddy | Reverse proxy with automatic Let's Encrypt TLS on 80/443 |
| Docker | Runs the official Plex container |
| UFW | Firewall with ports 22, 80, 443, and 32400 open |
| fail2ban | Protects SSH from brute-force attempts |

## Important Ports

| Port | Purpose |
|------|---------|
| 22/tcp | SSH |
| 80/tcp | HTTP (Caddy; redirects/ACME) |
| 443/tcp | HTTPS web UI via Caddy |
| 32400/tcp | Direct Plex access / remote streaming (localhost-only until claim; opened by `/opt/enable-plex-proxy.sh`) |

Only `32400/tcp` is published from the container for remote access MVP. Extra Plex discovery ports (DLNA / GDM UDP such as 1900, 32410–32414) are not exposed by default; enable them only if you need LAN discovery features.

## Documentation

- [DigitalOcean Marketplace — Plex](https://marketplace.digitalocean.com/apps/plex)
- [Plex Media Server Docker](https://github.com/plexinc/pms-docker)
