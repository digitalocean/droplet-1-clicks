# Buzz 1-Click Droplet Builder

Packer builder for a DigitalOcean Marketplace 1-Click that runs [Buzz](https://buzz.xyz/) (Block's open-source humans + agents workspace) on Ubuntu 24.04.

Upstream self-host path: official Docker Compose bundle from [`block/buzz` `deploy/compose`](https://github.com/block/buzz/tree/main/deploy/compose), with host Caddy for shortlived TLS (Marketplace pattern) instead of `compose.caddy.yml`.

## Directory Structure

```
buzz-24-04/
├── template.json
├── README.md
├── listing.md
├── scripts/
│   └── 010-buzz.sh
└── files/
    ├── etc/
    │   ├── caddy/
    │   │   ├── Caddyfile.tmp
    │   │   └── Caddyfile.domain.tmp
    │   ├── systemd/system/buzz.service
    │   └── update-motd.d/99-one-click
    ├── opt/
    │   ├── buzz/
    │   │   ├── compose.yml
    │   │   ├── env.template   # copied to .env at install time
    │   │   └── run.sh
    │   ├── start|stop|restart|status|update-buzz.sh
    │   └── setup-buzz-domain.sh
    └── var/lib/cloud/scripts/per-instance/001_onboot
```

## Build Requirements

1. Packer with the DigitalOcean plugin (see repo root `README.md`)
2. `DIGITALOCEAN_API_TOKEN` with write access

```bash
export DIGITALOCEAN_API_TOKEN="your_api_token_here"
```

## Validate and Build

From the `droplet-1-clicks` repo root:

```bash
make validate-buzz-24-04
make build-buzz-24-04
```

## What Gets Installed

- Buzz relay image `ghcr.io/block/buzz:<application_version>` (pinned in `template.json`)
- Postgres 17.10, Redis 7.4.10, MinIO (compose sidecars; path-style S3 addressing)
- Docker CE + Compose plugin
- Caddy → `127.0.0.1:3000` with Let's Encrypt shortlived TLS by IP
- UFW (SSH + HTTP/HTTPS), fail2ban

## First Boot

1. Unlock SSH (remove Packer `ForceCommand`)
2. Generate owner + relay Nostr keys via `buzz-admin generate-key` (hex for `.env`)
3. Encode the same owner keypair as `nsec1` / `npub` for Desktop-friendly credentials
4. Fill `/opt/buzz/.env` secrets and set `RELAY_URL` / CORS to the droplet IP
5. Install Caddyfile for the public IP
6. `systemctl start buzz` + `caddy`
7. Write `/root/buzz_credentials.txt` (hex + `nsec1`/`npub`) and `/root/buzz_info.txt`

## Version Pinning

Edit `application_version` in `template.json` (relay semver, e.g. `0.2.0`). The install script sets `BUZZ_IMAGE=ghcr.io/block/buzz:<version>` and pre-pulls that tag.

## License

Builder files follow the droplet-1-clicks repository license. Buzz itself is Apache-2.0.
