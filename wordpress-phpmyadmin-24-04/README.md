# WordPress + phpMyAdmin 1-Click with Easy Setup

Deploy WordPress instantly with automatic configuration and a web-based MySQL manager. HTTPS is enabled automatically on first login, phpMyAdmin is available at `/phpmyadmin`, and you can add a custom domain anytime with `/root/wp_setup_domain.sh`.

## Building this image

From the repository root (requires Packer and `DIGITALOCEAN_API_TOKEN`):

```bash
export DIGITALOCEAN_API_TOKEN=your_token
make validate-wordpress-phpmyadmin-24-04
make build-wordpress-phpmyadmin-24-04
```

Or:

```bash
packer validate wordpress-phpmyadmin-24-04/template.json
packer build wordpress-phpmyadmin-24-04/template.json
```

## What's New

This WordPress + phpMyAdmin 1-Click includes:

- **Automatic Setup Wizard**: Creates your admin account and configures WordPress on first login
- **Setup Pending Page**: Professional loading page displayed until you complete the initial setup
- **Quick Start**: Get WordPress running in ~2 minutes with automatic HTTPS
- **phpMyAdmin**: Manage MySQL through a browser UI at `https://your-droplet-ip/phpmyadmin`
- **Easy Custom Domain Setup**: Simple script to switch from IP-based access to a custom domain with Let's Encrypt SSL

## What is WordPress?

WordPress is the world's most popular content management system (CMS), powering over 40% of all websites on the internet. It's a free, open-source platform that makes it easy to create beautiful websites, blogs, and applications without needing to know how to code.

Key features include:

- **User-Friendly Interface** - Intuitive admin panel for managing content
- **Themes** - Thousands of free and premium designs
- **Plugins** - Extensible with 60,000+ plugins for any functionality
- **SEO Optimized** - Built-in features for search engine visibility
- **Mobile Responsive** - Works great on all devices
- **Community Support** - Large, active community and extensive documentation

## What is phpMyAdmin?

phpMyAdmin is a free web application for administering MySQL and MariaDB. It lets you browse databases, run SQL, import/export data, and manage users from a browser — without using the MySQL command line.

## System Requirements

### Minimum Requirements
- **CPU**: 1 core
- **RAM**: 2 GB
- **Storage**: 25 GB

### Recommended for Production
- **CPU**: 2+ cores
- **RAM**: 4+ GB
- **Storage**: 50+ GB

**Note**: Requirements depend on your traffic and installed plugins. Monitor resource usage and scale up as needed.

## Included Components

This 1-Click installs and configures:

- **Ubuntu 24.04 LTS** - Long-term support base operating system
- **Caddy** - Web server and reverse proxy with automatic HTTPS (Let's Encrypt)
- **PHP 8.3 FPM** - PHP FastCGI Process Manager for WordPress and phpMyAdmin
- **MySQL 8.4** - Relational database (local; optional Managed Database)
- **WordPress (Latest)** - Latest stable WordPress release (version recorded at image build)
- **phpMyAdmin (Latest)** - Latest stable release from phpmyadmin.net at `/phpmyadmin`
- **WP-CLI** - WordPress command-line interface
- **WP-Fail2Ban Plugin** - Installed and activated during first-login setup
- **UFW Firewall** - Pre-configured with secure defaults

## Getting Started

### 1. Deploy the Droplet

- Select this 1-Click App from the DigitalOcean Marketplace
- Choose a Droplet size (minimum 2 GB RAM)
- Select your preferred datacenter region
- Add your SSH key for secure access
- Optionally select **Add a Database** to provision a DigitalOcean Managed MySQL database alongside your Droplet (see [Using a DigitalOcean Managed Database](#using-a-digitalocean-managed-database-optional))
- Create the Droplet

### 2. Initial Access

Before running the setup script, you can visit your Droplet's IP address in a browser to see the setup pending page:

```
http://your-droplet-ip
```

This page will display instructions and automatically refresh until setup is complete.

### 3. Run the Setup Script

SSH into your Droplet:

```bash
ssh root@your-droplet-ip
```

The setup script will launch automatically on first login. It will:

1. **Detect your server's IP address** - Automatically determines your public IP
2. **Create admin account** - You'll be prompted for:
   - Email address
   - Admin username
   - Admin password
   - Site title
3. **Obtain SSL certificate** - Caddy requests a Let's Encrypt certificate for your IP (short-lived profile)
4. **Configure Caddy** - Serves WordPress over HTTPS with automatic HTTP→HTTPS redirect, and phpMyAdmin at `/phpmyadmin`
5. **Install security plugins** - Adds and activates WP-Fail2Ban

The entire process takes about 2-3 minutes.

If you added a Managed Database during deployment, the setup script also configures WordPress **and phpMyAdmin** to use it instead of the local MySQL instance. The script waits for the database cluster to become available before continuing, which may add a few minutes to setup.

### 4. Access Your WordPress Site

After setup completes, access your site at:

```
https://your-droplet-ip
```

**Admin Login:**
- URL: `https://your-droplet-ip/wp-admin`
- Username: (the one you chose during setup)
- Password: (the one you chose during setup)

### 5. Access phpMyAdmin

After setup completes, open:

```
https://your-droplet-ip/phpmyadmin
```

**Local MySQL** (default, when no Managed Database is added):

- **Username**: `admin`
- **Password**: value of `admin_mysql_pass` in `/root/.digitalocean_password`

```bash
grep admin_mysql_pass /root/.digitalocean_password
```

**DigitalOcean Managed Database** (when **Add a Database** was selected):

- **Username**: the Managed Database user (also stored as `phpmyadmin_user` in `/root/.digitalocean_password`)
- **Password**: value of `admin_mysql_pass` in `/root/.digitalocean_password` (same as WordPress `DB_PASSWORD`)
- phpMyAdmin is preconfigured for SSL to your Managed Database host and port

> **Security note**: phpMyAdmin is a powerful database UI. Use strong passwords, keep the Droplet firewalled, and consider restricting access (for example via Cloud Firewall source IP rules) in production.

## Post-Installation

### Using a DigitalOcean Managed Database (Optional)

When creating your Droplet, you can select **Add a Database** to provision a DigitalOcean Managed MySQL database at the same time. A managed database replaces the local MySQL instance to better secure your data and gives you easy backups, connection pools, and metrics. The setup script handles configuration automatically — no manual DBaaS wiring required.

#### What happens when you add a database

When you choose this option during Droplet creation, DigitalOcean:

1. Provisions a Managed MySQL cluster in the same region as your Droplet
2. Passes connection credentials to your Droplet at first boot (stored temporarily in `/root/.digitalocean_dbaas_credentials`)

When you complete the first-login setup script, the Droplet automatically:

1. Configures WordPress to connect to the Managed Database instead of the local MySQL instance
2. Updates `/var/www/html/wp-config.php` with the database host, port, name, username, and password
3. Enables SSL for the MySQL connection
4. Configures phpMyAdmin to use the same Managed Database host, port, and SSL settings
5. Waits for the database cluster to become available (this may take a few minutes during first setup)
6. Stops and disables the local MySQL instance on the Droplet
7. Updates `/root/.digitalocean_password` with phpMyAdmin login details for the Managed Database

After setup completes, your database connection details are stored in `/var/www/html/wp-config.php` and phpMyAdmin credentials are in `/root/.digitalocean_password`. The temporary `/root/.digitalocean_dbaas_credentials` file is removed.

#### Security: Trusted Sources

Your Droplet is not automatically added to the Managed Database's trusted sources. For better security, add your Droplet's public IP address to the database cluster's **Trusted Sources** in the [DigitalOcean control panel](https://cloud.digitalocean.com/databases):

1. Open your database cluster in the control panel
2. Go to **Settings** → **Trusted Sources**
3. Add your Droplet's public IP address

Without Trusted Sources configured, both WordPress and phpMyAdmin may fail to connect to the Managed Database.

#### Modifying database settings later

- **WordPress connection details**: View or update credentials in `/var/www/html/wp-config.php` (`DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`)
- **phpMyAdmin connection details**: Update `/usr/share/phpmyadmin/config.inc.php` (`$cfg['Servers'][1]['host']`, `port`, and SSL options) to match
- **Password rotation**: If you change the database password in the control panel, update both `wp-config.php` and `/root/.digitalocean_password` (`admin_mysql_pass`)
- **Switching databases**: To point WordPress and phpMyAdmin at a different Managed Database, update `wp-config.php` and phpMyAdmin's `config.inc.php`, and ensure the new cluster allows connections from your Droplet

### Adding a Custom Domain

To use a custom domain instead of the IP address:

1. Point your domain's DNS A record to your Droplet's IP
2. Wait for DNS propagation (usually 5-60 minutes)
3. Run the domain setup script:

```bash
/root/wp_setup_domain.sh
```

This script will:

- Configure Caddy for your domain (including `/phpmyadmin`)
- Obtain a domain-based SSL certificate
- Update WordPress URLs
- Set up automatic HTTP→HTTPS redirect

After domain setup, phpMyAdmin is available at `https://your-domain/phpmyadmin`.

### SSL Certificate Renewal

Caddy obtains and renews Let's Encrypt certificates automatically. You do not need to run Certbot manually.

To confirm Caddy is healthy:

```bash
systemctl status caddy
journalctl -u caddy -n 50 --no-pager
```

### Database Credentials

**Local MySQL** (default, when no Managed Database is added):

```bash
cat /root/.digitalocean_password
```

Keys include `root_mysql_pass`, `wordpress_mysql_pass`, and `admin_mysql_pass` (phpMyAdmin login).

**DigitalOcean Managed Database** (when **Add a Database** was selected during deployment):

After setup completes, connection details are in `/var/www/html/wp-config.php`. phpMyAdmin login details are in `/root/.digitalocean_password`. The local MySQL instance is stopped and disabled.

### Security Best Practices

1. **Change default admin username**: Create a new admin user with a unique username and delete the default one
2. **Use strong passwords**: Consider using a password manager
3. **Keep WordPress updated**: Regularly update WordPress core, themes, and plugins
4. **Enable automatic updates**: Consider enabling automatic security updates
5. **Regular backups**: Set up automated backups via DigitalOcean or a backup plugin
6. **Install security plugins**: Additional plugins like Wordfence or Sucuri are recommended
7. **Limit login attempts**: The WP-Fail2Ban plugin is installed and activated during first-login setup
8. **Protect phpMyAdmin**: Prefer Cloud Firewall rules that allow `/phpmyadmin` (port 443) only from trusted IPs

### Firewall Configuration

UFW firewall is pre-configured with:

- Port 22 (SSH) - Open
- Port 80 (HTTP) - Open, redirects to HTTPS after setup
- Port 443 (HTTPS) - Open

### WP-CLI Usage

WP-CLI is installed for command-line WordPress management:

```bash
# Update WordPress core
wp core update --allow-root

# List installed plugins
wp plugin list --allow-root

# Install a plugin
wp plugin install <plugin-name> --activate --allow-root

# Create a backup
wp db export --allow-root
```

## Troubleshooting

### Setup Script Didn't Run

If the setup script didn't automatically run on first login:

```bash
chmod +x /root/wp_setup.sh
/root/wp_setup.sh
```

### SSL Certificate Failed

If HTTPS fails after setup, check Caddy's logs and configuration:

```bash
systemctl status caddy
journalctl -u caddy -b --no-pager
```

Ensure ports 80 and 443 are open (`ufw status`). For a custom domain, run `/root/wp_setup_domain.sh` after DNS points to this Droplet.

### Can't Access WordPress

1. Check Caddy status:

   ```bash
   systemctl status caddy
   ```

2. Check Caddy logs:

   ```bash
   journalctl -u caddy -f
   ```

3. Verify PHP-FPM:

   ```bash
   systemctl status php8.3-fpm
   ```

4. Verify firewall rules:

   ```bash
   ufw status
   ```

### Can't Access phpMyAdmin

1. Confirm setup has finished and HTTPS works for the WordPress site
2. Open `https://your-droplet-ip/phpmyadmin/` (trailing slash)
3. Verify credentials in `/root/.digitalocean_password`
4. If using a Managed Database, confirm Trusted Sources includes this Droplet and that `/usr/share/phpmyadmin/config.inc.php` points at the managed host

### Database Connection Errors

**If using local MySQL:**

1. Check MySQL status:

   ```bash
   systemctl status mysql
   ```

2. Verify credentials in `/var/www/html/wp-config.php` match those in `/root/.digitalocean_password`

**If using a DigitalOcean Managed Database:**

1. Confirm your Droplet's IP is listed under the database cluster's **Trusted Sources** in the [control panel](https://cloud.digitalocean.com/databases)
2. Verify connection details in `/var/www/html/wp-config.php` match your Managed Database settings
3. Test connectivity from the Droplet:

   ```bash
   mysqladmin ping -h "$(grep DB_HOST /var/www/html/wp-config.php | cut -d"'" -f4 | cut -d: -f1)" --silent
   ```

## File Locations

- **WordPress Root**: `/var/www/html/`
- **phpMyAdmin**: `/usr/share/phpmyadmin/`
- **phpMyAdmin config**: `/usr/share/phpmyadmin/config.inc.php`
- **Caddy config**: `/etc/caddy/Caddyfile`
- **SSL certificates**: `/var/lib/caddy/.local/share/caddy/certificates/`
- **MySQL Data**: `/var/lib/mysql/` (local MySQL only)
- **PHP (FPM + CLI)**: `/etc/php/8.3/`

## Additional Resources

- [WordPress Documentation](https://wordpress.org/support/)
- [phpMyAdmin Documentation](https://docs.phpmyadmin.net/)
- [DigitalOcean WordPress Tutorials](https://www.digitalocean.com/community/tags/wordpress)
- [Caddy Documentation](https://caddyserver.com/docs/)
- [WP-CLI Documentation](https://wp-cli.org/)

## Support

For issues specific to this 1-Click deployment, please visit the [DigitalOcean Community](https://www.digitalocean.com/community/).

For general WordPress questions, visit the [WordPress Support Forums](https://wordpress.org/support/forums/).

---

**Note**: The first-login setup uses Let's Encrypt with a short-lived certificate profile for access by IP. After you add a custom domain with `/root/wp_setup_domain.sh`, Caddy continues to manage issuance and renewal automatically.
