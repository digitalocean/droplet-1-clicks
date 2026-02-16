# OpenCode 1-Click Droplet Builder

This directory contains the Packer builder configuration for creating an OpenCode 1-Click DigitalOcean Droplet image.

## Overview

OpenCode is an open-source AI coding agent that runs in the terminal. Users SSH into the droplet and run `opencode` to get AI-assisted coding directly in their shell. This builder creates a fully configured Ubuntu 24.04 LTS Droplet with OpenCode pre-installed and DigitalOcean Gradient AI pre-configured as the inference provider.

## Directory Structure

```
opencode-24-04/
├── template.json                    # Packer build configuration
├── README.md                        # This file
├── listing.md                       # Marketplace catalog copy
├── scripts/
│   └── 010-opencode.sh             # Main installation script
└── files/
    ├── etc/
    │   └── update-motd.d/
    │       └── 99-one-click         # Message of the Day
    ├── opt/
    │   ├── setup-opencode.sh       # First-login setup wizard (Gradient key)
    │   ├── update-opencode.sh      # Update to latest version
    │   └── opencode-version.sh     # Display installed version
    ├── root/
    │   └── .config/
    │       └── opencode/
    │           └── opencode.json   # Pre-configured Gradient AI provider
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
packer validate opencode-24-04/template.json

# Build the image
make build-opencode-24-04
# or: packer build opencode-24-04/template.json
```

## What Gets Installed

- **OpenCode** (version from `application_version` in template.json, currently 1.2.5)
- **DigitalOcean Gradient AI config** – Pre-configured provider in `opencode.json`
- **Git**, **curl**, **jq**, **unzip** – utilities
- **UFW** – Firewall (SSH only, rate-limited)

OpenCode is installed to `/root/.opencode/bin/` and added to PATH via `/etc/profile.d/opencode.sh`.

## First Boot Behavior

1. Removes SSH force-logout (allows normal login)
2. Creates `/root/opencode_info.txt` with getting-started instructions
3. Hooks the Gradient setup wizard (`/opt/setup-opencode.sh`) into `.bashrc` for first login

## First Login Experience

On first SSH login, the setup wizard runs and:
1. Prompts the user for their DigitalOcean Gradient model access key
2. Writes the key to `/root/.local/share/opencode/auth.json`
3. Tests the connection to `https://inference.do-ai.run/v1/models`
4. Self-removes from `.bashrc` (one-time only)

Pre-configured models (no separate provider key needed, all via Gradient):
- **Anthropic**: Claude Opus 4.6, Opus 4.5, Sonnet 4.5 (default), Sonnet 4, 3.7 Sonnet
- **OpenAI**: GPT-5.2, GPT-5, GPT-5.1 Codex Max, GPT-4.1, o3
- **Open Source**: DeepSeek R1 70B, Qwen3 32B, Llama 3.3 70B

If the user chooses option 2 in the setup wizard, the custom Gradient config is removed and OpenCode falls back to its standard built-in providers (75+ options via `/connect`).

## Version Pinning

The `application_version` variable in `template.json` pins the OpenCode version. To bump:

1. Edit `application_version` in `template.json` (e.g., `"1.2.6"`)
2. Rebuild the image

## License

This builder configuration follows the same license as the droplet-1-clicks repository. OpenCode is licensed under MIT.
