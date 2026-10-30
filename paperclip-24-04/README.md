# Paperclip 1-Click Droplet Builder

This directory contains the Packer builder configuration for creating a Paperclip 1-Click DigitalOcean Droplet image.

## Overview

[Paperclip](https://github.com/paperclipai/paperclip) is open-source orchestration for teams of AI agents. This builder creates an Ubuntu 24.04 LTS Droplet with a managed Paperclip CLI install (`paperclipai`), Caddy HTTPS (shortlived TLS by IP), and first-boot configuration for authenticated/public mode behind a reverse proxy.

Latest stable version pinned in `template.json` (from [paperclipai/paperclip releases](https://github.com/paperclipai/paperclip/releases)): **2026.916.1**.

## Directory Structure

```
paperclip-24-04/
├── template.json
├── README.md
├── listing.md
├── scripts/
│   └── 010-paperclip.sh
└── files/
    ├── etc/
    │   ├── caddy/Caddyfile.tmp
    │   ├── setup_wizard.sh
    │   ├── systemd/system/paperclip.service
    │   ├── systemd/system/paperclip-apply-inference.service
    │   └── update-motd.d/99-one-click
    ├── opt/
│   ├── start|stop|restart|status|update-paperclip.sh
│   ├── apply-inference-from-env.sh
│   ├── claim-paperclip-admin.sh
│   ├── setup-paperclip-domain.sh
│   ├── write-paperclip-config.sh
│   └── paperclip/
│       └── env.template     # → /opt/paperclip.env on install
└── var/lib/cloud/scripts/per-instance/001_onboot
```

## Build Requirements

1. **Packer**: https://www.packer.io/downloads
2. **DigitalOcean API Token** with write access

```bash
export DIGITALOCEAN_API_TOKEN="your_api_token_here"
```

## Building the Image

From the repository root:

```bash
packer validate paperclip-24-04/template.json
make build-paperclip-24-04
# or: packer build paperclip-24-04/template.json
```

## What Gets Installed

- **Paperclip** managed CLI (`paperclipai@2026.916.1` from `application_version` in `template.json`)
- **Node.js 24** (required by Paperclip)
- **PostgreSQL** (local package; required for authenticated/public — embedded Postgres is refused)
- **Caddy** – reverse proxy on ports 80/443 to `127.0.0.1:3100` with shortlived TLS by IP
- **UFW** – SSH (rate-limited), HTTP, HTTPS
- **fail2ban**
- Dedicated **`paperclip`** system user

## First Boot Behavior

1. Generates `BETTER_AUTH_SECRET`, `PAPERCLIP_TOOL_ACTION_SIGNING_SECRET`, and local Postgres `DATABASE_URL`
2. Writes authenticated/public/loopback instance config with `PAPERCLIP_PUBLIC_URL=https://<droplet-ip>`
3. Installs Caddyfile (shortlived TLS for droplet IP) and starts `postgresql` + `paperclip` + `caddy`
4. Creates a bootstrap invite, auto-claims it with generated `ADMIN_EMAIL` / `INITIAL_PASSWORD`, then locks open signup
5. Optionally stages `MODEL_ACCESS_KEY` (if set); otherwise hooks the SSH setup wizard
6. Writes `/root/paperclip_info.txt`

## First Login / Access

1. Open `https://<droplet-ip>` and sign in with `ADMIN_EMAIL` / `INITIAL_PASSWORD` from the SSH MOTD
2. Complete UI onboarding (company, agents, goals)
3. If `MODEL_ACCESS_KEY` was not staged at create time, the SSH wizard can stage a DigitalOcean model access key

### Staging from droplet environment

| Variable | Required | Description |
|----------|----------|-------------|
| `MODEL_ACCESS_KEY` | No (optional; needed for DO auto-stage) | DigitalOcean model access key |
| `INFERENCE_MODEL` | No | Model id (live list preferred; fallback `minimax-m2.5`) |
| `DO_INFERENCE_ROUTER` | No | Intelligent Inference Router name → `router:<name>` |
| `OPENAI_API_KEY` | No | OpenAI key written into `/opt/paperclip.env` on first boot |
| `ANTHROPIC_API_KEY` | No | Anthropic key written into `/opt/paperclip.env` on first boot |
| `OPENROUTER_API_KEY` | No | OpenRouter key written into `/opt/paperclip.env` on first boot |

`MODEL_ACCESS_KEY` is optional. When set, first boot stages it in `/opt/paperclip.env` and skips the interactive wizard. If `OPENAI_API_KEY` is empty, apply also sets `OPENAI_API_KEY`/`OPENAI_BASE_URL` for OpenAI-compatible adapters; an existing distinct OpenAI key is preserved. Paperclip has no native DigitalOcean provider API — connect providers in the UI after bootstrap. Create keys at https://cloud.digitalocean.com/model-studio/manage-keys.

## Management

| Action | Command |
|--------|---------|
| Start | `/opt/start-paperclip.sh` |
| Stop | `/opt/stop-paperclip.sh` |
| Restart | `/opt/restart-paperclip.sh` |
| Status | `/opt/status-paperclip.sh` |
| Update | `/opt/update-paperclip.sh` |
| Domain | `/opt/setup-paperclip-domain.sh` |
| DO inference | `/opt/apply-inference-from-env.sh` |
| Setup wizard | `/etc/setup_wizard.sh` |
| Doctor | `su - paperclip -c "paperclipai doctor"` |
| Logs | `journalctl -u paperclip -f` |

## Why managed install (not Docker build)?

Paperclip publishes a recommended managed npm install (`paperclipai`). The upstream Docker Compose files build from source (no published Hub image for this release). The managed CLI matches [INSTALLING.md](https://github.com/paperclipai/paperclip/blob/master/doc/INSTALLING.md), pins cleanly via `application_version`, and pairs with Caddy the same way as other Marketplace AI 1-Clicks.

## References

- https://github.com/paperclipai/paperclip
- https://paperclip.ing
- https://github.com/paperclipai/paperclip/releases/tag/v2026.916.1
