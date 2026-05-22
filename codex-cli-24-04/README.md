# Codex CLI 1-Click Droplet Builder

This directory contains the Packer builder configuration for creating a Codex CLI 1-Click DigitalOcean Droplet image.

## Overview

Codex CLI is OpenAI's terminal-based coding agent. Users SSH into the droplet and run `codex` to get AI-assisted coding directly in their shell. This builder creates a fully configured Ubuntu 24.04 LTS Droplet with Codex CLI pre-installed and DigitalOcean Gradient AI pre-configured as the inference provider.

## Directory Structure

```
codex-cli-24-04/
├── template.json                    # Packer build configuration
├── README.md                        # This file
├── listing.md                       # Marketplace catalog copy
├── scripts/
│   └── 010-codex-cli.sh            # Main installation script
└── files/
    ├── etc/
    │   └── update-motd.d/
    │       └── 99-one-click         # Message of the Day
    ├── opt/
    │   ├── apply-gradient-from-env.sh  # Apply GRADIENT_KEY from env on boot
    │   ├── codex-cli.env           # Droplet env template (GRADIENT_KEY/MODEL)
    │   ├── setup-codex-cli.sh      # First-login setup wizard (Gradient key)
    │   ├── update-codex-cli.sh     # Update to latest version
    │   └── codex-cli-version.sh    # Display installed version
    ├── root/
    │   └── .codex/
    │       └── config.toml         # Pre-configured Gradient AI provider
    └── var/
        └── lib/
            └── cloud/
                └── scripts/
                    └── per-instance/
                        └── 001_onboot  # First-boot configuration script
```

## Build Requirements

### Prerequisites

1. **Packer**: Install from https://www.packer.io/downloads
2. **DigitalOcean API Token**: Generate with write access from https://cloud.digitalocean.com/account/api/tokens

### Environment Setup

```bash
export DIGITALOCEAN_API_TOKEN="your_api_token_here"
```

## Building the Image

```bash
# Initialize Packer plugins (first time only)
packer init config/plugins.pkr.hcl

# Validate the template
packer validate codex-cli-24-04/template.json

# Build the image
make build-codex-cli-24-04
# or: packer build codex-cli-24-04/template.json
```

## What Gets Installed

- **Codex CLI** (version from `application_version` in template.json)
- **bwrap** sandbox helper (bundled with Codex releases)
- **DigitalOcean Gradient AI config** – Pre-configured provider in `/root/.codex/config.toml`
- **Git**, **curl**, **jq**, **unzip** – utilities
- **UFW** – Firewall (SSH only, rate-limited)

Codex CLI is installed to `/usr/local/bin/codex`. Authentication uses your Gradient model access key stored in `/root/.codex/env` as `MODEL_ACCESS_KEY`.

## First Boot Behavior

1. Removes SSH force-logout (allows normal login)
2. Sources `/etc/environment` and runs `/opt/apply-gradient-from-env.sh`
3. If `GRADIENT_KEY` is set (droplet env or `/opt/codex-cli.env`), configures Codex and skips the wizard
4. Otherwise hooks the Gradient setup wizard (`/opt/setup-codex-cli.sh`) into `.bashrc` for first login
5. Creates `/root/codex_cli_info.txt` with getting-started instructions

### Environment Variables

| Variable | Description |
|----------|-------------|
| `GRADIENT_KEY` | DigitalOcean Gradient model access key |
| `GRADIENT_MODEL` | Optional model id (default: `openai-gpt-5.5`) |

These can be set as droplet environment variables at create time (written to `/etc/environment`) or in `/opt/codex-cli.env`.

## First Login Experience

On first SSH login, the setup wizard runs and:

1. Prompts the user for their DigitalOcean Gradient model access key
2. Writes the key to `/root/.codex/env` as `MODEL_ACCESS_KEY`
3. Tests the connection to `https://inference.do-ai.run/v1/models`
4. Self-removes from `.bashrc` (one-time only)

Default model: **GPT-5.5** (`openai-gpt-5.5` via DigitalOcean Gradient).

Alternatively, users can run `codex login` for ChatGPT subscription OAuth instead of Gradient.

## Version Pinning

The `application_version` variable in `template.json` pins the Codex CLI version. To bump:

1. Edit `application_version` in `template.json` (e.g., `"0.134.0"`)
2. Rebuild the image

## License

This builder configuration follows the same license as the droplet-1-clicks repository. Codex CLI is open source (Apache-2.0).
