# Apache Superset 1-Click Droplet Builder

Packer builder for a DigitalOcean Marketplace 1-Click image running [Apache Superset](https://superset.apache.org/) on Ubuntu 24.04 LTS.

## Overview

This image installs Apache Superset in a Python virtualenv, PostgreSQL for metadata, and **Caddy** as a reverse proxy with Let's Encrypt **shortlived** TLS (works with the Droplet IP out of the box). Optional Managed Database (DBaaS) and custom-domain setup are supported at first boot / via helpers.

## Directory Structure

```
apache-superset-24-04/
├── template.json
├── README.md
├── listing.md
├── scripts/
│   └── 011-superset.sh
└── files/
    ├── etc/
    │   ├── caddy/Caddyfile.tmp
    │   ├── caddy/Caddyfile.domain.tmpl
    │   ├── systemd/system/superset.service
    │   └── update-motd.d/99-one-click
    ├── opt/
    │   ├── start-superset.sh
    │   ├── stop-superset.sh
    │   ├── restart-superset.sh
    │   ├── status-superset.sh
    │   ├── update-superset.sh
    │   └── setup-superset-domain.sh
    └── var/
        ├── lib/cloud/scripts/per-instance/001_onboot
        ├── lib/digitalocean/{finish-setup.sh,setup-dbaas.sh}
        └── superset/{install-superset.sh,superset.sh,superset_config.py}
```

## Build Requirements

1. [Packer](https://www.packer.io/downloads)
2. DigitalOcean API token with write access

```bash
export DIGITALOCEAN_API_TOKEN="your_api_token_here"
```

From the repo root (after Packer DigitalOcean plugin init; see root README):

```bash
make validate-apache-superset-24-04
make build-apache-superset-24-04
```

## What Gets Installed

| Component | Details |
|-----------|---------|
| Apache Superset | Version from `application_version` in `template.json` |
| PostgreSQL | Local metadata DB (optional switch to DO Managed Postgres) |
| Caddy | HTTPS reverse proxy to `127.0.0.1:8088` with shortlived TLS |
| UFW | SSH + HTTP + HTTPS |
| User | Dedicated `superset` system user |

Builder size defaults to **s-2vcpu-8gb** to match community guidance for a moderate Superset instance.

## First Boot

1. Generates admin password, DB password, and `SECRET_KEY`
2. Creates local Postgres role/DB and runs `superset db upgrade` / `create-admin` / `init`
3. Optionally reconfigures for attached Managed Postgres credentials
4. Installs Caddyfile with droplet public IP and starts `caddy` + `superset`
5. Unlocks SSH

## Service Management

```bash
/opt/status-superset.sh
/opt/start-superset.sh
/opt/stop-superset.sh
/opt/restart-superset.sh
/opt/update-superset.sh 6.1.0
/opt/setup-superset-domain.sh
```

## Updating the pinned version

Edit `application_version` in `template.json`, then rebuild the image.
