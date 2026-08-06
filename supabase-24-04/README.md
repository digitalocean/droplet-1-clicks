# Supabase 1-Click

Deploy self-hosted Supabase on Ubuntu 24.04 with Docker Compose and Nginx. By default Postgres runs as the local `db` container. When you select **Add a Database** at create time, Supabase is configured to use DigitalOcean Managed PostgreSQL instead.

## Getting Started

1. Select the Supabase 1-Click from the DigitalOcean Marketplace
2. Choose a Droplet size and region (2GB RAM minimum recommended)
3. Optionally select **Add a Database** to provision Managed PostgreSQL (see below)
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
2. Points Supabase `.env` / Compose at Managed Postgres (and disables the local `db` container)
3. Bootstraps Supabase roles and schemas on the managed database (`auth`, `storage`, `_supabase`, etc.)
4. Enables TLS for analytics/auth/storage/realtime (`docker-compose.dbaas.yml`; Logflare SSL runtime is patched at image build and verified on first boot)
5. Saves connection details in `/root/.digitalocean_passwords` and `DATABASE_URL` in `/etc/environment`

### Security: Trusted Sources

Your Droplet is not automatically added to the Managed Database's trusted sources. For better security, add your Droplet's public IP address to the database cluster's **Trusted Sources** in the [DigitalOcean control panel](https://cloud.digitalocean.com/databases):

1. Open your database cluster in the control panel
2. Go to **Settings** → **Trusted Sources**
3. Add your Droplet's public IP address

### Connection limits

DigitalOcean Managed Postgres allows about **25 connections per 1GB RAM** (minus 3 reserved for maintenance). The Supabase stack opens many pools (Supavisor, PostgREST, Auth, Storage, Realtime, Logflare). On first boot with DBaaS, this 1-Click lowers pool sizes so a small Marketplace DB can start. Prefer a **2GB+** Managed Database for production; if you see `remaining connection slots are reserved for roles with the SUPERUSER attribute`, resize the DB or lower `POOLER_DEFAULT_POOL_SIZE` in `/srv/supabase/supabase/docker/.env` and restart Compose.

### Modifying database settings later

- **Managed DB credentials:** `/root/.digitalocean_dbaas_credentials` and `/root/.digitalocean_passwords` (`POSTGRES_*`, `DATABASE_URL`)
- **Supabase stack env:** `/srv/supabase/supabase/docker/.env`
- **Password rotation:** If you change managed DB credentials in the control panel, update `/root/.digitalocean_passwords`, `/etc/environment`, and `/srv/supabase/supabase/docker/.env` to match, then restart the stack

## File Locations

- **Supabase stack:** `/srv/supabase/supabase/docker`
- **Passwords and keys:** `/root/.digitalocean_passwords`
- **Managed DB credentials (when used):** `/root/.digitalocean_dbaas_credentials`
- **SSL / domain setup:** `/var/supabase/supabase-setup.sh`
- **Setup log:** `/var/log/one_click_setup.log`

## Additional Resources

- Marketplace listing: https://marketplace.digitalocean.com/apps/supabase
- Supabase self-hosting docs: https://supabase.com/docs/guides/self-hosting/docker
