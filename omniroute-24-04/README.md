# OmniRoute 1-Click Droplet Builder

This directory contains the Packer builder configuration for creating an OmniRoute 1-Click DigitalOcean Droplet image.

## Overview

[OmniRoute](https://github.com/diegosouzapw/OmniRoute) is a self-hosted AI gateway with a dashboard and OpenAI-compatible API. This builder creates an Ubuntu 24.04 LTS Droplet with OmniRoute pre-installed (Docker), Redis, Caddy HTTPS (shortlived TLS by IP), and optional DigitalOcean Serverless Inference configuration (including Intelligent Inference Router).

## Directory Structure

```
omniroute-24-04/
├── template.json
├── README.md
├── listing.md
├── scripts/
│   └── 010-omniroute.sh
└── files/
    ├── etc/
    │   ├── caddy/Caddyfile.tmp
    │   ├── setup_wizard.sh
    │   ├── systemd/system/omniroute.service
    │   ├── systemd/system/omniroute-apply-inference.service
    │   └── update-motd.d/99-one-click
    ├── opt/
    │   ├── start|stop|restart|status|update-omniroute.sh
    │   ├── apply-inference-from-env.sh
    │   ├── retry-apply-inference-after-cloud-init.sh
    │   ├── setup-omniroute-domain.sh
    │   └── omniroute/
    │       ├── compose.yml
    │       ├── env.template     # → /opt/omniroute/.env on install
    │       ├── inference-helpers.sh
    │       └── run.sh
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
packer validate omniroute-24-04/template.json
make build-omniroute-24-04
# or: packer build omniroute-24-04/template.json
```

## What Gets Installed

- **OmniRoute** (`diegosouzapw/omniroute:latest` from `application_version` in `template.json`)
- **Redis** (`redis:8.6.5-alpine`) for rate limiting / shared cache — compose-network only, password-protected (`REDIS_PASSWORD`)
- **Caddy** – reverse proxy on ports 80/443 to `127.0.0.1:20128` with shortlived TLS by IP
- **UFW** – SSH (rate-limited), HTTP, HTTPS
- **fail2ban**

## First Boot Behavior

1. Generates `INITIAL_PASSWORD`, `JWT_SECRET`, and `API_KEY_SECRET`
2. Installs Caddyfile (shortlived TLS for droplet IP) and starts `omniroute` + `caddy`
3. If `MODEL_ACCESS_KEY` is set (droplet env or `/opt/omniroute/.env`), configures the DigitalOcean provider and skips the wizard
4. Otherwise hooks `/etc/setup_wizard.sh` into root `.bashrc` for first login
5. Writes `/root/omniroute_info.txt`

## First Login / Access

1. Open `https://<droplet-ip>` and sign in with `INITIAL_PASSWORD` from the MOTD
2. If Serverless Inference was not auto-configured, the SSH wizard can set a DigitalOcean model access key (Enter = model, `R` = Intelligent Inference Router)
3. Create an Endpoint API key in the dashboard, then call `https://<droplet-ip>/v1`

### Auto-configuration from droplet environment

| Variable | Required | Description |
|----------|----------|-------------|
| `MODEL_ACCESS_KEY` | Yes (for auto) | DigitalOcean model access key |
| `INFERENCE_MODEL` | No | Model id (live list preferred; fallback `minimax-m2.5`) |
| `DO_INFERENCE_ROUTER` | No | Intelligent Inference Router name → `router:<name>` |

## Version Pinning

Edit `application_version` in `template.json` (`latest` or a SemVer such as `3.8.50`), then rebuild. On a running droplet:

```bash
sudo /opt/update-omniroute.sh              # pull current OMNIROUTE_IMAGE tag
sudo /opt/update-omniroute.sh 3.8.50       # pin SemVer
sudo /opt/update-omniroute.sh latest
```

## Droplet Size

Packer builds with `s-2vcpu-4gb`. OmniRoute’s Docker default heap is raised to `OMNIROUTE_MEMORY_MB=2048` for dashboard/light chat. Heavy concurrent coding-agent `/v1/responses` workloads may need a larger droplet and a higher `OMNIROUTE_MEMORY_MB`.

## License

This builder configuration follows the same license as the droplet-1-clicks repository. OmniRoute licensing is governed by the upstream project.
