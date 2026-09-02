# OpenClaw 1-Click Application

Deploy OpenClaw, a personal AI assistant you run on your own Droplet. Connect from the browser Control UI, wire up messaging channels (WhatsApp, Telegram, Slack, Discord, and more), and optionally use DigitalOcean Serverless Inference for models.

## What is OpenClaw?

OpenClaw is a self-hosted personal AI assistant and gateway. The Control UI and gateway run on your Droplet behind Caddy; you authenticate with a per-droplet gateway token and complete Control UI device pairing over SSH.

- **Self-hosted** – Config and workspace stay on your Droplet
- **Browser Control UI** – HTTPS on your droplet IP (Caddy reverse proxy + shortlived TLS)
- **Gateway token + pairing** – Token in the MOTD; Control UI device pairing required for remote access
- **DigitalOcean Serverless Inference** – Optional one-key setup for OpenAI-compatible models
- **Channels** – Configure Telegram, Discord, Slack, and more via env or CLI

## Key Features

- Always-on OpenClaw gateway with Docker sandbox support
- Caddy reverse proxy (ports 80/443 → gateway on `127.0.0.1:18789`)
- Optional DigitalOcean model access key configuration at first login
- Helper scripts for start/stop/restart/status/update and custom domain TLS
- Ubuntu 24.04 LTS with UFW and fail2ban

## System Requirements

OpenClaw runs the gateway on the host and uses Docker for sandboxes. Prefer at least 2 GB RAM.

| Use Case | RAM | CPU | Storage |
|----------|-----|-----|---------|
| Minimum | 2 GB | 1 vCPU | 50 GB |
| Recommended | 4 GB | 2 vCPU | 100 GB |

## Included System Components

- **Ubuntu 24.04 LTS**
- **OpenClaw** (version pinned in the image build)
- **Node.js 22** and **Docker**
- **Caddy** reverse proxy (ports 80/443 → gateway on localhost:18789)
- **UFW** and **fail2ban**
- Dedicated **`openclaw`** system user

## Getting Started

### 1. Deploy the Droplet

1. Select this 1-Click App from the DigitalOcean Marketplace
2. Choose a Droplet size (2 GB RAM minimum)
3. Add your SSH key
4. Optionally set droplet environment variables `MODEL_ACCESS_KEY` and `INFERENCE_MODEL`
5. Create the Droplet

### 2. Open the Control UI

1. Visit `https://your-droplet-ip`
2. Paste the **gateway token** shown in the SSH MOTD (also in `/opt/openclaw.env` as `OPENCLAW_GATEWAY_TOKEN`)
3. Complete Control UI pairing from SSH when prompted (or run `sudo /opt/openclaw-control-ui-pairing.sh`)

### 3. SSH (optional setup wizard)

```bash
ssh root@your-droplet-ip
```

If Serverless Inference was not passed at create time, the first-login wizard can configure a provider (DigitalOcean Serverless Inference, OpenAI, Anthropic, OpenRouter, or Codex). Create DigitalOcean model access keys at https://cloud.digitalocean.com/gen-ai/model-access-keys.

### 4. Configure channels and start working

1. Edit `/opt/openclaw.env` with channel tokens, or use `/opt/openclaw-cli.sh channels add`
2. Restart: `systemctl restart openclaw` or `/opt/restart-openclaw.sh`
3. Use the Control UI or `/opt/openclaw-tui.sh`

## Managing OpenClaw

| Action | Command |
|--------|---------|
| Start | `/opt/start-openclaw.sh` |
| Stop | `/opt/stop-openclaw.sh` |
| Restart | `/opt/restart-openclaw.sh` |
| Status | `/opt/status-openclaw.sh` |
| Update | `/opt/update-openclaw.sh` |
| Domain TLS | `/opt/setup-openclaw-domain.sh` |
| Re-run setup | `/etc/setup_wizard.sh` |
| Control UI pairing | `/opt/openclaw-control-ui-pairing.sh` |

systemd: `systemctl {start|stop|restart|status} openclaw`  
Logs: `journalctl -u openclaw -f`

### Configuration paths

- Env / secrets: `/opt/openclaw.env`
- Gateway token file: `/home/openclaw/.openclaw/gateway-token.txt`
- User config: `/home/openclaw/.openclaw/openclaw.json`
- Workspace: `/home/openclaw/.openclaw/workspace/`

### DigitalOcean Serverless Inference

When configured, OpenClaw uses the OpenAI-compatible Serverless Inference endpoint and a `digitalocean/<model-id>` primary model. You can change the model by re-running the setup wizard or editing config.

### Custom domain (HTTPS)

The droplet already serves HTTPS on the public IP via shortlived certificates. For a custom domain, point a DNS A record at the droplet, then:

```bash
sudo /opt/setup-openclaw-domain.sh
```

## Security notes

- OpenClaw runs as the `openclaw` user with Docker sandbox access
- Keep `OPENCLAW_GATEWAY_TOKEN` private; complete Control UI pairing so token alone is not enough
- Prefer a DigitalOcean Cloud Firewall restricting SSH (and optionally HTTP/HTTPS) to your IP
- For production, use a custom domain with TLS via `/opt/setup-openclaw-domain.sh`

## Additional Resources

- Docs: https://docs.clawd.bot/
- GitHub: https://github.com/openclaw/openclaw
- OpenAI vs Codex: https://github.com/openclaw/openclaw/blob/main/docs/providers/openai.md

## Support

For OpenClaw-specific issues: https://docs.clawd.bot/ and the upstream project.

For DigitalOcean Droplet issues: https://www.digitalocean.com/support
