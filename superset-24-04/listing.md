# Apache Superset 1-Click Application

Deploy Apache Superset 6.1.0, an open-source data exploration and visualization platform. This image runs Superset in Docker behind Caddy with a short-lived TLS certificate, and keeps chart metadata in PostgreSQL.

## What is Apache Superset?

Apache Superset is a web application for exploring data and building dashboards. Connect it to a read-only source database, write SQL, and publish charts without giving the application write access to your data.

- **Web UI** on HTTPS, with the application bound to `127.0.0.1:8088`
- **Metadata database** on local PostgreSQL 16, or on an attached DigitalOcean Managed Postgres cluster
- **Separate source database** queried by the `superset_reader` role
- **Per-droplet admin password** generated on first boot and shown in the login banner only after setup succeeds

## Key Features

- Official Superset 6.1.0 image, pinned by digest and rebuilt locally with `Flask-Caching` 2.3.1 and `psycopg2-binary` 2.9.9
- Caddy reverse proxy with a Let's Encrypt short-lived certificate
- Helper scripts to start, stop, restart, check status, rebuild the pinned image, and attach a custom domain
- UFW allows SSH, HTTP, and HTTPS, plus PostgreSQL from the Docker bridge only
- fail2ban enabled for SSH

## System Requirements

Superset needs at least 8 GB of RAM. Smaller Droplets will run out of memory while serving dashboards.

| Use case | RAM | CPU | Storage |
|----------|-----|-----|---------|
| Minimum | 8 GB | 2 vCPU | 50 GB |
| Heavier dashboards or more concurrent users | 16 GB | 4 vCPU | 80 GB |

## Included System Components

- **Ubuntu 24.04 LTS**
- **Apache Superset 6.1.0** (Docker image built on this Droplet from the digest-pinned official image)
- **Flask-Caching 2.3.1** and **psycopg2-binary 2.9.9**
- **PostgreSQL 16** for local metadata and the source database
- **Caddy** on ports 80 and 443, proxying to `127.0.0.1:8088`
- **UFW** and **fail2ban**
- **Docker Engine**

## Getting Started

### 1. Create the Droplet

1. Select this 1-Click from the DigitalOcean Marketplace.
2. Choose a Droplet with at least 8 GB of RAM.
3. Add your SSH key.
4. Optional: attach a Managed Postgres cluster. Add this Droplet’s public IP under the cluster’s **Trusted Sources** in the control panel. The Droplet is not added automatically. When that cluster is reachable, Superset stores its own data in the attached database. After the switch, **Source** remains `superset_reader` on managed `superset_source`. Create new tables in `superset_source`. `/opt/prepare-source-db.sh` is only for local PostgreSQL. Local PostgreSQL is stopped after the switch and the cluster remains installed. `systemctl enable --now postgresql` only brings the local server back. It does not move **Source** off the managed database.
5. Create the Droplet.

First boot generates secrets, migrates the metadata database, and creates the admin user. SSH stays closed until that script finishes.

### 2. Sign in

1. SSH to the Droplet: `ssh root@your-droplet-ip`
2. Read the login banner. After setup succeeds it shows:
   - Web UI: `https://your-droplet-ip`
   - Username: `admin`
   - Password: the generated value (also in `/etc/superset/admin.password`)
3. Open the web UI and sign in.

If setup did not succeed, the banner does not show the password. Read `/var/log/superset-firstboot.log` and run `/var/lib/cloud/scripts/per-instance/001_onboot`. When a Managed Postgres cluster was attached but the banner says Superset is still on local PostgreSQL, add the Droplet’s public IP to that cluster’s Trusted Sources, then run `/var/lib/cloud/scripts/per-instance/001_onboot` again.

### 3. Query a source database

The Superset UI includes a database connection named **Source**. It uses the `superset_reader` role, which can connect and `SELECT`. It cannot read the metadata database. First boot does not create sample tables. **Source** stays empty until you add a table.

In the UI, open **Datasets**, create a dataset, choose database **Source** and schema **public**.

#### Managed Postgres

Create new tables in the managed database `superset_source`, as the cluster admin from the login banner. **Source** remains `superset_reader` on that database. Do not run `/opt/prepare-source-db.sh` for a managed cluster. That script is only for local PostgreSQL. Starting local PostgreSQL only brings the local server back.

```bash
psql "host=your-managed-host port=25060 user=doadmin dbname=superset_source sslmode=require"
```

```sql
CREATE TABLE public.revenue (id int, amount numeric);
INSERT INTO public.revenue VALUES (1, 10);
```

Tables created by that admin user in `superset_source` are already readable by `superset_reader`.

#### Local PostgreSQL

Without a managed database, **Source** is the local database `superset_source`. Load tables as the Postgres superuser, then grant the reader role again so new tables are included:

```bash
sudo -u postgres psql -d superset_source
```

```sql
CREATE TABLE public.revenue (id int, amount numeric);
INSERT INTO public.revenue VALUES (1, 10);
```

```bash
/opt/prepare-source-db.sh superset_source
```

To expose another local database to Superset with the same read-only role:

```bash
/opt/prepare-source-db.sh your_database_name
```

The reader password is stored in `/etc/superset/source.env`.

### 4. Optional custom domain

Point a DNS A record at the Droplet, then run:

```bash
/opt/setup-superset-domain.sh
```

Caddy requests a short-lived certificate for that hostname.

## Managing Superset

| Action | Command |
|--------|---------|
| Start | `/opt/start-superset.sh` |
| Stop | `/opt/stop-superset.sh` |
| Restart | `/opt/restart-superset.sh` |
| Status | `/opt/status-superset.sh` |
| Update | `/opt/update-superset.sh` |
| Custom domain | `/opt/setup-superset-domain.sh` |
| Grant source read access (local PostgreSQL only) | `/opt/prepare-source-db.sh [database]` |

`/opt/update-superset.sh` rebuilds the local image from the digest-pinned Superset 6.1.0 base and runs metadata migrations. It does not upgrade Superset to a newer release.

You can also use `systemctl start|stop|restart|status superset` and `journalctl -u superset -f`.

## Ports

| Port | Access |
|------|--------|
| 22 | SSH, rate-limited by UFW |
| 80 | HTTP, redirected to HTTPS by Caddy |
| 443 | HTTPS for the Superset UI |
| 5432 | PostgreSQL, Docker bridge only |

Port 8088 is bound to `127.0.0.1` and is not open on the public interface.

## Credentials

| Item | Location |
|------|----------|
| Admin password (after setup succeeds) | Login banner and `/etc/superset/admin.password` |
| Metadata connection | `/etc/superset/superset.env` |
| Source reader password | `/etc/superset/source.env` |
| Managed Postgres credentials, when attached | `/root/.digitalocean_dbaas_credentials` |
| Metadata location (`local` or `managed`) | `/var/lib/digitalocean/superset-metadata-db` |

## Documentation

https://superset.apache.org/admin-docs/installation/docker-builds/
