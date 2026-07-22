# Craft CMS 1-Click

Deploy [Craft CMS](https://craftcms.com/) on DigitalOcean with Caddy, PHP 8.3, and MySQL on Ubuntu 24.04.

## Included software

- Ubuntu 24.04 LTS
- Craft CMS 5.10.11
- Caddy (short-lived Let's Encrypt for IP HTTPS)
- PHP 8.3 FPM
- MySQL
- Composer
- UFW firewall (ports 22, 80, 443)
- fail2ban

## Getting started

1. Create a Droplet from this 1-Click (2 GB RAM recommended).
2. Wait about 1–2 minutes for first-boot database setup.
3. Visit the Droplet IP — you will see a **setup-pending** page until SSH setup finishes.
4. SSH in as `root` to run `/root/craft_setup.sh` (admin account + HTTPS).
5. Open `https://your-droplet-ip` and `https://your-droplet-ip/admin`.

Credentials are saved in `/root/.digitalocean_password`.

- Project path: `/var/www/craft`
- Web root: `/var/www/craft/web`
- Custom domain: `/root/craft_setup_domain.sh`

### Service helpers

```bash
/opt/start-craft.sh
/opt/stop-craft.sh
/opt/restart-craft.sh
/opt/update-craft.sh
/opt/status-craft.sh
```

## Build

```bash
export DIGITALOCEAN_API_TOKEN=...
make validate-craftcms-24-04
make build-craftcms-24-04
```

Override the Craft version (`application_version` pins both the Marketplace tag and Composer install):

```bash
packer build \
  -var 'application_version=5.10.11' \
  craftcms-24-04/template.json
```
