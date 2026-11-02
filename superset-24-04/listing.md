# Apache Superset 1-Click Application

Deploy Apache Superset 6.1.0, an open-source data exploration and visualization platform. This image runs Superset in Docker behind Caddy with a short-lived TLS certificate, and keeps Superset metadata in PostgreSQL.

## What is Apache Superset?

Apache Superset is a web application for exploring data and building dashboards. Connect it to your own databases, write SQL, and publish charts.

- **Web UI** on HTTPS, with the application bound to `127.0.0.1:8088`
- **Metadata database** on local PostgreSQL 16, or on an attached DigitalOcean Managed Postgres cluster
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
- **PostgreSQL 16** for local metadata (optional Managed Postgres)
- **Caddy** on ports 80 and 443, proxying to `127.0.0.1:8088`
- **UFW** and **fail2ban**
- **Docker Engine**

## Getting Started

### 1. Create the Droplet

1. Select this 1-Click from the DigitalOcean Marketplace.
2. Choose a Droplet with at least 8 GB of RAM.
3. Add your SSH key.
4. Optional: attach a Managed Postgres cluster for Superset **metadata**. Add this Droplet’s public IP under the cluster’s **Trusted Sources** in the control panel. The Droplet is not added automatically. When that cluster is reachable, Superset stores its own metadata in the attached database and local PostgreSQL is stopped. `systemctl enable --now postgresql` only brings the local server back; it does not move metadata off Managed Postgres.
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

### 3. Connect analytics databases

Add the databases you want to chart in the Superset UI (**Settings → Database Connections**). Use a separate database or warehouse for analytics data — do not store chart data in the Superset metadata database.

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
| Update | `/opt/update-superset.sh` `[version]` |
| Custom domain | `/opt/setup-superset-domain.sh` |

`/opt/update-superset.sh` upgrades (or rebuilds) Superset from the official `apache/superset` image, runs metadata migrations, and restarts the service.

```bash
/opt/update-superset.sh              # latest stable tag
/opt/update-superset.sh 6.1.0        # exact version
/opt/update-superset.sh --list       # recent Docker Hub tags
/opt/update-superset.sh --rollback   # previous version, if recorded
```

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
| Managed Postgres credentials, when attached | `/root/.digitalocean_dbaas_credentials` |
| Metadata location (`local` or `managed`) | `/var/lib/digitalocean/superset-metadata-db` |

## Documentation

https://superset.apache.org/admin-docs/installation/docker-builds/
