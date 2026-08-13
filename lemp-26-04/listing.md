# LEMP

A DigitalOcean 1-Click Droplet running a **LEMP** stack on **Ubuntu 26.04 LTS**: **Nginx**, **MySQL**, and **PHP 8.5 FPM**. Use it to host PHP applications and static sites with Certbot available for HTTPS.

## System Components

- Ubuntu 26.04 LTS
- Nginx
- MySQL (local)
- PHP 8.5 FPM (`php8.5-fpm`, `php8.5-mysql`, `php8.5-curl`, `php8.5-apcu`)
- Certbot (Nginx plugin)
- fail2ban, Postfix (loopback), UFW

## Droplet size

Minimum **1 GB RAM** (`s-1vcpu-1gb`). For production traffic or heavier PHP apps, **2 GB+** is recommended.

## Getting Started

1. Create a Droplet from this image.
2. Visit `http://YOUR_IP` to confirm the default LEMP landing page.
3. SSH in as **root**. The MySQL root password is in `/root/.digitalocean_password`.
4. Deploy your site under `/var/www/html` (or add Nginx server blocks under `/etc/nginx/sites-available`).
5. Optional HTTPS with a domain: `certbot --nginx -d example.com -d www.example.com`

## Service Management

| Action | Command |
|--------|---------|
| Nginx status | `systemctl status nginx` |
| Nginx start | `systemctl start nginx` |
| Nginx stop | `systemctl stop nginx` |
| Nginx restart | `systemctl restart nginx` |
| PHP-FPM status | `systemctl status php8.5-fpm` |
| PHP-FPM restart | `systemctl restart php8.5-fpm` |
| MySQL status | `systemctl status mysql` |
| MySQL start | `systemctl start mysql` |
| MySQL stop | `systemctl stop mysql` |
| MySQL restart | `systemctl restart mysql` |
| fail2ban status | `systemctl status fail2ban` |
| System packages | `apt update && apt upgrade` |
