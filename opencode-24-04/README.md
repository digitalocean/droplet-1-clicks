# OpenCode 1-Click Droplet Builder

This directory contains the Packer builder configuration for creating an OpenCode 1-Click DigitalOcean Droplet image.

## Overview

OpenCode is an open-source AI coding agent that runs in the terminal. Users SSH into the droplet and run `opencode` to get AI-assisted coding directly in their shell. This builder creates a fully configured Ubuntu 24.04 LTS Droplet with OpenCode pre-installed.

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
    │   ├── update-opencode.sh      # Update to latest version
    │   └── opencode-version.sh    # Display installed version
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
- **Git**, **curl**, **jq**, **unzip** – utilities
- **UFW** – Firewall (SSH only, rate-limited)

OpenCode is installed to `/root/.opencode/bin/` and added to PATH via `/etc/profile.d/opencode.sh`.

## First Boot Behavior

1. Removes SSH force-logout (allows normal login)
2. Creates `/root/opencode_info.txt` with getting-started instructions
3. Creates `/root/.config/opencode/` config directory

## Version Pinning

The `application_version` variable in `template.json` pins the OpenCode version. To bump:

1. Edit `application_version` in `template.json` (e.g., `"1.2.6"`)
2. Rebuild the image

## License

This builder configuration follows the same license as the droplet-1-clicks repository. OpenCode is licensed under MIT.
