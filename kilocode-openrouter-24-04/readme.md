# Kilo Code CLI (OpenRouter) 1-Click Droplet Builder

This directory contains the Packer builder configuration for creating a Kilo Code CLI 1-Click DigitalOcean Droplet image pre-wired for OpenRouter.

## Overview

Kilo Code CLI is an open-source AI coding agent that runs in the terminal. This builder creates an Ubuntu 24.04 LTS Droplet with Node.js LTS, Kilo Code CLI, and optional OpenRouter API key setup so the Droplet can run as an [OpenRouter Kilo Code agent](https://openrouter.ai/apps/kilo-code).

## Directory Structure

```text
kilocode-openrouter-24-04/
├── template.json
├── readme.md
├── listing.md
├── scripts/
│   └── 010-kilocode-openrouter.sh
└── files/
    ├── etc/
    │   └── update-motd.d/
    │       └── 99-one-click
    ├── opt/
    │   ├── apply-openrouter-token.sh
    │   ├── setup-kilocode-openrouter.sh
    │   ├── update-kilocode.sh
    │   └── kilocode-openrouter-first-login.bashrc
    ├── root/
    │   └── .config/kilo/
    │       ├── kilo.jsonc
    │       └── kilo.json
    └── var/
        └── lib/
            ├── cloud/scripts/per-instance/001_onboot
            └── digitalocean/
                ├── kilocode_info_with_token.txt
                └── kilocode_info_no_token.txt
```

## Build Requirements

1. **Packer**: Install from https://www.packer.io/downloads
2. **DigitalOcean API Token**: Generate with write access from https://cloud.digitalocean.com/account/api/tokens

```bash
export DIGITALOCEAN_API_TOKEN="your_api_token_here"
```

## Building the Image

```bash
packer validate kilocode-openrouter-24-04/template.json
make build-kilocode-openrouter-24-04
# or: packer build kilocode-openrouter-24-04/template.json
```

## What Gets Installed

- **Kilo Code CLI** from npm package `@kilocode/cli`
- **Node.js LTS** via the shared `common/scripts/010-nodejs.sh`
- **OpenRouter API key helper** for `OPENROUTER_API_KEY`
- **Git**, **curl**, **jq**, **unzip**, **UFW** and related system utilities

## First Boot Behavior

1. Removes the SSH force-logout rule
2. Sources `/etc/environment` and checks for `OPENROUTER_API_KEY`
3. If present, persists `OPENROUTER_API_KEY` and `KILO_PROVIDER_TYPE=openrouter` to `/etc/profile.d/` (shipped `/root/.config/kilo/kilo.jsonc` attribution config is left as-is)
4. Appends the shipped first-login bashrc snippet and starts `kilo` after setup
5. Copies `/root/kilocode_info.txt` from the shipped DigitalOcean info templates

## First Login Experience

The MOTD and setup helper ask for `OPENROUTER_API_KEY`. If the user does not have one, they can press Enter to skip setup. Kilo starts automatically after the first-login setup prompt in both cases.

To configure an OpenRouter API key later, export `OPENROUTER_API_KEY` and run `/opt/apply-openrouter-token.sh`. Keys are managed at https://openrouter.ai/keys. See the agent app page at https://openrouter.ai/apps/kilo-code.

## Version Pinning

The `application_version` variable in `template.json` pins the npm package version. To bump:

1. Check the latest release: `npm view @kilocode/cli version`
2. Edit `application_version` in `template.json`
3. Rebuild the image

## License

This builder configuration follows the same license as the droplet-1-clicks repository. Kilo Code licensing is provided by the upstream Kilo project. OpenRouter is a separate third-party service.
