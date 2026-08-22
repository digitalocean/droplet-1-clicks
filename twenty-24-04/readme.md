# Twenty CRM 1-Click Application for DigitalOcean

This directory contains the Packer configuration and supporting files to build a DigitalOcean Marketplace 1-Click image for [Twenty CRM](https://github.com/twentyhq/twenty).

## Overview

Twenty is an open-source CRM built with TypeScript, NestJS, React, PostgreSQL, and Redis. This 1-Click deploys Twenty v2.8.3 using the official Docker Compose stack behind Caddy with HTTPS via Let's Encrypt short-lived IP certificates.

## What's Included

- **Twenty CRM v2.8.3** — Official `twentycrm/twenty` Docker image
- **PostgreSQL 16** — Database backend
- **Redis** — Background job queue
- **Caddy** — Reverse proxy with automatic TLS
- **Docker & Docker Compose v2** — Container orchestration
- **Ubuntu 24.04 LTS** — Base operating system
- **UFW Firewall** — Pre-configured security
- **Systemd service** — Service lifecycle management
- **Helper scripts** — Start, stop, restart, update, status, and domain setup

## Architecture

Docker Compose runs four containers:

1. **server** — Twenty API and web UI (localhost:3000, proxied by Caddy)
2. **worker** — Background job processor
3. **db** — PostgreSQL 16 with persistent volume
4. **redis** — Redis with `noeviction` policy

Caddy terminates HTTPS on ports 80/443 and reverse-proxies to the Twenty server on localhost.

## Directory Structure

```
twenty-24-04/
├── template.json
├── scripts/
│   └── twenty.sh
├── files/
│   ├── etc/
│   │   ├── caddy/Caddyfile.tmp
│   │   ├── systemd/system/twenty.service
│   │   └── update-motd.d/99-one-click
│   ├── opt/twenty/
│   │   ├── docker-compose.yml
│   │   ├── twenty.env
│   │   ├── start-twenty.sh
│   │   ├── stop-twenty.sh
│   │   ├── restart-twenty.sh
│   │   ├── update-twenty.sh
│   │   ├── status-twenty.sh
│   │   └── setup-twenty-domain.sh
│   └── var/lib/cloud/scripts/per-instance/001_onboot
├── listing.md
└── readme.md
```

## Building the Image

### Prerequisites

1. DigitalOcean API token with write access
2. Packer 1.8+ with the DigitalOcean plugin
3. `DIGITALOCEAN_API_TOKEN` environment variable set

### Build Steps

```bash
cd droplet-1-clicks
export DIGITALOCEAN_API_TOKEN="your_token_here"
packer init config/plugins.pkr.hcl   # once per checkout
packer build twenty-24-04/template.json
```

The build creates a temporary Droplet, installs Docker and Caddy, pre-pulls Twenty images, and snapshots the result.

### Build Time

Approximately 10–15 minutes depending on network speed for Docker image pulls.

## First Boot Process

When a Droplet is created from this snapshot:

1. Cloud-init runs `001_onboot`
2. Unique `ENCRYPTION_KEY` and `PG_DATABASE_PASSWORD` are generated
3. `SERVER_URL` is set to `https://<droplet-ip>`
4. Caddy is configured with a short-lived ACME IP certificate
5. Twenty Docker Compose stack starts
6. Database migrations run (may take several minutes)

## Security

- Secrets are generated per-droplet on first boot using OpenSSL
- Twenty listens on `127.0.0.1:3000` only; external access is via Caddy
- UFW allows SSH (rate-limited), HTTP, and HTTPS
- `/opt/twenty/.env` is chmod 600 after secret generation

## Version Information

- **Twenty**: v2.8.3 (set via `application_version` in `template.json`)
- **PostgreSQL**: 16
- **Ubuntu**: 24.04 LTS

To bump the Twenty version, update `application_version` in `template.json` and rebuild.

## Testing

After building:

1. Create a Droplet from the snapshot (minimum s-2vcpu-2gb)
2. Wait 3–5 minutes for first boot
3. SSH in and run `/opt/twenty/status-twenty.sh`
4. Open `https://<droplet-ip>` and complete workspace setup

## Resources

- [Twenty Documentation](https://docs.twenty.com/)
- [Docker Compose Self-Hosting Guide](https://docs.twenty.com/developers/self-host/capabilities/docker-compose)
- [Twenty GitHub](https://github.com/twentyhq/twenty)
