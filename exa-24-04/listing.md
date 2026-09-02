# Exa MCP Server 1-Click Application

Deploy [Exa](https://exa.ai/) MCP Server on Ubuntu 24.04. Exa gives AI agents web search and content retrieval over the Model Context Protocol (MCP). This Droplet pre-installs the official `exa-mcp-server` npm package and serves it over **HTTPS** with Caddy (Let's Encrypt shortlived TLS) plus a Droplet **Bearer access token**.

## What is Exa MCP?

Exa MCP exposes Exa search tools to MCP-compatible AI clients. This image terminates TLS with Caddy on ports 80/443 so clients can connect to `https://<droplet-ip>/mcp` with an `Authorization: Bearer` header.

## Key Features

- Pinned `exa-mcp-server` install (version from the image build)
- HTTPS via Caddy with shortlived Let's Encrypt TLS (works with the Droplet IP)
- Per-Droplet Bearer access token (required on MCP requests; rotatable)
- First-SSH Exa API key setup (key never baked into the snapshot; stays server-side)
- Helper scripts for start/stop/restart/status/update, domain TLS, and token rotation
- UFW: SSH + HTTP/HTTPS only

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

Use the HTTPS endpoint with the Droplet access token from `/root/exa_access_token.txt`:

```text
https://your-droplet-ip/mcp
Authorization: Bearer <access-token>
```

**Cursor** example (`~/.cursor/mcp.json`):

```json
{
  "mcpServers": {
    "exa": {
      "url": "https://your-droplet-ip/mcp",
      "headers": {
        "Authorization": "Bearer <access-token>"
      }
    }
  }
}
```

**Claude Code** example:

```bash
claude mcp add --transport http exa https://your-droplet-ip/mcp \
  --header "Authorization: Bearer <access-token>"
```

Optional: for local stdio on the Droplet itself, use `/opt/run-exa-mcp.sh`.

## Managing Exa MCP

| Action | How |
|--------|-----|
| Start | `/opt/start-exa.sh` or `systemctl start exa-mcp` |
| Stop | `/opt/stop-exa.sh` or `systemctl stop exa-mcp` |
| Restart | `/opt/restart-exa.sh` or `systemctl restart exa-mcp` |
| Status | `/opt/status-exa.sh` |
| Update | `/opt/update-exa.sh` (reinstalls pin) or `/opt/update-exa.sh 3.2.1` (bump). Target version must ship `smithery/shttp`. |
| Custom domain | `/opt/setup-exa-domain.sh` |
| Rotate access token | `/opt/rotate-exa-access-token.sh` |
| Re-run setup | `/opt/setup-exa.sh --force` |

### Paths

- **Exa API key**: `/etc/exa/mcp.env` (`EXA_API_KEY`)
- **Access token**: `/etc/exa/access.token` (also `/root/exa_access_token.txt`)
- **Configured marker**: `/etc/exa/.configured`
- **Version pin**: `/etc/exa/version`
- **HTTP runner**: `/opt/run-exa-mcp-http.sh`
- **Stdio entrypoint**: `/opt/run-exa-mcp.sh`

## Security Notes

- UFW allows **SSH, HTTP, and HTTPS** only. The MCP backend is not opened on the firewall; clients use HTTPS on 80/443.
- TLS is terminated by Caddy using Let's Encrypt shortlived certificates (IP or custom domain).
- A Droplet-generated **Bearer access token** is required on MCP requests (separate from the Exa API key).
- The Exa API key is collected on first login and stays on the server only.
- Rotate the access token with `/opt/rotate-exa-access-token.sh` if it may have leaked.
- Do not commit or share `/etc/exa/mcp.env` or `/etc/exa/access.token`. Prefer a Cloud Firewall when possible.

## Support

- Marketplace: https://marketplace.digitalocean.com/apps/exa
- Exa MCP docs: https://docs.exa.ai/reference/exa-mcp
- Exa dashboard / API keys: https://dashboard.exa.ai/api-keys
