# Apache Superset 1-Click Droplet Builder

Packer builder for an Ubuntu 24.04 DigitalOcean Marketplace image that runs Apache Superset 6.1.0.

## Overview

Superset runs from a local Docker image. The Dockerfile starts from the official `apache/superset` 6.1.0 linux/amd64 image, pinned by digest, and installs `Flask-Caching==2.3.1` and `psycopg2-binary==2.9.9`. The container listens on `127.0.0.1:8088`. Caddy publishes HTTPS with a Let's Encrypt short-lived certificate.

Metadata starts on local PostgreSQL 16. When `/root/.digitalocean_dbaas_credentials` contains `db_protocol="postgresql"`, first boot waits up to 10 minutes and, after setup succeeds, points `SUPERSET__SQLALCHEMY_DATABASE_URI` at that cluster as the admin user. **Source** uses `superset_reader` on database `superset_source` on the same cluster. Without a managed database, **Source** is the local `superset_source` database through `superset_reader`.

The admin password is generated on first boot. The MOTD prints it only after `/var/lib/superset/setup-complete` exists.

## Directory Structure

```
superset-24-04/
├── template.json
├── README.md
├── listing.md
├── scripts/
│   └── 010-superset.sh
└── files/
    ├── etc/
    │   ├── caddy/Caddyfile.tmp
    │   ├── docker/daemon.json
    │   ├── superset/superset_config.py
    │   ├── systemd/system/superset.service
    │   └── update-motd.d/99-one-click
    ├── opt/
    │   ├── bootstrap-superset.sh
    │   ├── prepare-source-db.sh
    │   ├── start-superset.sh
    │   ├── stop-superset.sh
    │   ├── restart-superset.sh
    │   ├── status-superset.sh
    │   ├── update-superset.sh
    │   ├── setup-superset-domain.sh
    │   └── superset/
    │       ├── Dockerfile
    │       ├── lib.sh
    │       └── postgres/listen.conf
    └── var/lib/
        ├── cloud/scripts/per-instance/001_onboot
        └── digitalocean/
            ├── setup-dbaas.sh
            └── finish-setup.sh
```

## Pins

| Component | Pin |
|-----------|-----|
| Application version | `6.1.0` in `template.json` |
| Base image tag digest (multi-arch) | `sha256:16b50bbef6648912a79e3293d418fefa743ce555d36c5af6b85d859119ed7f88` |
| Base image linux/amd64 digest (`FROM`) | `sha256:8b0426ef41beba328549e45371ea181f1c6761a871f167565cdab33c76057fe1` |
| Flask-Caching | `2.3.1` |
| psycopg2-binary | `2.9.9` |
| Builder size | `s-4vcpu-8gb` (product minimum is 8 GB RAM) |

## Build Requirements

1. Packer: https://www.packer.io/downloads
2. A DigitalOcean API token with write access

```bash
export DIGITALOCEAN_API_TOKEN="your_api_token_here"
```

From the repository root, after the DigitalOcean Packer plugin is installed (see the root README):

```bash
make validate-superset-24-04
make build-superset-24-04
```

## What Gets Installed

- Docker Engine and the locally built `superset-local:6.1.0` image
- PostgreSQL 16, listening on the Docker bridge gateway, with UFW allowing port 5432 only on `docker0`
- Caddy, enabled on first boot
- fail2ban
- UFW for SSH, HTTP, and HTTPS (`common/scripts/014-ufw-http.sh`)

No admin password, metadata password, or secret key is created during the Packer build.

## First Boot

`/var/lib/cloud/scripts/per-instance/001_onboot` prepares the Droplet, then removes the SSH `ForceCommand` lock even if setup fails.

1. `/opt/bootstrap-superset.sh` starts local PostgreSQL 16, creates database `superset`, points Caddy at the droplet public IP, and runs `/opt/prepare-source-db.sh`. It does not load sample tables.
2. Exports `PASSWORD`, then runs `bash /var/lib/digitalocean/setup-dbaas.sh` (it is not sourced). On the managed cluster it creates `superset_reader` on database `superset_source`. `/opt/prepare-source-db.sh` remains local PostgreSQL only
3. That script reads `/root/.digitalocean_dbaas_credentials` only when `db_protocol` is `postgresql`, waits at most 10 minutes for `pg_isready`, and on timeout, incomplete credentials, or a non-numeric port writes `local` to `/var/lib/digitalocean/superset-metadata-db` and exits 0. A missing `/etc/superset/superset.env` still exits non-zero. Add the Droplet’s public IP to the Managed Postgres cluster’s Trusted Sources first. The Droplet is not added automatically. If the banner still says Superset is on local PostgreSQL, re-run `/var/lib/cloud/scripts/per-instance/001_onboot`
4. When the local `superset` database already has Superset tables, it dumps that database and restores it into the managed metadata database before changing the URI. If that copy fails, the state file stays `local` and local PostgreSQL is not stopped. On success it locks down `CONNECT` on the metadata database when no other login role exists, writes the admin URI only to `SUPERSET__SQLALCHEMY_DATABASE_URI`, writes the `superset_reader` URI to `SUPERSET__SQLALCHEMY_EXAMPLES_URI`, deletes `/etc/superset/dbaas.vars`, and runs `finish-setup.sh`. Both URIs use `sslmode=require`. It then stops and disables local PostgreSQL, leaving the cluster installed, and writes `managed`. A failed switch restores the local URI and writes `local`. If setup already completed on local Postgres and managed credentials are present, a later run of this script calls `setup-dbaas.sh` only. It does not run `bootstrap-superset.sh` again.
5. If the state file is not `managed`, `finish-setup.sh` runs against local PostgreSQL
6. Starts Superset and creates `/var/lib/superset/setup-complete` only after `http://127.0.0.1:8088/health` succeeds

A non-zero exit from `setup-dbaas.sh` does not start Superset. Re-run `/var/lib/cloud/scripts/per-instance/001_onboot` if the first attempt fails. Existing secret files are reused. The MOTD shows managed host, database, user, and password only when the state file is `managed`. If credentials exist and the state file is not `managed`, it says Superset is still on local PostgreSQL.

## Smoke Test

- `make validate-superset-24-04`
- Packer build completes without an interactive prompt
- After first boot, `https://<droplet-ip>` reaches Superset
- MOTD shows the admin password only when `/var/lib/superset/setup-complete` exists
- `systemctl status superset` and `systemctl status caddy` are active
- `ufw status` shows 22, 80, and 443, and PostgreSQL only on `docker0`
- A second Droplet from the same snapshot gets a different admin password
