# Craft CMS 1-Click Application

Deploy [Craft CMS](https://craftcms.com/) on DigitalOcean with Caddy (automatic HTTPS), PHP 8.3 FPM, and MySQL on Ubuntu 24.04 LTS.

## What is Craft CMS?

Craft is a flexible, developer-friendly CMS for creating custom digital experiences. This 1-Click installs Craft 5 with a production-ready LAMP-alternative stack using Caddy as the edge web server.

## System Components

- Ubuntu 24.04 LTS
- Craft CMS 5.10.11
- PHP 8.3 FPM
- MySQL
- Caddy (short-lived Let's Encrypt certificates for IP access)
- Composer
- UFW firewall (22, 80, 443)
- fail2ban

## System Requirements

| Use case | RAM | Recommended |
|----------|-----|-------------|
| Small site | 2GB | s-1vcpu-2gb |
| Production | 4GB+ | s-2vcpu-4gb |

## Getting Started

1. Create a Droplet from this 1-Click (2 GB RAM minimum).
2. Wait 1–2 minutes for first-boot database setup.
3. Until you finish setup, visiting the Droplet IP shows a **setup-pending** page (Craft web installer is blocked).
4. SSH as `root` and complete the interactive wizard (`/root/craft_setup.sh`):
   ```bash
   ssh root@YOUR_DROPLET_IP
   ```
5. After setup, open:
   - Site: `https://YOUR_DROPLET_IP`
   - Control Panel: `https://YOUR_DROPLET_IP/admin`

MySQL passwords are saved in `/root/.digitalocean_password`.

### Custom domain (HTTPS)

Point DNS to the Droplet, then:

```bash
/root/craft_setup_domain.sh
```

## Service Management

| Action | Command |
|--------|---------|
| Start | `/opt/start-craft.sh` |
| Stop | `/opt/stop-craft.sh` |
| Restart | `/opt/restart-craft.sh` |
| Update Craft | `/opt/update-craft.sh` |
| Domain TLS | `/root/craft_setup_domain.sh` |
| Status | `/opt/status-craft.sh` |

## Software Included

| Software | Description |
|----------|-------------|
| Craft CMS | Content management system (pinned version in image) |
| Caddy | Reverse proxy / TLS termination |
| PHP 8.3 FPM | Application runtime |
| MySQL | Database |
| fail2ban | SSH brute-force protection |
| UFW | Firewall |

## Documentation

- [Craft CMS docs](https://craftcms.com/docs/5.x/)
- Caddy config: `/etc/caddy/Caddyfile`
