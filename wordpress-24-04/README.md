# WordPress 1-Click with Easy Setup

Deploy WordPress instantly with automatic configuration. Get started with HTTP immediately, then add HTTPS when you're ready with a custom domain.

## What's New

This WordPress 1-Click now includes:

- **Automatic Setup Wizard**: Creates your admin account and configures WordPress on first login
- **Setup Pending Page**: Professional loading page displayed until you complete the initial setup
- **Quick Start**: Get WordPress running in ~2 minutes with HTTP
- **Easy HTTPS Migration**: Simple script to add a custom domain with Let's Encrypt SSL later

## What is WordPress?

WordPress is the world's most popular content management system (CMS), powering over 40% of all websites on the internet. It's a free, open-source platform that makes it easy to create beautiful websites, blogs, and applications without needing to know how to code.

Key features include:

- **User-Friendly Interface** - Intuitive admin panel for managing content
- **Themes** - Thousands of free and premium designs
- **Plugins** - Extensible with 60,000+ plugins for any functionality
- **SEO Optimized** - Built-in features for search engine visibility
- **Mobile Responsive** - Works great on all devices
- **Community Support** - Large, active community and extensive documentation

## System Requirements

### Minimum Requirements
- **CPU**: 1 core
- **RAM**: 1 GB
- **Storage**: 25 GB

### Recommended for Production
- **CPU**: 2+ cores
- **RAM**: 2+ GB
- **Storage**: 50+ GB

**Note**: Requirements depend on your traffic and installed plugins. Monitor resource usage and scale up as needed.

## Included Components

This 1-Click installs and configures:

- **Ubuntu 24.04 LTS** - Long-term support base operating system
- **Apache 2.4** - High-performance web server
- **MySQL 8.0** - Relational database
- **PHP 8.3** - Latest PHP with performance optimizations
- **WordPress (Latest)** - Latest stable WordPress release
- **Certbot** - Let's Encrypt SSL certificate management
- **WP-CLI** - WordPress command-line interface
- **WP-Fail2Ban Plugin** - Security plugin with fail2ban integration
- **UFW Firewall** - Pre-configured with secure defaults

## Getting Started

### 1. Deploy the Droplet

- Select this 1-Click App from the DigitalOcean Marketplace
- Choose a Droplet size (minimum 1GB RAM)
- Select your preferred datacenter region
- Add your SSH key for secure access
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
3. **Obtain SSL certificate** - Requests Let's Encrypt certificate for your IP
4. **Configure Apache** - Sets up HTTPS with automatic HTTP→HTTPS redirect
5. **Install security plugins** - Adds and activates WP-Fail2Ban

The entire process takes about 2-3 minutes.

### 4. Access Your WordPress Site

After setup completes, access your site at:

```
https://your-droplet-ip
```

**Admin Login:**
- URL: `https://your-droplet-ip/wp-admin`
- Username: (the one you chose during setup)
- Password: (the one you chose during setup)

## Post-Installation

### Adding a Custom Domain

To use a custom domain instead of the IP address:

1. Point your domain's DNS A record to your Droplet's IP
2. Wait for DNS propagation (usually 5-60 minutes)
3. Run the domain setup script:

```bash
/root/wp_setup_domain.sh
```

This script will:
- Configure Apache for your domain
- Obtain a domain-based SSL certificate
- Update WordPress URLs
- Set up automatic HTTP→HTTPS redirect

### SSL Certificate Renewal

Let's Encrypt certificates are valid for 90 days and automatically renew via certbot.

Test renewal:
```bash
certbot renew --dry-run
```

Check renewal status:
```bash
certbot certificates
```

### Database Credentials

MySQL credentials are stored in:
```bash
cat /root/.digitalocean_password
```

### Security Best Practices

1. **Change default admin username**: Create a new admin user with a unique username and delete the default one
2. **Use strong passwords**: Consider using a password manager
3. **Keep WordPress updated**: Regularly update WordPress core, themes, and plugins
4. **Enable automatic updates**: Consider enabling automatic security updates
5. **Regular backups**: Set up automated backups via DigitalOcean or a backup plugin
6. **Install security plugins**: Additional plugins like Wordfence or Sucuri are recommended
7. **Limit login attempts**: The WP-Fail2Ban plugin is pre-installed and active

### Firewall Configuration

UFW firewall is pre-configured with:
- Port 22 (SSH) - Open
- Port 80 (HTTP) - Open, redirects to HTTPS
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

If SSL certificate acquisition fails, WordPress will still be accessible via HTTP. To retry:

```bash
certbot certonly --standalone -d your-droplet-ip
```

Then reconfigure Apache to use SSL.

### Can't Access WordPress

1. Check Apache status:
   ```bash
   systemctl status apache2
   ```

2. Check error logs:
   ```bash
   tail -f /var/log/apache2/error.log
   ```

3. Verify firewall rules:
   ```bash
   ufw status
   ```

### Database Connection Errors

1. Check MySQL status:
   ```bash
   systemctl status mysql
   ```

2. Verify credentials in `/var/www/html/wp-config.php` match those in `/root/.digitalocean_password`

## File Locations

- **WordPress Root**: `/var/www/html/`
- **Apache Config**: `/etc/apache2/sites-available/`
- **SSL Certificates**: `/etc/letsencrypt/live/your-ip/`
- **Apache Logs**: `/var/log/apache2/`
- **MySQL Data**: `/var/lib/mysql/`
- **PHP Config**: `/etc/php/8.3/`

## Additional Resources

- [WordPress Documentation](https://wordpress.org/support/)
- [DigitalOcean WordPress Tutorials](https://www.digitalocean.com/community/tags/wordpress)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [WP-CLI Documentation](https://wp-cli.org/)

## Support

For issues specific to this 1-Click deployment, please visit the [DigitalOcean Community](https://www.digitalocean.com/community/).

For general WordPress questions, visit the [WordPress Support Forums](https://wordpress.org/support/forums/).

---

**Note**: This deployment uses Let's Encrypt's IP address certificate feature, which became generally available in 2024. These certificates work identically to domain-based certificates and are automatically renewed by certbot.
