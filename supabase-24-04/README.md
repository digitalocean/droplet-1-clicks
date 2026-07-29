# Supabase 1-Click

Deploy self-hosted Supabase on Ubuntu 24.04 with Docker Compose and Nginx. Postgres for the Supabase stack runs as the local `db` container. You can optionally attach a DigitalOcean Managed PostgreSQL database during deployment for your own application data.

## Getting Started

1. Select the Supabase 1-Click from the DigitalOcean Marketplace
2. Choose a Droplet size and region (2GB RAM minimum recommended)
3. Optionally select **Add a Database** to provision a Managed PostgreSQL database (see below)
4. Create the Droplet and SSH in as `root`

On first boot, the Supabase Docker stack starts automatically and Nginx proxies to Kong.

**Supabase Studio / API:**

- **URL:** `http://your-droplet-ip`
- **Dashboard username/password:** stored in `/root/.digitalocean_passwords`

## Using a DigitalOcean Managed Database (Optional)

When creating your Supabase Droplet, you can select **Add a Database** to provision a DigitalOcean Managed PostgreSQL database at the same time. Managed databases give you easy backups, connection pools, and metrics.

### Marketplace Vendor Portal (required for predeploy)

**Add a Database** only appears if PostgreSQL is enabled for this 1-Click in the Vendor Portal. Image scripts cannot turn that UI on by themselves.

Before customers can use DBaaS with this app:

1. Open the [Vendor Portal](https://cloud.digitalocean.com/vendorportal)
2. Edit the Supabase Droplet 1-Click listing
3. Enable the **PostgreSQL** managed database (predeploy) option
4. Save and publish/update the listing

Until that is done, droplets will not receive `/root/.digitalocean_dbaas_credentials` and the DBaaS first-boot path will not run.

### What happens when you add a database

When you choose this option during Droplet creation, DigitalOcean:

1. Provisions a Managed PostgreSQL cluster in the same region as your Droplet
2. Passes connection credentials to your Droplet at first boot in `/root/.digitalocean_dbaas_credentials`

During first-boot setup, the Droplet automatically:

1. Waits for the PostgreSQL cluster to become available (up to a few minutes)
2. Saves connection details and a `DATABASE_URL` in `/root/.digitalocean_passwords` and `/etc/environment`
3. Starts the Supabase stack with its **local** `db` container (unchanged)

The Supabase services are not automatically pointed at Managed Postgres. Supabase requires its specialized Postgres image; use the managed database for your own apps or tooling alongside Supabase.

### Security: Trusted Sources

Your Droplet is not automatically added to the Managed Database's trusted sources. For better security, add your Droplet's public IP address to the database cluster's **Trusted Sources** in the [DigitalOcean control panel](https://cloud.digitalocean.com/databases):

1. Open your database cluster in the control panel
2. Go to **Settings** → **Trusted Sources**
3. Add your Droplet's public IP address

### Modifying database settings later

- **Managed DB credentials:** `/root/.digitalocean_dbaas_credentials` and `/root/.digitalocean_passwords` (`DATABASE_URL`, `DB_*`)
- **Supabase stack env:** `/srv/supabase/supabase/docker/.env`
- **Password rotation:** If you change managed DB credentials in the control panel, update `/root/.digitalocean_passwords` and `/etc/environment` to match

## File Locations

- **Supabase stack:** `/srv/supabase/supabase/docker`
- **Passwords and keys:** `/root/.digitalocean_passwords`
- **Managed DB credentials (when used):** `/root/.digitalocean_dbaas_credentials`
- **SSL / domain setup:** `/var/supabase/supabase-setup.sh`
- **Setup log:** `/var/log/one_click_setup.log`

## Additional Resources

- Marketplace listing: https://marketplace.digitalocean.com/apps/supabase
- Supabase self-hosting docs: https://supabase.com/docs/guides/self-hosting/docker
