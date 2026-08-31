# Exa MCP Server 1-Click Application

Deploy [Exa](https://exa.ai/) MCP Server on Ubuntu 24.04. Exa gives AI agents web search and content retrieval over the Model Context Protocol (MCP). This Droplet pre-installs the official `exa-mcp-server` npm package and serves it over **HTTPS** with Caddy (Let's Encrypt shortlived TLS).

## What is Exa MCP?

Exa MCP exposes Exa search tools to MCP-compatible AI clients. This image runs the streamable HTTP transport on localhost and terminates TLS with Caddy so clients can connect to `https://<droplet-ip>/mcp`.

## Key Features

- Pinned `exa-mcp-server` install (version from the image build)
- HTTPS via Caddy with shortlived Let's Encrypt TLS (works with the Droplet IP)
- First-SSH API key setup (key never baked into the snapshot)
- Helper scripts for start/stop/restart/status/update and custom domains
- UFW: SSH + HTTP/HTTPS only (MCP backend bound for local proxy use)

## System Requirements

| Use Case | RAM | CPU | Storage |
|----------|-----|-----|---------|
| Minimum | 1 GB | 1 vCPU | 25 GB |
| Recommended | 1 GB | 1 vCPU | 25 GB |

## Included System Components

- **Ubuntu 24.04 LTS** – Base operating system
- **Node.js 20** – Runtime (Nodesource)
- **exa-mcp-server** – Exa MCP server (pinned at build time)
- **Caddy** – Reverse proxy with shortlived Let's Encrypt TLS
- **UFW Firewall** – SSH + HTTP/HTTPS (rate-limited SSH)

## Getting Started

### 1. Deploy the Droplet

1. Select this 1-Click App from the DigitalOcean Marketplace
2. Choose a Droplet size (1 GB RAM minimum)
3. Add your SSH key for secure access
4. Create the Droplet

### 2. SSH In and set your API key

```bash
ssh root@your-droplet-ip
```

On first login you are prompted for an Exa API key. Create one at https://dashboard.exa.ai/api-keys.

Press Enter to skip once (the login hook is removed). Configure later with:

```bash
/opt/setup-exa.sh
```

### 3. Point your MCP client at this Droplet

Use the HTTPS endpoint:

```text
https://your-droplet-ip/mcp
```

**Cursor** example (`~/.cursor/mcp.json`):

```json
{
  "mcpServers": {
    "exa": {
      "url": "https://your-droplet-ip/mcp"
    }
  }
}
```

**Claude Code** example:

```bash
claude mcp add --transport http exa https://your-droplet-ip/mcp
```

Optional: for local stdio on the Droplet itself, use `/opt/run-exa-mcp.sh`.

## Managing Exa MCP

| Action | How |
|--------|-----|
| Start | `/opt/start-exa.sh` or `systemctl start exa-mcp` |
| Stop | `/opt/stop-exa.sh` or `systemctl stop exa-mcp` |
| Restart | `/opt/restart-exa.sh` or `systemctl restart exa-mcp` |
| Status | `/opt/status-exa.sh` |
| Update | `/opt/update-exa.sh` (reinstalls pin) or `/opt/update-exa.sh 3.2.1` (bump) |
| Custom domain | `/opt/setup-exa-domain.sh` |
| Re-run setup | `/opt/setup-exa.sh --force` |

### Paths

- **API key**: `/etc/exa/mcp.env` (`EXA_API_KEY`)
- **Configured marker**: `/etc/exa/.configured`
- **Version pin**: `/etc/exa/version`
- **HTTP runner**: `/opt/run-exa-mcp-http.sh`
- **Stdio entrypoint**: `/opt/run-exa-mcp.sh`

## Security Notes

- UFW allows **SSH, HTTP, and HTTPS** only. Port 8081 is not opened publicly; Caddy proxies to `127.0.0.1:8081`.
- TLS is terminated by Caddy using Let's Encrypt shortlived certificates (IP or custom domain).
- The API key is collected on first boot/login and is unique per Droplet.
- Do not commit or share `/etc/exa/mcp.env`. Prefer restricting access with a Cloud Firewall when possible.

## Support

- Exa MCP docs: https://docs.exa.ai/reference/exa-mcp
- Exa dashboard / API keys: https://dashboard.exa.ai/api-keys
