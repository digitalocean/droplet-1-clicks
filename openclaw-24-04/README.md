# OpenClaw 1-Click Droplet Builder

This directory contains the Packer builder configuration for creating an OpenClaw 1-Click DigitalOcean Droplet image.

## Overview

[OpenClaw](https://github.com/openclaw/openclaw) is a self-hosted personal AI assistant and gateway. This builder creates an Ubuntu 24.04 LTS Droplet with OpenClaw pre-installed, the Control UI behind Caddy (shortlived TLS by IP), Docker sandboxes, and optional DigitalOcean Serverless Inference configuration.

## Directory Structure

```
openclaw-24-04/
├── template.json                    # Packer build configuration
├── README.md                        # This file
├── listing.md                       # Marketplace catalog copy
├── scripts/
│   └── openclaw.sh                  # Main installation script
├── files/
│   ├── etc/
│   │   ├── caddy/Caddyfile.tmp      # Shortlived TLS reverse proxy to :18789
│   │   ├── config/                  # Provider / gateway JSON templates
│   │   ├── setup_wizard.sh          # First-login wizard (providers + inference)
│   │   ├── systemd/system/openclaw.service
│   │   └── update-motd.d/99-one-click
│   ├── opt/
│   │   ├── openclaw.env             # Secrets + optional inference env vars
│   │   ├── start-openclaw.sh
│   │   ├── stop-openclaw.sh
│   │   ├── restart-openclaw.sh
│   │   ├── status-openclaw.sh
│   │   ├── update-openclaw.sh
│   │   ├── setup-openclaw-domain.sh
│   │   └── ...                      # CLI, pairing, sandbox, sync helpers
│   ├── usr/local/bin/openclaw       # PATH wrapper → /opt/openclaw-cli.sh
│   └── var/lib/cloud/scripts/per-instance/001_onboot
└── util/                            # Optional clawdbot → OpenClaw migration helpers
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
packer validate openclaw-24-04/template.json
make build-openclaw-24-04
```

## What Gets Installed

- **OpenClaw** (npm package version from `application_version` in `template.json`)
- **Node.js 22** and **Docker** (sandbox image built at snapshot time and on first boot)
- **Caddy** – reverse proxy on ports 80/443 to `127.0.0.1:18789` with shortlived TLS by IP
- **UFW** – SSH (rate-limited), HTTP, HTTPS
- **fail2ban**
- Dedicated **`openclaw`** user and workspace under `/home/openclaw/.openclaw/`

## First Boot Behavior

1. Generates a unique `OPENCLAW_GATEWAY_TOKEN`
2. Installs Caddyfile (shortlived TLS for droplet IP) and starts `openclaw` + `caddy`
3. Syncs gateway tokens / `trustedProxies` into `openclaw.json`
4. If `MODEL_ACCESS_KEY` is set (droplet env or `/opt/openclaw.env`), configures Serverless Inference and skips the provider wizard
5. Otherwise hooks `/etc/setup_wizard.sh` into root `.bashrc` for first login
6. Removes SSH force-logout after init completes

## First Login / Access

1. Open `https://<droplet-ip>` and paste `OPENCLAW_GATEWAY_TOKEN` from the MOTD or `/opt/openclaw.env`
2. Complete Control UI pairing from SSH (`/opt/openclaw-control-ui-pairing.sh`)
3. If Serverless Inference was not auto-configured, the SSH wizard can set a provider

### Auto-configuration from droplet environment

| Variable | Required | Description |
|----------|----------|-------------|
| `MODEL_ACCESS_KEY` | Yes (for auto) | DigitalOcean model access key |
| `INFERENCE_MODEL` | No | Model id from the Serverless Inference API |

## Version Pinning

Edit `application_version` in `template.json` (OpenClaw npm version, e.g. `v2026.8.1`), then rebuild.

## License

This builder configuration follows the same license as the droplet-1-clicks repository. OpenClaw licensing is governed by the upstream project.
