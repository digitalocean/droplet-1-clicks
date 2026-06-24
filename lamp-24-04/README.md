# LAMP 1-Click

Deploy a LAMP stack (Linux, Apache, MySQL, PHP) on Ubuntu 24.04. By default, MySQL runs locally on the Droplet. You can optionally attach a DigitalOcean Managed MySQL database during deployment.

## Getting Started

1. Select the LAMP 1-Click from the DigitalOcean Marketplace
2. Choose a Droplet size and region
3. Optionally select **Add a Database** to provision a Managed MySQL database (see below)
4. Create the Droplet

## What's Included

In addition to the package installation, the 1-Click also:

- Enables the UFW firewall to allow only SSH (port `22`, rate limited), HTTP (port `80`), and HTTPS (port `443`) access
- Sets the MySQL root password and runs `mysql_secure_installation`
- Sets up the `debian-sys-maint` user in MySQL so the system's init scripts for MySQL will work without requiring the MySQL `root` user password

## After You Create the Droplet

- You can view the LAMP instance immediately by visiting the Droplet's IP address in your browser (`http://your-droplet-ip`)
- You can log into the Droplet as `root` using either the password you set when you created the Droplet or with an SSH key, if you added one during creation
- The MySQL root password is in `/root/.digitalocean_password` (when using the local MySQL instance)
- The web root is `/var/www/html`
- You can get information about the PHP installation by logging into the Droplet and running `php -i`

A newly-created LAMP Droplet includes an `index.html` web page in the web root. You can replace it by uploading a custom `index.html` file or remove it.

## Apache Virtual Hosts

Creating an Apache virtual hosts file for each site maintains the default configuration as the fallback, as intended, and makes it easier to manage changes when hosting multiple sites.

To do so, you'll need to create two things for each domain:

- A new directory in `/var/www` for that domain's content
- A new virtual host file in `/etc/apache2/sites-available` for that domain's configuration

For a detailed walkthrough, see [How to Set Up Apache Virtual Hosts](https://www.digitalocean.com/community/tutorials/how-to-set-up-apache-virtual-hosts-on-ubuntu-16-04).

## Setting Up SSL with Certbot

Setting up an SSL certificate enables HTTPS on the web server, which secures the traffic between the server and the clients connecting to it. Certbot is preinstalled on the LAMP 1-Click to make securing the Droplet easier.

To use Certbot, you'll need a registered domain name and two DNS records:

- An A record from a domain (e.g., `example.com`) to the server's IP address
- An A record from a domain prefaced with `www` (e.g., `www.example.com`) to the server's IP address

Additionally, if you are using a virtual hosts file, make sure the `ServerName` directive in the `VirtualHost` block (e.g., `ServerName example.com`) is correctly set to the domain.

Once the DNS records and, optionally, the virtual hosts files are set up, generate the SSL certificate. Substitute your domain in the command:

```bash
certbot --apache -d example.com -d www.example.com
```

HTTPS traffic on port `443` is already allowed through the firewall. After you set up HTTPS, you can optionally deny HTTP traffic on port `80`:

```bash
ufw delete allow 80/tcp
```

For more detail, see [How to Secure Apache with Let's Encrypt](https://www.digitalocean.com/community/tutorials/how-to-secure-apache-with-let-s-encrypt-on-ubuntu-18-04) or [Certbot's official documentation](https://certbot.eff.org/docs/using.html).

## Serving Files

You can serve files from the web server by adding them to the web root (`/var/www/html`) using [SFTP](https://www.digitalocean.com/community/tutorials/how-to-use-sftp-to-securely-transfer-files-with-a-remote-server) or other tools.

## Using a DigitalOcean Managed Database (Optional)

When creating your LAMP Droplet, you can select **Add a Database** to provision a DigitalOcean Managed MySQL database at the same time. A managed database replaces the local MySQL instance to better secure your data and gives you easy backups, connection pools, and metrics.

### What happens when you add a database

When you choose this option during Droplet creation, DigitalOcean:

1. Provisions a Managed MySQL cluster in the same region as your Droplet
2. Passes connection credentials to your Droplet at first boot in `/root/.digitalocean_dbaas_credentials`
3. Exposes a `DATABASE_URL` environment variable with the database connection string

The Droplet waits for the Managed Database to become available, then stops and disables the local MySQL instance. You configure your PHP application to use the managed cluster — LAMP does not auto-wire a specific app.

### Security: Trusted Sources

Your Droplet is not automatically added to the Managed Database's trusted sources. For better security, add your Droplet's public IP address to the database cluster's **Trusted Sources** in the [DigitalOcean control panel](https://cloud.digitalocean.com/databases):

1. Open your database cluster in the control panel
2. Go to **Settings** → **Trusted Sources**
3. Add your Droplet's public IP address

### Modifying database settings later

- **Connection credentials:** `/root/.digitalocean_dbaas_credentials` or the `DATABASE_URL` environment variable
- **Local MySQL (default):** root password in `/root/.digitalocean_password`
- **PHP apps:** Update your application's database configuration to use the managed host, port, username, password, and SSL as required by [Managed MySQL](https://docs.digitalocean.com/products/databases/mysql/)

## Droplet Summary

- UFW firewall allows SSH (port 22, rate limited), HTTP (port 80), and HTTPS (port 443)
- Apache serves content from `/var/www/html`
- Local MySQL root password: `/root/.digitalocean_password`
- Managed MySQL credentials: `/root/.digitalocean_dbaas_credentials` and `DATABASE_URL` (when **Add a Database** was selected)
- Apache config: `/etc/apache2/`
- Certbot is preinstalled for HTTPS setup

## Additional Resources

- [LAMP 1-Click Quickstart](https://do.co/3gY97ha)
