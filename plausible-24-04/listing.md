# Plausible Analytics 1-Click Application

Deploy [Plausible Community Edition](https://github.com/plausible/community-edition) — privacy-friendly web analytics — on Ubuntu 24.04 with Docker Compose and Caddy (HTTPS via shortlived TLS).

## What is Plausible?

Plausible is lightweight, open-source web analytics. It is cookie-free by default, GDPR-friendly, and a simple alternative to heavier analytics stacks. This 1-Click runs the official Community Edition stack (Plausible app, PostgreSQL, and ClickHouse) behind Caddy.

## Included System Components

- **Ubuntu 24.04 LTS**
- **Plausible Community Edition** (version from `application_version` in the image build; image `ghcr.io/plausible/community-edition`)
- **Docker** and **Docker Compose v2**
- **Caddy** reverse proxy (ports 80/443 → app on `127.0.0.1:8000`) with Let's Encrypt shortlived TLS
- **UFW** (SSH rate-limited, HTTP, HTTPS)
- **fail2ban**

## System Requirements

| Use case | RAM | CPU | Storage |
|----------|-----|-----|---------|
| Minimum (this image) | 4 GB | 2 vCPU | 80 GB |
| Busier sites | 8 GB+ | 4 vCPU | 100 GB+ |

ClickHouse benefits from extra RAM under load. Prefer at least the default Marketplace size (`s-2vcpu-4gb`).

## Getting Started

1. Create the Droplet from the Marketplace 1-Click and add an SSH key.
2. SSH in as root: `ssh root@your-droplet-ip`
3. On first login, `/root/plausible-setup.sh` runs and prompts you to:
   - **1** — use the Droplet IP with HTTPS (shortlived TLS), or
   - **2** — use a custom domain (DNS A record required first)
4. When setup finishes, open `https://your-droplet-ip/register` (or your domain) and create the **first account immediately** — that user becomes admin.
5. Further signups are invite-only (`DISABLE_REGISTRATION=invite_only`).

App files live under `/docker/plausible` (compose, `.env` with `BASE_URL` and `SECRET_KEY_BASE`).

### Custom domain (later)

```bash
/opt/setup-plausible-domain.sh
```

Point an A record at the Droplet first. The script updates Caddy and `BASE_URL`, then restarts the stack.

## Start / Stop / Restart / Status

```bash
/opt/start-plausible.sh
/opt/stop-plausible.sh
/opt/restart-plausible.sh
/opt/status-plausible.sh
```

These wrap `docker compose` in `/docker/plausible` and manage Caddy where needed.

## Updating Plausible

Pin matches Marketplace `application_version` (Community Edition tag, e.g. `v3.2.1`):

```bash
cd /docker/plausible
docker compose pull
docker compose up -d
```

To move to a newer Community Edition release that has a matching branch/tag on [plausible/community-edition](https://github.com/plausible/community-edition):

```bash
cd /docker/plausible
git fetch --depth 1 origin vX.Y.Z
git checkout vX.Y.Z
# ensure compose image pin matches, then:
docker compose pull
docker compose up -d
```

Also update `/var/lib/digitalocean/application.info` `application_version` if you track it for Marketplace tooling.

## Useful paths

| Path | Purpose |
|------|---------|
| `/docker/plausible` | Compose project and `.env` |
| `/root/plausible-setup.sh` | First-login setup (re-runnable if needed) |
| `/etc/caddy/Caddyfile` | Reverse proxy / TLS |
| `/opt/setup-plausible-domain.sh` | Switch to a custom domain |

## Documentation

- [Plausible self-hosting docs](https://plausible.io/docs/self-hosting)
- [Community Edition repo](https://github.com/plausible/community-edition)
