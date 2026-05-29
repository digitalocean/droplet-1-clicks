# Codex Universal 1-Click Droplet Builder

This directory contains the Packer builder configuration for creating a Codex Universal 1-Click DigitalOcean Droplet image.

## Overview

[Codex Universal](https://github.com/openai/codex-universal) is OpenAI's reference Docker image for the multi-language development environment used in Codex. This builder pre-installs Docker, pulls the official image (pinned by digest), and configures a persistent dev container with a mounted workspace at `/root/workspace`.

## Directory Structure

```
codex-universal-24-04/
├── template.json                    # Packer build configuration
├── readme.md                        # This file
├── listing.md                       # Marketplace catalog copy
├── SECURITY.md                      # Security audit and hardening notes
├── scripts/
│   └── 010-codex-universal.sh      # Main installation script
└── files/
    ├── etc/
    │   ├── systemd/system/
    │   │   └── codex-universal.service
    │   └── update-motd.d/
    │       └── 99-one-click
    ├── opt/
    │   └── codex-universal/
    │       ├── codex-universal.env
    │       ├── docker-compose.yml
    │       ├── entrypoint-wrapper.sh
    │       ├── validate-codex-universal-env.sh
    │       ├── shell-codex-universal.sh
    │       ├── start-codex-universal.sh
    │       ├── stop-codex-universal.sh
    │       ├── restart-codex-universal.sh
    │       ├── update-codex-universal.sh
    │       ├── status-codex-universal.sh
    │       ├── codex-universal-version.sh
    │       └── test-codex-universal.sh
    └── var/
        └── lib/cloud/scripts/per-instance/
            └── 001_onboot
```

## Build Requirements

### Prerequisites

1. **Packer** — Install from https://www.packer.io/downloads
2. **DigitalOcean API Token** — Generate with write access from https://cloud.digitalocean.com/account/api/tokens

### Environment Setup

```bash
export DIGITALOCEAN_API_TOKEN="your_api_token_here"
```

### Build

From the repository root:

```bash
packer init config/plugins.pkr.hcl
packer build codex-universal-24-04/template.json
```

The build uses an `s-2vcpu-4gb` Droplet because the codex-universal image is large. Image pre-pull during build may take 10+ minutes.

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `application_name` | Codex Universal | Application tag name |
| `application_version` | latest | Human-readable tag label (`TAG` in env file) |
| `image_digest` | sha256:905e512f... | Pinned digest for `ghcr.io/openai/codex-universal` |

Default language runtimes are set in `files/opt/codex-universal/codex-universal.env`. Users can override via droplet environment variables on first boot (validated against upstream supported versions).

### Updating the pinned image digest

```bash
docker pull ghcr.io/openai/codex-universal:latest
docker inspect ghcr.io/openai/codex-universal:latest --format='{{index .RepoDigests 0}}'
```

Update `image_digest` in `template.json` and `IMAGE` / `IMAGE_DIGEST` in `codex-universal.env`, then rebuild.

## Runtime Behavior

1. **Packer build** — Installs Docker, pulls pinned image by digest, enables systemd unit; `.env` is not left in the snapshot
2. **First boot** — `001_onboot` creates `.env` from template, validates droplet env overrides, starts `codex-universal.service`
3. **Usage** — User runs `/opt/codex-universal/shell-codex-universal.sh` to `docker exec` into the running container

## Security

See [SECURITY.md](SECURITY.md) for the full audit. Summary:

- SSH-only UFW firewall
- Image pinned by digest
- `CODEX_ENV_*` allowlist validation on boot
- `security_opt: no-new-privileges:true` on the container
- `/opt/codex-universal/test-codex-universal.sh` includes runtime security checks

**Note:** Docker can bypass UFW if users add `ports:` to compose. The dev container runs as root by design.

## Notes

- No Caddy or HTTP ports — this is a terminal dev environment, not a web application
- The upstream image is amd64-only in production; DigitalOcean Droplets use amd64
- Related: `codex-cli-24-04/` installs the Codex CLI natively with Gradient AI integration

## References

- https://github.com/openai/codex-universal
- https://platform.openai.com/docs/codex
