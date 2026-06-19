# Kilo Code CLI 1-Click Droplet Builder

This directory contains the Packer builder configuration for creating a Kilo Code CLI 1-Click DigitalOcean Droplet image.

## Overview

Kilo Code CLI is an open-source AI coding agent that runs in the terminal. Users SSH into the Droplet and run `kilo` to work on code with AI assistance. This builder creates an Ubuntu 24.04 LTS Droplet with Node.js LTS, Kilo Code CLI, and optional DigitalOcean model access key setup.

## Directory Structure

```text
kilocode-24-04/
├── template.json
├── readme.md
├── listing.md
├── scripts/
│   └── 010-kilocode.sh
└── files/
    ├── etc/
    │   └── update-motd.d/
    │       └── 99-one-click
    ├── opt/
    │   ├── apply-digitalocean-token.sh
    │   ├── setup-kilocode.sh
    │   └── update-kilocode.sh
    └── var/
        └── lib/
            └── cloud/
                └── scripts/
                    └── per-instance/
                        └── 001_onboot
```

## Build Requirements

1. **Packer**: Install from https://www.packer.io/downloads
2. **DigitalOcean API Token**: Generate with write access from https://cloud.digitalocean.com/account/api/tokens

```bash
export DIGITALOCEAN_API_TOKEN="your_api_token_here"
```

## Building the Image

```bash
packer validate kilocode-24-04/template.json
make build-kilocode-24-04
# or: packer build kilocode-24-04/template.json
```

## What Gets Installed

- **Kilo Code CLI** from npm package `@kilocode/cli`
- **Node.js LTS** via the shared `common/scripts/010-nodejs.sh`
- **DigitalOcean model access key helper** for `DIGITALOCEAN_ACCESS_TOKEN`
- **Git**, **curl**, **jq**, **unzip**, **UFW** and related system utilities

## First Boot Behavior

1. Removes the SSH force-logout rule
2. Sources `/etc/environment` and checks for `DIGITALOCEAN_ACCESS_TOKEN`
3. If present, persists it and `KILO_PROVIDER_TYPE=digitalocean` to root-only files for future shell sessions
4. Hooks first login to run `/opt/setup-kilocode.sh`, reload the saved token if present, and start `kilo`
5. Writes `/root/kilocode_info.txt` with token setup and first-login instructions

## First Login Experience

The MOTD and setup helper ask for `DIGITALOCEAN_ACCESS_TOKEN`. If the user does not have one, they can press Enter to skip setup. Kilo starts automatically after the first-login setup prompt in both cases.

To configure a DigitalOcean model access key later, export `DIGITALOCEAN_ACCESS_TOKEN` and run `/opt/apply-digitalocean-token.sh`. Model access keys are managed at https://cloud.digitalocean.com/model-studio/manage-keys.

## Version Pinning

The `application_version` variable in `template.json` pins the npm package version. To bump:

1. Check the latest release: `npm view @kilocode/cli version`
2. Edit `application_version` in `template.json`
3. Rebuild the image

## License

This builder configuration follows the same license as the droplet-1-clicks repository. Kilo Code licensing is provided by the upstream Kilo project.
