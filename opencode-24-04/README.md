# OpenCode 1-Click Droplet Builder

This directory contains the Packer builder configuration for creating an OpenCode 1-Click DigitalOcean Droplet image.

## Overview

OpenCode is an open-source AI coding agent that runs in the terminal. Users SSH into the droplet and run `opencode` to get AI-assisted coding directly in their shell. This builder creates a fully configured Ubuntu 24.04 LTS Droplet with OpenCode pre-installed and DigitalOcean Gradient AI pre-configured as the inference provider. The first-login wizard lists models live from `GET https://inference.do-ai.run/v1/models` (same helper as Hermes and OpenClaw).

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
    │   ├── apply-gradient-from-env.sh # Auto-config from GRADIENT_KEY / GRADIENT_MODEL / DO_INFERENCE_ROUTER
    │   ├── opencode.env              # Optional Gradient env vars (see 001_onboot)
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

- **OpenCode** (version from `application_version` in template.json; see `template.json` for the current pin)
- **DigitalOcean Gradient AI config** – Pre-configured provider in `files/root/.config/opencode/opencode.json` (`baseURL` only; no extra client options that imply prompt caching on Gradient)
- **Git**, **curl**, **jq**, **unzip** – utilities
- **UFW** – Firewall (SSH only, rate-limited)

OpenCode is installed to `/root/.opencode/bin/` and PATH is set in `/etc/profile.d/opencode.sh`. Claude and other Gradient models are exposed through the same OpenAI-compatible `digitalocean` provider; authentication uses your Gradient model access key in `auth.json`.

## Inference usage on Gradient

Field testing shows **cache-related usage fields are often zero** on `https://inference.do-ai.run/v1` across models, so this image **does not** set OpenCode’s `setCacheKey` (or similar) for Gradient. Billing and semantics should be taken from **DigitalOcean Gen AI / Gradient documentation**, not from those API numbers alone. A short note is in **`001_onboot`** (`opencode_info.txt`) and **`listing.md`**.

## First Boot Behavior

1. Removes SSH force-logout (allows normal login)
2. Creates `/root/opencode_info.txt` with getting-started instructions
3. If `GRADIENT_KEY` is set in droplet environment (`/etc/environment`) or `/opt/opencode.env`, applies Gradient config automatically (honoring `GRADIENT_MODEL` or `DO_INFERENCE_ROUTER`) and skips the setup wizard
4. Otherwise hooks the Gradient setup wizard (`/opt/setup-opencode.sh`) into `.bashrc` for first login

## First Login Experience

If `GRADIENT_KEY` was not passed at droplet creation, on first SSH login the setup wizard runs and:
1. Prompts the user for their DigitalOcean Gradient model access key
2. Fetches the current chat-capable catalog from `https://inference.do-ai.run/v1/models` and presents it as a numbered list — or `R` to use an Intelligent Inference Router
3. Writes the key to `/root/.local/share/opencode/auth.json` under **`digitalocean`**, replaces `provider.digitalocean.models` with that live list, and sets the default model (or `digitalocean/router:<name>`)
4. Self-removes from `.bashrc` (one-time only)

### Auto-configuration from droplet environment

Pass these environment variables when creating the droplet (or set them in `/opt/opencode.env` before first boot):

| Variable | Required | Description |
|----------|----------|-------------|
| `GRADIENT_KEY` | Yes | Gradient model access key from the control panel |
| `GRADIENT_MODEL` | No | Model id from `GET /v1/models`. If unset, the first chat-capable model from that list is used. |
| `DO_INFERENCE_ROUTER` | No | Optional Intelligent Inference Router name (`router:<name>`). If set, becomes the default. |

On first boot, `/opt/apply-gradient-from-env.sh` writes `/root/.local/share/opencode/auth.json`, replaces the DigitalOcean model list in `opencode.json` from the live catalog, and skips the interactive wizard.

Models are not pinned in the image. The live chat-capable list comes from [Retrieve available models](https://docs.digitalocean.com/products/inference/how-to/retrieve-available-models/). The Intelligent Inference Router remains available as `digitalocean/router:<name>`.

If the user chooses option 2 in the setup wizard, the custom Gradient config is removed and OpenCode falls back to its standard built-in providers (75+ options via `/connect`).

## Version Pinning

The `application_version` variable in `template.json` pins the OpenCode version. To bump:

1. Edit `application_version` in `template.json` (e.g., `"1.2.6"`)
2. Rebuild the image

## License

This builder configuration follows the same license as the droplet-1-clicks repository. OpenCode is licensed under MIT.
