# Exa MCP Server 1-Click Droplet Builder

Packer builder for a DigitalOcean Marketplace 1-Click image that installs [exa-mcp-server](https://www.npmjs.com/package/exa-mcp-server) on Ubuntu 24.04 LTS.

Exa MCP is served over **streamable HTTP** on `127.0.0.1:8081`, with **Caddy** terminating Let's Encrypt **shortlived** TLS on ports 80/443. Clients connect to `https://<droplet-ip>/mcp`.

## Directory Structure

```
exa-24-04/
├── template.json
├── README.md
├── listing.md
├── scripts/
│   └── 01-exa.sh
└── files/
    ├── etc/
    │   ├── caddy/Caddyfile.tmp
    │   ├── systemd/system/exa-mcp.service
    │   └── update-motd.d/99-one-click
    ├── opt/
    │   ├── setup-exa.sh
    │   ├── setup-exa-domain.sh
    │   ├── status-exa.sh
    │   ├── update-exa.sh
    │   ├── start-exa.sh
    │   ├── stop-exa.sh
    │   ├── restart-exa.sh
    │   ├── run-exa-mcp.sh
    │   └── run-exa-mcp-http.sh
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
- Caddy reverse proxy with shortlived TLS template
- systemd unit `exa-mcp` (streamable HTTP on port 8081)
- UFW: SSH + HTTP/HTTPS (`common/scripts/014-ufw-http.sh`)
- First-boot SSH unlock, Caddy IP cert, and first-login API key wizard

## Version bumps

1. Set `application_version` in `template.json` to the desired npm version (for example `3.2.1`).
2. Confirm that release still ships `smithery/shttp` (required for the HTTP service).
3. Rebuild the image.
4. On existing Droplets, run `/opt/update-exa.sh <version>`.

## First boot / first login

1. `001_onboot` removes SSH `ForceCommand`, installs the Caddyfile with the Droplet IP, and starts Caddy.
2. First SSH login prompts for `EXA_API_KEY`. Enter skips once (removes the `.bashrc` hook); re-run `/opt/setup-exa.sh` later.
3. Key is written to `/etc/exa/mcp.env` (mode `600`); `exa-mcp` is started.
4. Clients use `https://<droplet-ip>/mcp`. Optional custom domain: `/opt/setup-exa-domain.sh`.
