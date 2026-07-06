# Keycloak 1-Click

Deploy Keycloak on Ubuntu 24.04 in a Docker container with PostgreSQL. By default, PostgreSQL runs locally. You can optionally attach a DigitalOcean Managed PostgreSQL database during deployment.

## Getting Started

1. Select the Keycloak 1-Click from the DigitalOcean Marketplace
2. Choose a Droplet size and region (minimum **2 GB RAM** and **2 vCPUs** recommended)
3. Optionally select **Add a Database** to provision a Managed PostgreSQL database (see below)
4. Create the Droplet

On first boot, Keycloak is built and started automatically in Docker. This can take a few minutes.

### Access Keycloak

After your Droplet is created, open your Droplet's IP address in a browser.

Your browser may show a **Privacy Error** — this is expected because Keycloak uses self-signed certificates. Click **Advanced**, then **Proceed** to continue.

![Keycloak Privacy Error](https://do-not-delete-droplet-assets.nyc3.digitaloceanspaces.com/Screenshot%202024-07-03%20at%2018.21.13.png)

After this, you will be greeted by the Keycloak login page:

![Keycloak Login Page](https://do-not-delete-droplet-assets.nyc3.digitaloceanspaces.com/Screenshot%202024-07-03%20at%2018.28.22.png)

If you see **Site can't be reached** or an **Nginx 502 Bad Gateway** error, wait 2–3 minutes for the Docker build and Keycloak startup to finish, then reload the page. If it still does not load, try a larger Droplet size.

Nginx acts as a reverse proxy on port 80 (`http://your-droplet-ip`) and forwards requests to Keycloak.

### Retrieve Login Credentials

SSH into your Droplet:

```bash
ssh root@your-droplet-ip
```

View the generated passwords:

```bash
cat /root/.digitalocean_passwords
```

This file contains three passwords:

- **`KEYCLOAK_ADMIN_PASSWORD`** — log in to the Keycloak admin console as `admin`
- **`KEYCLOAK_DATABASE_PASSWORD`** — password for the PostgreSQL database used by Keycloak
- **`KEYSTORE_PASSWORD`** — password for the Keycloak HTTPS certificate keystore

**Keycloak admin console:**

- **URL:** `http://your-droplet-ip` (via Nginx) or `https://your-droplet-ip:8443` (Keycloak directly)
- **Username:** `admin`
- **Password:** `KEYCLOAK_ADMIN_PASSWORD` from `/root/.digitalocean_passwords`

## Configuring Nginx

After creating your Keycloak Droplet, configure a separate Nginx server block for each domain you plan to host. This keeps the default configuration as a fallback and makes it easier to manage multiple sites.

For each domain, create a directory under `/var/www` for its content and a server block file in `/etc/nginx/sites-available`. See [How to Set Up Nginx Server Blocks](https://www.digitalocean.com/community/tutorials/how-to-set-up-nginx-server-blocks-virtual-hosts-on-ubuntu-16-04).

## Adding a Domain Name

A domain name lets others access Keycloak with a recognizable hostname and enables HTTPS via Let's Encrypt.

Certbot is preinstalled on the Droplet. Before running it:

1. Point your domain's DNS A record to your Droplet's IP

If your DNS is managed by DigitalOcean, it should look like this:

![Keycloak Domain Example](https://do-not-delete-droplet-assets.nyc3.digitaloceanspaces.com/Screenshot%202024-07-03%20at%2018.38.33.png)

2. Configure Nginx to host the new domain (see above)

Then obtain a certificate:

```bash
certbot --nginx -d your-domain.com
```

Answer Certbot's prompts to finish HTTPS setup. Use your domain in the browser to access Keycloak.

If your DNS is managed by DigitalOcean, see [this guide](https://docs.digitalocean.com/tutorials/dns-registrars/) for connecting your registrar.

## Using a DigitalOcean Managed Database (Optional)

When creating your Keycloak Droplet, you can select **Add a Database** to provision a DigitalOcean Managed PostgreSQL database at the same time. A managed database replaces the local PostgreSQL instance to better secure your data and gives you easy backups, connection pools, and metrics. No manual DBaaS setup is required.

### What happens when you add a database

When you choose this option during Droplet creation, DigitalOcean:

1. Provisions a Managed PostgreSQL cluster in the same region as your Droplet
2. Passes connection credentials to your Droplet at first boot in `/root/.digitalocean_dbaas_credentials`

During first-boot setup, the Droplet automatically:

1. Waits for the PostgreSQL cluster to become available (this may take a few minutes)
2. Creates a dedicated `keycloak` database user and `keycloak` database on the managed cluster
3. Starts Keycloak configured to connect to the Managed Database over SSL
4. Stops and disables the local PostgreSQL instance

The Keycloak database password is stored in `/root/.digitalocean_passwords` (`KEYCLOAK_DATABASE_PASSWORD`).

### Security: Trusted Sources

Your Droplet is not automatically added to the Managed Database's trusted sources. For better security, add your Droplet's public IP address to the database cluster's **Trusted Sources** in the [DigitalOcean control panel](https://cloud.digitalocean.com/databases):

1. Open your database cluster in the control panel
2. Go to **Settings** → **Trusted Sources**
3. Add your Droplet's public IP address

### Modifying database settings later

- **Keycloak DB password:** `/root/.digitalocean_passwords` (`KEYCLOAK_DATABASE_PASSWORD`)
- **Keycloak container:** Recreate the container with updated `KC_DB_*` environment variables if you change database connection settings
- **Container logs:** `docker logs keycloak`
- **Password rotation:** If you change credentials in the control panel, update Keycloak's database configuration and restart the container

## Droplet Summary

- UFW firewall allows SSH (port 22, rate limited), Nginx (ports 80 and 443), and Keycloak (ports 8443 and 9000)
- Keycloak runs in a Docker container (`docker logs keycloak` to view logs)
- Nginx redirects requests to Keycloak, acting as a reverse proxy for the application server
- Passwords are shown in the message of the day (MOTD) on SSH login and saved in `/root/.digitalocean_passwords`
- The Keycloak Dockerfile is at `/var/digitalocean/Dockerfile`

## Additional Resources

- [Keycloak Documentation](https://www.keycloak.org/documentation)
