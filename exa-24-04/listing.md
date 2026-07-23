# Exa MCP Server 1-Click Application

Deploy [Exa](https://exa.ai/) MCP Server on Ubuntu 24.04. Exa gives AI agents web search and content retrieval over the Model Context Protocol (MCP). This Droplet pre-installs the official `exa-mcp-server` npm package for **stdio** use with clients such as Cursor, Claude Desktop, and Claude Code.

## What is Exa MCP?

Exa MCP exposes Exa search tools to MCP-compatible AI clients. The local npm package speaks **stdio** (your client starts the process). There is no public HTTP UI on this Droplet; only SSH is exposed.

## Key Features

- Pinned `exa-mcp-server` install (version from the image build)
- First-SSH API key setup (key never baked into the snapshot)
- `/opt/run-exa-mcp.sh` entrypoint for MCP client configs
- Helper scripts for status and updates
- UFW: SSH only

## System Requirements

| Use Case | RAM | CPU | Storage |
|----------|-----|-----|---------|
| Minimum | 1 GB | 1 vCPU | 25 GB |
| Recommended | 1 GB | 1 vCPU | 25 GB |

## Included System Components

- **Ubuntu 24.04 LTS** – Base operating system
- **Node.js 20** – Runtime (Nodesource)
- **exa-mcp-server** – Exa MCP stdio server (pinned at build time)
- **UFW Firewall** – SSH only (rate-limited)

## Getting Started

### 1. Deploy the Droplet

1. Select this 1-Click App from the DigitalOcean Marketplace
2. Choose a Droplet size (1 GB RAM minimum)
3. Add your SSH key for secure access
4. Create the Droplet

### 2. SSH In

```bash
ssh root@your-droplet-ip
```

On first login you are prompted for an Exa API key. Create one at https://dashboard.exa.ai/api-keys.

Press Enter to skip once (the login hook is removed). Configure later with:

```bash
/opt/setup-exa.sh
```

### 3. Point your MCP client at this Droplet

Use the Droplet as the host that runs the stdio server (for example SSH + local client config on the server, or any workflow where the client can execute `/opt/run-exa-mcp.sh`).

Configure the MCP client **on this Droplet** (or any host that can execute the entrypoint) to run:

```text
/opt/run-exa-mcp.sh
```

**Cursor** example (`~/.cursor/mcp.json` on the Droplet):

```json
{
  "mcpServers": {
    "exa": {
      "command": "/opt/run-exa-mcp.sh"
    }
  }
}
```

**Claude Code** example (on the Droplet):

```bash
claude mcp add --transport stdio exa -- /opt/run-exa-mcp.sh
```

Prefer Exa's hosted HTTP MCP instead? Use `https://mcp.exa.ai/mcp` in clients that support remote MCP (no Droplet required).

## Managing Exa MCP

Exa MCP is **not** a long-running systemd daemon. Your MCP client starts and stops the stdio process.

| Action | How |
|--------|-----|
| Start | MCP client runs `/opt/run-exa-mcp.sh` (or `exa-mcp-server` with `EXA_API_KEY` set) |
| Stop | Disconnect / quit the MCP client (ends the stdio process) |
| Restart | Restart the MCP client or reconnect the Exa server in the client |
| Status | `/opt/status-exa.sh` |
| Update | `/opt/update-exa.sh` (reinstalls pin) or `/opt/update-exa.sh 3.2.1` (bump) |
| Re-run setup | `/opt/setup-exa.sh --force` |

### Paths

- **API key**: `/etc/exa/mcp.env` (`EXA_API_KEY`)
- **Configured marker**: `/etc/exa/.configured`
- **Version pin**: `/etc/exa/version`
- **Client entrypoint**: `/opt/run-exa-mcp.sh`

## Security Notes

- UFW allows **SSH only**. Ports 80/443 are not opened.
- The API key is collected on first boot/login and is unique per Droplet.
- Do not commit or share `/etc/exa/mcp.env`.

## Support

- Exa MCP docs: https://docs.exa.ai/reference/exa-mcp
- Exa dashboard / API keys: https://dashboard.exa.ai/api-keys
