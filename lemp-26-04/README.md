# LEMP 1-Click

Deploy a LEMP stack (Linux, Nginx, MySQL, PHP 8.5) on Ubuntu 26.04 LTS.

## Build / validate

From the repository root:

```sh
export DIGITALOCEAN_API_TOKEN=your_api_token_here

make validate-lemp-26-04
make build-lemp-26-04
```

Or with Packer directly:

```sh
packer validate lemp-26-04/template.json
packer build lemp-26-04/template.json
```

## Getting Started

1. Select the LEMP 1-Click from the DigitalOcean Marketplace
2. Choose a Droplet size and region
3. Create the Droplet

## What's Included

In addition to the package installation, the 1-Click also:

- Enables the UFW firewall to allow only SSH (port `22`, rate limited), HTTP (port `80`), and HTTPS (port `443`) access
- Enables fail2ban with an sshd jail
- Sets the MySQL root password and runs `mysql_secure_installation`
- Sets up the `debian-sys-maint` user in MySQL so the system's init scripts for MySQL will work without requiring the MySQL `root` user password
- Configures Nginx with PHP 8.5 FPM

## After You Create the Droplet

- You can view the LEMP instance immediately by visiting the Droplet's IP address in your browser (`http://your-droplet-ip`)
- You can log into the Droplet as `root` using either the password you set when you created the Droplet or with an SSH key, if you added one during creation
- The MySQL root password is in `/root/.digitalocean_password`
- The web root is `/var/www/html`
- You can get information about the PHP installation by logging into the Droplet and running `php -i`

A newly-created LEMP Droplet includes an `index.html` web page in the web root. You can replace it by uploading a custom `index.html` file or remove it.

## Nginx Server Blocks

Creating an Nginx server block for each site maintains the default configuration as the fallback and makes it easier to manage changes when hosting multiple sites.

For each domain you will typically need:

- A new directory in `/var/www` for that domain's content
- A new server block in `/etc/nginx/sites-available` (symlinked into `/etc/nginx/sites-enabled`)

For a detailed walkthrough, see [How To Set Up Nginx Server Blocks](https://www.digitalocean.com/community/tutorials/how-to-set-up-nginx-server-blocks-on-ubuntu-20-04).

## Setting Up SSL with Certbot

Setting up an SSL certificate enables HTTPS on the web server. Certbot is preinstalled on the LEMP 1-Click.

To use Certbot, you'll need a registered domain name and two DNS records:

- An A record from a domain (e.g., `example.com`) to the server's IP address
- An A record from a domain prefaced with `www` (e.g., `www.example.com`) to the server's IP address

Ensure `server_name` in your Nginx server block matches the domain, then generate the certificate:

```bash
certbot --nginx -d example.com -d www.example.com
```

HTTPS traffic on port `443` is already allowed through the firewall. After you set up HTTPS, you can optionally deny HTTP traffic on port `80`:

```bash
ufw delete allow 80/tcp
```

For more detail, see [How To Secure Nginx with Let's Encrypt](https://www.digitalocean.com/community/tutorials/how-to-secure-nginx-with-let-s-encrypt-on-ubuntu-22-04) or [Certbot's official documentation](https://certbot.eff.org/docs/using.html).

## Serving Files

You can serve files from the web server by adding them to the web root (`/var/www/html`) using [SFTP](https://www.digitalocean.com/community/tutorials/how-to-use-sftp-to-securely-transfer-files-with-a-remote-server) or other tools.

## Droplet Summary

- Ubuntu 26.04 LTS with Nginx, MySQL, and PHP 8.5 FPM
- UFW firewall allows SSH (port 22, rate limited), HTTP (port 80), and HTTPS (port 443)
- Nginx serves content from `/var/www/html`
- Local MySQL root password: `/root/.digitalocean_password`
- Nginx config: `/etc/nginx/`
- PHP-FPM socket: `/run/php/php8.5-fpm.sock`
- Certbot is preinstalled for HTTPS setup

## Additional Resources

- [LEMP 1-Click Quickstart](https://do.co/2GOFe5J)
