# Plausible Analytics 1-Click Droplet Builder

Packer builder for a DigitalOcean Marketplace 1-Click that runs [Plausible Community Edition](https://github.com/plausible/community-edition) on Ubuntu 24.04 with Docker Compose and Caddy (shortlived TLS).

Plausible is **not** fully started at image-build time. The snapshot ships Docker, Caddy, helpers, and a first-login setup script that clones Community Edition, writes `.env`, configures Caddy, and brings the stack up.

## Directory Structure

```
plausible-24-04/
├── template.json
├── README.md
├── listing.md
├── scripts/
│   └── 010-update-and-install.sh      # Caddy, Docker, fail2ban, chmod helpers
└── files/
    ├── etc/
    │   ├── caddy/Caddyfile.tmp        # PLACEHOLDER_DOMAIN → shortlived TLS → :8000
    │   └── update-motd.d/99-one-click
    ├── opt/
    │   ├── plausible/compose.override.yml   # bind app to 127.0.0.1:8000
    │   ├── start-plausible.sh
    │   ├── stop-plausible.sh
    │   ├── restart-plausible.sh
    │   ├── status-plausible.sh
    │   └── setup-plausible-domain.sh
    ├── root/
    │   └── plausible-setup.sh         # Interactive first-login setup
    └── var/lib/cloud/scripts/per-instance/
        └── 001_onboot                 # IP into Caddyfile; bashrc hook; unlock SSH
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
packer validate plausible-24-04/template.json
make build-plausible-24-04
# or:
packer build plausible-24-04/template.json
```

Override the Marketplace version pin:

```bash
packer build -var 'application_version=3.2.1' plausible-24-04/template.json
```

Use bare semver (no leading `v`) so autoupdate `latestversion/plausible-analytics.sh` matches. Setup maps that to Community Edition tag/branch `v${version}`.

## What Gets Installed (build time)

- Ubuntu 24.04 LTS
- Docker (`docker.io`) and Docker Compose v2
- Caddy (disabled until onboot/setup)
- UFW with SSH (rate-limited), HTTP, and HTTPS
- fail2ban
- Helpers under `/opt` and `/root/plausible-setup.sh`
- Application metadata (`application_version` from `template.json`)

## First Boot (`001_onboot`)

1. Installs Caddyfile from `Caddyfile.tmp` with the Droplet public IP
2. Enables Caddy (proxy ready; app starts after first-login setup)
3. Appends a one-shot hook so root’s first SSH runs `/root/plausible-setup.sh`
4. Removes the SSH `ForceCommand` lock

## First Login

1. MOTD points at setup and docs
2. Setup prompts for IP HTTPS or custom domain
3. Clones `plausible/community-edition` at `v${application_version}`, pins the compose image, generates `SECRET_KEY_BASE`, starts compose, waits for HTTP and HTTPS
4. On success, restores a clean `/root/.bashrc` (hook removed)
5. User must open `/register` immediately to claim the admin account

## Version Pinning

`application_version` in `template.json` is bare semver (e.g. `3.2.1`). It is written to `/var/lib/digitalocean/application.info` and used by `plausible-setup.sh` as Community Edition branch/tag `v3.2.1` and image `ghcr.io/plausible/community-edition:v3.2.1`.

That CE branch/tag must exist before autoupdate ships a newer version.

## License

Builder files follow the droplet-1-clicks repository license. Plausible Community Edition is AGPL-3.0 (upstream).
