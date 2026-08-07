# Supabase 1-Click Application

Deploy self-hosted Supabase on Ubuntu 24.04 with Docker Compose and Nginx. Supabase provides Postgres-backed Auth, REST/Realtime APIs, Storage, and Studio. By default the stack uses its local `db` container; with **Add a Database**, Supabase is configured to use Managed PostgreSQL instead.

## Included System Components

- **Ubuntu 24.04 LTS**
- **Docker Engine** and **Docker Compose plugin**
- **Supabase** (pinned release from the image build, currently `v1.26.05`) — Studio, Kong, Auth, PostgREST, Realtime, Storage, and related services
- **PostgreSQL** via the Supabase `db` container (`supabase/postgres`), or DigitalOcean Managed PostgreSQL when **Add a Database** is selected
- **Nginx** reverse proxy (ports 80/443 → Kong on `localhost:8000`)
- **Certbot** (Snap) for optional custom-domain TLS
- **UFW** — SSH, HTTP, and HTTPS
- **postgresql-client** — used on first boot when a Managed Database is attached

## System Requirements

| Use Case | RAM | CPU | Storage |
|----------|-----|-----|---------|
| Minimum | 2 GB | 1 vCPU | 25 GB |
| Recommended | 4 GB+ | 2 vCPU | 50 GB+ |

## Getting Started

### 1. Deploy the Droplet

1. Select the Supabase 1-Click from the DigitalOcean Marketplace
2. Choose a Droplet size (2 GB RAM minimum recommended)
3. Optionally select **Add a Database** to provision Managed PostgreSQL (see below)
4. Add your SSH key and create the Droplet

### 2. Access Supabase

1. Open `http://your-droplet-ip` in a browser (Nginx → Kong / Studio)
2. SSH in for credentials:

```bash
ssh root@your-droplet-ip
```

Dashboard username and password are shown in the MOTD and stored in `/root/.digitalocean_passwords`.

### 3. Optional domain / HTTPS

Domain and TLS setup is manual (not prompted on every login). When ready, run:

```bash
/var/supabase/supabase-setup.sh
```

## Managing Supabase

Supabase runs as Docker Compose services under `/srv/supabase/supabase/docker`.

| Action | Command |
|--------|---------|
| Start | `cd /srv/supabase/supabase/docker && docker compose up -d` (add `-f docker-compose.dbaas.yml` when Managed DB is in use) |
| Stop | `cd /srv/supabase/supabase/docker && docker compose down` |
| Restart | `cd /srv/supabase/supabase/docker && docker compose restart` |
| Status | `cd /srv/supabase/supabase/docker && docker compose ps` |
| Logs | `cd /srv/supabase/supabase/docker && docker compose logs -f` |
| Update | Pin/bump `application_version` in a new image build, or follow [Supabase self-hosting update docs](https://supabase.com/docs/guides/self-hosting/docker) then `docker compose pull && docker compose up -d` |
| Domain TLS | `/var/supabase/supabase-setup.sh` |

Nginx: `systemctl {start|stop|restart|status} nginx`

### Configuration paths

- Supabase stack: `/srv/supabase/supabase/docker`
- Env / secrets: `/srv/supabase/supabase/docker/.env`
- Passwords: `/root/.digitalocean_passwords`
- Managed DB credentials (when attached): `/root/.digitalocean_dbaas_credentials`
- Domain / TLS helper: `/var/supabase/supabase-setup.sh`
- Setup log: `/var/log/one_click_setup.log`

## Using a DigitalOcean Managed Database (Optional)

When creating the Droplet, select **Add a Database** to provision Managed PostgreSQL for Supabase.

On first boot the Droplet:

1. Waits for the managed cluster (up to a few minutes) and **aborts** if unreachable (e.g. Trusted Sources)
2. Points Supabase at Managed Postgres and removes only the local `db` service (keeps `vector`)
3. Fail-fast bootstraps required roles/schemas (`auth`, `storage`, `_supabase`, etc.) and TLS for analytics/auth/storage
4. Saves connection details to `/root/.digitalocean_passwords` and `DATABASE_URL` in `/etc/environment`

Add the Droplet IP under the database cluster’s **Trusted Sources** in the [control panel](https://cloud.digitalocean.com/databases). If the DB is unreachable on first boot, DBaaS setup aborts instead of starting a broken stack — see `/var/log/one_click_setup.log`, then re-run `/var/lib/digitalocean/setup-dbaas.sh` and `docker compose … up -d`.

Prefer a **2GB+** Managed Database. Small plans (~25 connections/GB) can be exhausted by the Supabase stack; this 1-Click lowers pool sizes on DBaaS first boot. If you see `remaining connection slots are reserved…`, resize the DB or reduce `POOLER_DEFAULT_POOL_SIZE` in `/srv/supabase/supabase/docker/.env` and restart Compose.

## Marketplace release note (Vendor Portal)

Image code alone does **not** show **Add a Database** to customers. Before publishing or updating this 1-Click in the Marketplace:

1. Open the [Vendor Portal](https://cloud.digitalocean.com/vendorportal)
2. Edit the Supabase Droplet 1-Click
3. Enable **PostgreSQL** under managed database / predeploy options
4. Save so create-droplet offers **Add a Database**

Without that checkbox, `/root/.digitalocean_dbaas_credentials` is never injected and DBaaS predeploy will not run.

## Security notes

- Change the Studio dashboard password after first login if needed (value in `/root/.digitalocean_passwords`)
- Prefer restricting SSH (and optionally HTTP/HTTPS) with a Cloud Firewall
- For production, configure a custom domain and TLS via `/var/supabase/supabase-setup.sh`
- Rotate default JWT / API secrets in `/srv/supabase/supabase/docker/.env` for production use

## Additional Resources

- Marketplace: https://marketplace.digitalocean.com/apps/supabase
- Supabase self-hosting: https://supabase.com/docs/guides/self-hosting/docker
- Managed Databases: https://docs.digitalocean.com/products/databases/
