# Grok Build 1-Click Droplet Builder

This directory contains the Packer builder configuration for creating a Grok Build 1-Click DigitalOcean Droplet image.

## Overview

Grok Build is xAI's terminal-based coding agent. Users SSH into the droplet and run `grok` to get agentic, AI-assisted coding directly in their shell. This builder creates a fully configured Ubuntu 24.04 LTS Droplet with Grok Build pre-installed and **DigitalOcean Serverless Inference** pre-configured as the model provider (with the Intelligent Inference Router supported, and xAI account auth as a fallback).

## Directory Structure

```
grok-build-24-04/
├── template.json                    # Packer build configuration
├── README.md                        # This file
├── listing.md                       # Marketplace catalog copy
├── scripts/
│   └── 010-grok-build.sh           # Main installation script
└── files/
    ├── etc/
    │   └── update-motd.d/
    │       └── 99-one-click         # Message of the Day
    ├── opt/
    │   ├── apply-inference-from-env.sh  # Apply DO_MODEL_ACCESS_KEY/XAI_API_KEY on boot
    │   ├── grok-build.env           # Droplet env template
    │   ├── setup-grok-build.sh      # First-login setup wizard (+ model picker)
    │   ├── grok-login.sh            # Browser-free xAI device-code sign-in
    │   └── update-grok-build.sh     # Update to latest version
    ├── root/
    │   └── .grok/
    │       └── config.toml          # Pre-configured DigitalOcean provider + router
    └── var/
        └── lib/
            └── cloud/
                └── scripts/
                    └── per-instance/
                        └── 001_onboot  # First-boot configuration script
```

## Build Requirements

### Prerequisites

1. **Packer**: Install from <https://www.packer.io/downloads>
2. **DigitalOcean API Token**: Generate with write access from <https://cloud.digitalocean.com/account/api/tokens>

### Environment Setup

```bash
export DIGITALOCEAN_API_TOKEN="your_api_token_here"
```

## Building the Image

```bash
# Validate the template
packer validate grok-build-24-04/template.json

# Build the image
packer build grok-build-24-04/template.json
```

## What Gets Installed

- **Grok Build** (version from `application_version` in `template.json`; pinned via the official installer)
- **DigitalOcean Serverless Inference config** – Pre-configured provider in `/root/.grok/config.toml`
- **Git**, **curl**, **jq**, **unzip** – utilities
- **UFW** – Firewall (SSH only, rate-limited)

Grok Build is installed to `/root/.grok/bin/grok` (with an `agent` alias) and PATH is set for all login shells via `/etc/profile.d/grok-build.sh`.

## Model Provider Configuration

Grok Build supports any OpenAI-compatible provider through per-model entries in `~/.grok/config.toml` (`base_url` + `env_key`, switchable with `-m`/`/model`). This image pre-configures **DigitalOcean Serverless Inference**:

- **Endpoint**: `https://inference.do-ai.run/v1`
- **Auth**: Bearer token (model access key) read from the `MODEL_ACCESS_KEY` env var
- **Default model**: `gpt-5-5` (GPT-5.5)
- **Catalog**: GPT-5.x, Claude Opus/Sonnet, Kimi, MiniMax, GLM, Llama, Qwen, DeepSeek (see `config.toml`)
- **Intelligent Inference Router**: the `router` alias uses `model = "router:<name>"`

### Authentication priority

| Method | How | env var |
|--------|-----|---------|
| DigitalOcean Serverless Inference (default) | `DO_MODEL_ACCESS_KEY`, `/opt/grok-build.env`, or wizard | `MODEL_ACCESS_KEY` |
| xAI API key | `XAI_API_KEY`, `/opt/grok-build.env`, or wizard | `XAI_API_KEY` |
| xAI account sign-in | `/opt/grok-login.sh` or `grok login --device-auth` (wizard option 1) | `~/.grok/auth.json` |

`apply-inference-from-env.sh` writes the active key to `/etc/profile.d/grok-build-key.sh` (mode 600) and sets the default model (or router) in `config.toml`. The key is **never** written into `config.toml`. To make it available in every shell — not just login shells — the script also adds a guarded block to `/root/.bashrc` that sources the key file, and `001_onboot` places that same loader right after the wizard hook so the key is loaded into the live shell immediately after first-login setup. If a key isn't present in some shell, load it with `source /etc/profile.d/grok-build-key.sh`.

### Avoiding the OAuth browser prompt

Grok resolves credentials per model as `model.api_key` > `model.env_key` > active session token > `XAI_API_KEY`. Because the default model is a DigitalOcean entry with `env_key = "MODEL_ACCESS_KEY"`, launching `grok` with a key configured **never triggers the browser OIDC flow** — it uses the API key directly. The browser flow (`grok login`) is only relevant for the personal xAI-account path; on a headless droplet that has no browser, use the device-code helper `/opt/grok-login.sh` (RFC 8628) instead, which prints a URL + code to authorize on another device. The setup wizard and MOTD steer users to this helper.

### Bring your own provider

`/root/.grok/config.toml` ends with commented, ready-to-uncomment `[model.<alias>]` examples for **OpenAI**, **xAI**, and **Anthropic** (plus any OpenAI-compatible endpoint). To use one: uncomment the block, export the API key named by its `env_key` (e.g. `echo 'export OPENAI_API_KEY="sk-..."' >> /etc/profile.d/grok-build-key.sh`), then select it with `grok -m <alias>` or set it as the default under `[models]`. Run `grok inspect` to confirm what Grok loaded. The setup wizard's "skip" path also points users to this file.

## First Boot Behavior

1. Removes SSH force-logout (allows normal login)
2. Sources `/etc/environment` and runs `/opt/apply-inference-from-env.sh`
3. If `DO_MODEL_ACCESS_KEY` (or `XAI_API_KEY`) is set, configures Grok Build and skips the wizard
4. Otherwise hooks the setup wizard (`/opt/setup-grok-build.sh`) into `.bashrc` for first login, followed by a permanent key-loader block so the key reaches the live shell right after setup
5. Creates `/root/grok_build_info.txt` with getting-started instructions

### Environment Variables

| Variable | Description |
|----------|-------------|
| `DO_MODEL_ACCESS_KEY` | DigitalOcean model access key (default provider) |
| `DO_INFERENCE_MODEL` | Optional default model alias (default `gpt-5-5`) |
| `DO_INFERENCE_ROUTER` | Optional Intelligent Inference Router name (`router:<name>`) |
| `XAI_API_KEY` | xAI API key (`xai-...`) for the xAI native provider |

Set these as droplet environment variables at create time (written to `/etc/environment`) or in `/opt/grok-build.env`.

## First Login Experience

On first SSH login (when nothing was pre-applied), the wizard:

1. Prompts for a DigitalOcean model access key
2. Presents a numbered list of DigitalOcean models to pick the default from — or `R` to use an Intelligent Inference Router (and prompts for its name)
3. Saves the selection to `/opt/grok-build.env`, applies `MODEL_ACCESS_KEY`, and sets the default model/router in `config.toml`
4. Tests the connection to `https://inference.do-ai.run/v1/models`
5. If the model access key is skipped, offers xAI device-code sign-in or an xAI API key
6. Self-removes from `.bashrc` after a successful setup

The model menu aliases are kept in sync with `/root/.grok/config.toml`. The DigitalOcean catalog evolves; list the live set with `curl -s -H "Authorization: Bearer $MODEL_ACCESS_KEY" https://inference.do-ai.run/v1/models | jq -r '.data[].id'`.

## Version Pinning

The `application_version` variable in `template.json` pins the Grok Build version (passed to the official installer). To bump:

1. Edit `application_version` in `template.json` (e.g., `"0.2.52"`)
2. Rebuild the image

The latest stable version pointer is published at <https://x.ai/cli/stable>.

## License

This builder configuration follows the same license as the droplet-1-clicks repository. Grok Build is a proprietary xAI product; usage is subject to xAI's terms.
