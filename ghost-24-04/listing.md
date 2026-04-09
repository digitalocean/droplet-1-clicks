# Ghost

A DigitalOcean 1-Click Droplet running **Ghost** (publishing platform) on **Ubuntu 24.04 LTS** with MySQL, **nginx** (configured by Ghost CLI), Postfix, fail2ban, and UFW. The first time you SSH in as root, the installer finishes Ghost setup interactively; after that, use the **`ghost-mgr`** user for day-to-day Ghost administration.

## System Components

- Ubuntu 24.04 LTS  
- Ghost (installed via Ghost CLI on first boot; version pinned in the image build)  
- Node.js 22 LTS (NodeSource)  
- MySQL 8  
- nginx (reverse proxy / SSL via Ghost CLI)  
- Postfix (loopback-only for mail)  
- fail2ban  
- UFW (SSH limited; HTTP/HTTPS for nginx)  

## Droplet size

[Ghost’s documentation](https://ghost.org/docs/hosting/) recommends **at least 1 GB of RAM** for Ghost on a supported production server. This Marketplace image is built and tested on a **2 GB** Droplet (`s-1vcpu-2gb`) because Ghost shares the machine with MySQL, nginx, Postfix, and the OS, and first-time setup (`ghost install`, database work) needs more headroom than steady traffic alone. Starting at **2 GB** avoids swapping and out-of-memory issues during provisioning; you can resize later if your traffic grows.

## Getting Started

1. Create a Droplet from this image (2 GB RAM or larger is recommended).  
2. Optionally point a domain’s **A record** at the Droplet’s public IPv4 address and wait for DNS to propagate.  
3. SSH in as **root** once. The bootstrap script runs **Ghost install** and will ask for your site URL and SSL details.  
4. After setup, manage Ghost as **`ghost-mgr`**: `sudo -i -u ghost-mgr`  
5. Read `/root/.digitalocean_password` for the MySQL password set at first boot, and consider running `mysql_secure_installation` before production use.

## Service Management

Use **`ghost-mgr`** for Ghost (run from `/var/www/ghost` or use `ghost` CLI which knows the install path):

| Action | Command (as `ghost-mgr`, or with `sudo -u ghost-mgr -H bash -lc '...'`) |
|--------|--------------------------------------------------------------------------|
| Ghost status | `ghost status` |
| Stop | `ghost stop` |
| Start | `ghost start` |
| Restart | `ghost restart` |
| Update Ghost | `ghost update` (from the install directory) |
| Logs | `ghost log` or files under `/var/www/ghost/content/logs/` |

Core stack services (run as root):

| Service | Status example |
|---------|----------------|
| nginx | `sudo systemctl status nginx` |
| MySQL | `sudo systemctl status mysql` |
| Postfix | `sudo systemctl status postfix` |

System packages update with `sudo apt update && sudo apt upgrade`. After upgrading system Node or MySQL, follow [Ghost’s self-hosting docs](https://ghost.org/docs/hosting/) for any stack-specific steps.
