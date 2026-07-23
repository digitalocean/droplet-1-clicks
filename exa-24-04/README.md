# Exa MCP Server 1-Click Droplet Builder

Packer builder for a DigitalOcean Marketplace 1-Click image that installs [exa-mcp-server](https://www.npmjs.com/package/exa-mcp-server) on Ubuntu 24.04 LTS.

Exa MCP uses **stdio** transport. This image does not expose an HTTP UI; UFW allows SSH only. Users set an API key on first SSH login and point MCP clients at `/opt/run-exa-mcp.sh`.

## Directory Structure

```
exa-24-04/
├── template.json
├── README.md
├── listing.md
├── scripts/
│   └── 01-exa.sh
└── files/
    ├── etc/update-motd.d/99-one-click
    ├── opt/
    │   ├── setup-exa.sh
    │   ├── status-exa.sh
    │   ├── update-exa.sh
    │   └── run-exa-mcp.sh
    └── var/lib/cloud/scripts/per-instance/001_onboot
```

## Prerequisites

1. Packer: https://www.packer.io/downloads
2. DigitalOcean API token with write access

```bash
export DIGITALOCEAN_API_TOKEN="your_api_token_here"
```

## Validate and build

```bash
packer init config/plugins.pkr.hcl
packer validate exa-24-04/template.json
make build-exa-24-04
# or: packer build exa-24-04/template.json
```

## What gets installed

- Node.js 20 (Nodesource)
- `exa-mcp-server` at the version in `application_version` (`template.json`)
- UFW limited to SSH
- First-boot SSH unlock + first-login API key wizard

## Version bumps

1. Set `application_version` in `template.json` to the desired npm version (for example `3.2.1`).
2. Rebuild the image.
3. On existing Droplets, run `/opt/update-exa.sh <version>`.

## First boot / first login

1. `001_onboot` removes SSH `ForceCommand` and hooks `/opt/setup-exa.sh` into root's `.bashrc` when not configured.
2. First SSH login prompts for `EXA_API_KEY`. Enter skips once (removes the `.bashrc` hook); re-run `/opt/setup-exa.sh` later.
3. Key is written to `/etc/exa/mcp.env` (mode `600`).
