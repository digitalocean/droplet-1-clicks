# OpenHands 1-Click Droplet Builder

This directory contains the Packer builder configuration for creating an OpenHands (Agent Canvas) 1-Click DigitalOcean Droplet image.

## Overview

[OpenHands](https://www.openhands.dev/) Agent Canvas is an open-source, self-hosted control center for AI coding agents and automations. This builder creates an Ubuntu 24.04 LTS Droplet with Agent Canvas pre-installed, running in public mode behind Caddy, with optional DigitalOcean Gradient AI configuration.

## Directory Structure

```
openhands-24-04/
├── template.json                    # Packer build configuration
├── README.md                        # This file
├── listing.md                       # Marketplace catalog copy
├── scripts/
│   └── 010-openhands.sh             # Main installation script
└── files/
    ├── etc/
    │   ├── caddy/Caddyfile.tmp      # Shortlived TLS reverse proxy to :8000
    │   ├── setup_wizard.sh          # First-login wizard (API key + Gradient)
    │   ├── systemd/system/openhands.service
    │   ├── systemd/system/openhands-apply-gradient.service
    │   └── update-motd.d/99-one-click
    ├── opt/
    │   ├── openhands.env            # Secrets + optional GRADIENT_* vars
    │   ├── apply-gradient-from-env.sh
    │   ├── retry-apply-gradient-after-cloud-init.sh
    │   ├── start-openhands.sh
    │   ├── stop-openhands.sh
    │   ├── restart-openhands.sh
    │   ├── status-openhands.sh
    │   ├── update-openhands.sh
    │   └── setup-openhands-domain.sh
    └── var/lib/cloud/scripts/per-instance/001_onboot
```

## Build Requirements

1. **Packer**: https://www.packer.io/downloads
2. **DigitalOcean API Token** with write access

```bash
export DIGITALOCEAN_API_TOKEN="your_api_token_here"
```

## Building the Image

```bash
# From the droplet-1-clicks repo root (after installing the DigitalOcean Packer plugin; see root README)
packer validate openhands-24-04/template.json
make build-openhands-24-04
```

## What Gets Installed

- **OpenHands Agent Canvas** (`@openhands/agent-canvas`, version from `application_version` in `template.json`)
- **Node.js 22** and **uv** (agent-server / automation via uvx)
- **Caddy** – reverse proxy on ports 80/443 to `127.0.0.1:8000` with shortlived TLS by IP
- **UFW** – SSH (rate-limited), HTTP, HTTPS
- **fail2ban**
- Dedicated **`openhands`** user and `/home/openhands/projects` workspace

## First Boot Behavior

1. Removes SSH force-logout
2. Generates unique `LOCAL_BACKEND_API_KEY` and `OH_SECRET_KEY`
3. Installs Caddyfile (shortlived TLS for droplet IP) and starts `openhands` + `caddy`
4. If `GRADIENT_KEY` is set (droplet env or `/opt/openhands.env`), configures Gradient and skips the provider wizard
5. Otherwise hooks `/etc/setup_wizard.sh` into root `.bashrc` for first login
6. Writes `/root/openhands_info.txt`

## First Login / Access

1. Open `https://<droplet-ip>` and paste `LOCAL_BACKEND_API_KEY` from the MOTD or `/opt/openhands.env`
2. If Gradient was not auto-configured, the SSH wizard can set a Gradient model access key
3. Or configure any LLM under **Settings > LLM** in the UI (Advanced: custom model + base URL)

### Auto-configuration from droplet environment

| Variable | Required | Description |
|----------|----------|-------------|
| `GRADIENT_KEY` | Yes (for auto) | Gradient model access key |
| `GRADIENT_MODEL` | No | Model id (default: `minimax-m2.5`) |

## Version Pinning

Edit `application_version` in `template.json` (Agent Canvas npm version), then rebuild.

## License

This builder configuration follows the same license as the droplet-1-clicks repository. OpenHands / Agent Canvas licensing is governed by the upstream project.
