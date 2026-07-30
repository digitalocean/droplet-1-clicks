# WordPress + phpMyAdmin

A DigitalOcean 1-Click Droplet running **WordPress** with **phpMyAdmin** on **Ubuntu 24.04 LTS**, using **Caddy** (automatic HTTPS), **PHP 8.3 FPM**, and **MySQL**. Optionally pair the Droplet with a DigitalOcean Managed MySQL database (**Add a Database**); first-login setup configures both WordPress and phpMyAdmin for DBaaS automatically.

## System Components

- Ubuntu 24.04 LTS
- WordPress (latest stable)
- phpMyAdmin (latest stable, served at `/phpmyadmin`)
- Caddy (HTTP/HTTPS, Let's Encrypt)
- PHP 8.3 FPM
- MySQL 8.4 (local; disabled when Managed Database is used)
- WP-CLI, WP-Fail2Ban, fail2ban, Postfix (loopback), UFW

## Droplet size

Minimum **2 GB RAM** (MySQL 8.4, PHP-FPM, Caddy, WordPress, and phpMyAdmin on one Droplet). For production traffic or heavier plugin sets, **4 GB+** is recommended.

## Getting Started

1. Create a Droplet from this image.
2. Optionally select **Add a Database** for Managed MySQL, and add the Droplet IP to the cluster **Trusted Sources**.
3. Visit `http://YOUR_IP` for the setup-pending page, then SSH in as **root** to finish automatic HTTPS setup.
4. Open WordPress at `https://YOUR_IP` and phpMyAdmin at `https://YOUR_IP/phpmyadmin`.
5. Local phpMyAdmin login: user `admin`, password in `/root/.digitalocean_password` (`admin_mysql_pass`). With Managed Database, use the credentials written to that same file after setup.
6. Optional custom domain: `/root/wp_setup_domain.sh`

## Service Management

| Action | Command |
|--------|---------|
| Caddy status | `systemctl status caddy` |
| Caddy start | `systemctl start caddy` |
| Caddy stop | `systemctl stop caddy` |
| Caddy restart | `systemctl restart caddy` |
| PHP-FPM status | `systemctl status php8.3-fpm` |
| PHP-FPM restart | `systemctl restart php8.3-fpm` |
| MySQL status (local) | `systemctl status mysql` |
| MySQL start | `systemctl start mysql` |
| MySQL stop | `systemctl stop mysql` |
| MySQL restart | `systemctl restart mysql` |
| fail2ban status | `systemctl status fail2ban` |
| Update WordPress | `wp core update --allow-root --path=/var/www/html` |
| Update plugins | `wp plugin update --all --allow-root --path=/var/www/html` |
| Update phpMyAdmin | Re-download from [phpMyAdmin releases](https://www.phpmyadmin.net/downloads/) into `/usr/share/phpmyadmin` (preserve `config.inc.php`) |
| System packages | `apt update && apt upgrade` |

WordPress CLI: `wp --allow-root --path=/var/www/html [command]`
