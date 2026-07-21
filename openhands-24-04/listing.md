# OpenHands 1-Click Application

Deploy OpenHands Agent Canvas, an open-source self-hosted control center for AI coding agents and automations. Run agents on your Droplet, connect from the browser, and optionally use DigitalOcean Gradient AI for inference.

## What is OpenHands?

OpenHands is the open platform for cloud coding agents. Agent Canvas is the self-hosted developer control center: start conversations, run automations, and work with OpenHands or other ACP-compatible agents across local and remote backends.

- **Self-hosted** – Agents and settings stay on your Droplet
- **Browser UI** – Agent Canvas on your droplet IP (Caddy reverse proxy)
- **Public mode** – Protected by a generated API key (`LOCAL_BACKEND_API_KEY`)
- **DigitalOcean Gradient AI** – Optional one-key setup for OpenAI-compatible models
- **Workspace** – Projects under `/home/openhands/projects`

## Key Features

- Always-on agent backend for coding tasks and automations
- Web UI with API-key gate for internet-facing deployments
- Optional Gradient model access key configuration at first login
- Helper scripts for start/stop/restart/status/update and custom domain TLS
- Ubuntu 24.04 LTS with UFW and fail2ban

## System Requirements

OpenHands Agent Canvas runs the agent server on the host. Prefer at least 4 GB RAM.

| Use Case | RAM | CPU | Storage |
|----------|-----|-----|---------|
| Minimum (single user) | 4 GB | 2 vCPU | 50 GB |
| Recommended | 8 GB | 4 vCPU | 100 GB |

## Included System Components

- **Ubuntu 24.04 LTS**
- **OpenHands Agent Canvas** (version pinned in the image build)
- **Node.js 22** and **uv**
- **Caddy** reverse proxy (ports 80/443 → Agent Canvas on localhost:8000)
- **UFW** and **fail2ban**
- Dedicated **`openhands`** system user

## Getting Started

### 1. Deploy the Droplet

1. Select this 1-Click App from the DigitalOcean Marketplace
2. Choose a Droplet size (4 GB RAM minimum recommended)
3. Add your SSH key
4. Optionally set droplet environment variables `GRADIENT_KEY` and `GRADIENT_MODEL`
5. Create the Droplet

### 2. Open the Web UI

1. Visit `https://your-droplet-ip`
2. Paste the **API key** shown in the SSH MOTD (also in `/opt/openhands.env` as `LOCAL_BACKEND_API_KEY`)

### 3. SSH (optional setup wizard)

```bash
ssh root@your-droplet-ip
```

If Gradient was not passed at create time, the first-login wizard can configure a DigitalOcean Gradient model access key. Create keys at https://cloud.digitalocean.com/gen-ai/model-access-keys.

### 4. Configure LLM and start working

1. In the UI, open **Settings > LLM** (confirm Gradient settings or add another provider)
2. Place code under `/home/openhands/projects`
3. Start a conversation from the home screen

## Managing OpenHands

| Action | Command |
|--------|---------|
| Start | `/opt/start-openhands.sh` |
| Stop | `/opt/stop-openhands.sh` |
| Restart | `/opt/restart-openhands.sh` |
| Status | `/opt/status-openhands.sh` |
| Update | `/opt/update-openhands.sh` |
| Domain TLS | `/opt/setup-openhands-domain.sh` |
| Re-run setup | `/etc/setup_wizard.sh` |

systemd: `systemctl {start|stop|restart|status} openhands`  
Logs: `journalctl -u openhands -f`

### Configuration paths

- Env / secrets: `/opt/openhands.env`
- API key file: `/home/openhands/.openhands/api-key.txt`
- Settings: `/home/openhands/.openhands/`
- Getting started: `/root/openhands_info.txt`

### DigitalOcean Gradient

When configured, OpenHands uses the OpenAI-compatible Gradient endpoint:

- Base URL: `https://inference.do-ai.run/v1`
- Model form: `openai/<model-id>` (default `openai/minimax-m2.5`)

You can change the model in Settings > LLM or by re-running the setup wizard.

### Custom domain (HTTPS)

Point a DNS A record at the droplet, then:

```bash
sudo /opt/setup-openhands-domain.sh
```

## Security notes

- Agent Canvas runs as the `openhands` user and can read/write that user's filesystem and run commands in that context
- Keep `LOCAL_BACKEND_API_KEY` private; anyone with the key can use the agent
- Prefer a DigitalOcean Cloud Firewall restricting SSH (and optionally HTTP/HTTPS) to your IP
- For production, use a custom domain with TLS via `/opt/setup-openhands-domain.sh`

## Additional Resources

- Product: https://www.openhands.dev/
- Self-hosting: https://docs.openhands.dev/openhands/usage/agent-canvas/backend-setup/vm
- Docs: https://docs.openhands.dev/
- GitHub: https://github.com/OpenHands/agent-canvas

## Support

For OpenHands-specific issues: https://docs.openhands.dev/ and the OpenHands community Slack.

For DigitalOcean Droplet issues: https://www.digitalocean.com/support
