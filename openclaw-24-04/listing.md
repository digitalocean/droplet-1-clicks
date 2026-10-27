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

OpenClaw runs the gateway on the host and uses Docker for sandboxes. The Control UI (HTTPS by IP) and SSH TUI load the same Node gateway; **2 GB Droplets often freeze or thrash** under that load (worse after newer OpenClaw releases). Use **4 GB / 2 vCPU** or larger.

| Use Case | RAM | CPU | Storage |
|----------|-----|-----|---------|
| Minimum | 4 GB | 2 vCPU | 50 GB |
| Recommended | 8 GB | 4 vCPU | 100 GB |

## Included System Components

- **Ubuntu 24.04 LTS**
- **OpenClaw** `v2026.10.7` (version pinned in the image build)
- **Node.js 24** (≥**24.22.1**, remediates CVE-2026-111497) and **Docker**
- **Caddy** reverse proxy (ports 80/443 → gateway on localhost:18789)
- **UFW** and **fail2ban**
- Dedicated **`openclaw`** system user

## Getting Started

### 1. Deploy the Droplet

1. Select this 1-Click App from the DigitalOcean Marketplace
2. Choose a Droplet size (**4 GB / 2 vCPU minimum**; 8 GB recommended for TUI + Control UI + sandboxes)
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
| Update (latest) | `sudo /opt/update-openclaw.sh` |
| Domain TLS | `/opt/setup-openclaw-domain.sh` |
| Re-run setup | `/etc/setup_wizard.sh` |
| Control UI pairing | `/opt/openclaw-control-ui-pairing.sh` |

### Updating OpenClaw

```bash
# Install the latest release from npm
sudo /opt/update-openclaw.sh
```

The script installs `openclaw@latest` and updates `OPENCLAW_VERSION` in `/opt/openclaw.env` after a successful install. Prefer the SSH helper over the Control UI update button on this 1-Click image.

If the Control UI or CLI misbehaves after an update (including agent DB errors like `schema version N; run openclaw doctor --fix`), stop the gateway first so doctor can take exclusive SQLite maintenance, then repair. The 1-Click uses a root-owned custom `openclaw.service`, so doctor must use `OPENCLAW_SERVICE_REPAIR_POLICY=external`:

```bash
sudo systemctl stop openclaw
sudo -u openclaw -H env HOME=/home/openclaw OPENCLAW_SERVICE_REPAIR_POLICY=external \
  openclaw doctor --fix --yes --non-interactive
sudo systemctl start openclaw

# Optional: re-sync proxy/token settings; re-apply inference if models list is empty
sudo /opt/ensure-openclaw-ready.sh
sudo /opt/apply-inference-from-env.sh
```

`/opt/update-openclaw.sh` already stops the gateway, runs that doctor command (with `OPENCLAW_SERVICE_REPAIR_POLICY=external`), syncs gateway config, and only restarts OpenClaw if doctor succeeds. If doctor fails mid-upgrade, the gateway is left stopped on the newly installed package for manual repair.

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

## Troubleshooting

### Doctor: “Gateway service ownership or shutdown could not be verified”

The 1-Click gateway is a custom systemd unit (`openclaw.service`), not the CLI-managed installer unit. Always stop via `systemctl` and run doctor with `OPENCLAW_SERVICE_REPAIR_POLICY=external` (see commands above). `/opt/update-openclaw.sh` sets this automatically.

### Control UI or TUI freezes the Droplet

This usually means the Droplet is undersized (common on **2 GB / 1 vCPU**). Gateway + Docker + browser Control UI + SSH TUI need more RAM, especially on newer OpenClaw releases.

1. **Resize** to at least **4 GB / 2 vCPU** (8 GB recommended) in the DigitalOcean control panel, then reboot.
2. On a live Droplet, add swap immediately if it is missing:
   ```bash
   sudo /opt/ensure-openclaw-swap.sh
   ```
   First boot also creates a 2 GB swap file automatically. Swap reduces hard freezes but is not a substitute for enough RAM.

## Security notes

- OpenClaw runs as the `openclaw` user with Docker sandbox access
- Keep `OPENCLAW_GATEWAY_TOKEN` private; complete Control UI pairing so token alone is not enough
- Prefer a DigitalOcean Cloud Firewall restricting SSH (and optionally HTTP/HTTPS) to your IP
- For production, use a custom domain with TLS via `/opt/setup-openclaw-domain.sh`
- **Remediation for [CVE-2026-111497](https://nodejs.org/en/blog/vulnerability/october-2026-security-releases)** (Brotli RCE; internal trackers VULN-5695 / VULN-5716): ship / upgrade host Node.js to **≥24.22.1** (upstream also fixed 22.23.4 and 26.12.1). The VULN IDs are tracker labels only — the fix is the patched Node runtime. On an older droplet, `sudo /opt/update-openclaw.sh` upgrades Node when below the floor, refreshes the systemd unit PATH so `/usr/bin/node` wins over Homebrew, and restarts; or run `sudo apt-get update && sudo apt-get install -y nodejs && sudo systemctl restart openclaw`.

## Additional Resources

- Docs: https://docs.clawd.bot/
- GitHub: https://github.com/openclaw/openclaw
- OpenAI vs Codex: https://github.com/openclaw/openclaw/blob/main/docs/providers/openai.md

## Support

For OpenClaw-specific issues: https://docs.clawd.bot/ and the upstream project.

For DigitalOcean Droplet issues: https://www.digitalocean.com/support
