# Craft CMS 1-Click

Deploy [Craft CMS](https://craftcms.com/) on DigitalOcean with Nginx, PHP 8.3, and MySQL on Ubuntu 24.04.

## Included software

- Ubuntu 24.04 LTS
- Craft CMS 5.10.11
- Nginx
- PHP 8.3 FPM
- MySQL
- Composer
- Certbot (`python3-certbot-nginx`)
- UFW firewall (ports 22, 80, 443)

## Getting started

1. Create a Droplet from this 1-Click (2 GB RAM recommended).
2. Wait about 1–2 minutes for first-boot database setup.
3. SSH in as `root` to run the setup wizard, **or** open `http://your-droplet-ip` and finish the Craft web installer.

Credentials are saved in `/root/.digitalocean_password`.

- Site: `http://your-droplet-ip`
- Control Panel: `http://your-droplet-ip/admin`
- Project path: `/var/www/craft`
- Web root: `/var/www/craft/web`

### Enable HTTPS

```bash
certbot --nginx -d your.domain
```

## Build

```bash
export DIGITALOCEAN_API_TOKEN=...
make build-craftcms-24-04
```

Override the Craft version:

```bash
packer build \
  -var 'application_version=5.10.11' \
  -var 'craft_version=5.10.11' \
  craftcms-24-04/template.json
```
