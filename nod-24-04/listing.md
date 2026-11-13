# Nod 1-Click Application

Deploy [Nod](https://github.com/n8n-io/nod), the open source personal agent from the team behind n8n. Nod runs on your Droplet with its own Linux workspace and Chromium browser, connects to the model you choose, and asks before it acts.

## What is Nod?

Nod is a self-hosted personal agent that works across Gmail, Calendar, Slack, Notion, and the web. Policy checks, Vault secrets, memory, and schedules run in the server — not only in the prompt.

- **Self-hosted** — Files, memory, and saved logins stay on your Droplet
- **Browser + workspace** — Docker containers give Nod its own computer
- **Your model** — DigitalOcean Serverless Inference, or OpenAI, Anthropic, Gemini, OpenRouter, and more
- **HTTPS by IP** — Caddy reverse proxy with shortlived Let's Encrypt TLS
- **Access token** — Per-droplet `NOD_AUTH_TOKEN` gates the web UI

## Key Features

- Always-on Nod server with PostgreSQL, browser, and workspace sandbox
- Optional DigitalOcean Serverless Inference via `MODEL_ACCESS_KEY` at create time or first-login wizard
- Caddy reverse proxy (ports 80/443 → Nod on `127.0.0.1:4310`)
- Helper scripts for start/stop/restart/status/update and custom domain TLS
- Ubuntu 24.04 LTS with UFW and fail2ban

## System Requirements

Nod's self-host stack recommends **2 vCPU, 8 GB RAM, and 50 GB disk** as a starting point. Simultaneous browser tasks need more capacity.

| Use Case | RAM | CPU | Storage |
|----------|-----|-----|---------|
| Minimum | 8 GB | 2 vCPU | 50 GB |
| Recommended | 16 GB | 4 vCPU | 100 GB |

## Included System Components

- **Ubuntu 24.04 LTS**
- **Nod** `0.7.2` (pinned `nod-v0.7.2` git tag; Docker self-host stack)
- **Docker Engine** 25+ with Compose v2
- **Caddy** reverse proxy (ports 80/443 → localhost:4310)
- **PostgreSQL 17** (inside Compose)
- **UFW** and **fail2ban**

## Getting Started

### 1. Deploy the Droplet

1. Select this 1-Click App from the DigitalOcean Marketplace
2. Choose a Droplet size (**8 GB / 2 vCPU minimum**)
3. Add your SSH key
4. Optionally set droplet environment variables `MODEL_ACCESS_KEY` and `INFERENCE_MODEL` (or `DO_INFERENCE_ROUTER`)
5. Create the Droplet (first boot generates secrets and starts Nod)

### 2. Open Nod

1. Visit `https://your-droplet-ip`
2. Paste the **access token** shown in the SSH MOTD (also `NOD_AUTH_TOKEN` in `/opt/nod/deployment/self-host/.env`)
3. If Serverless Inference was pre-configured, finish onboarding with that model; otherwise connect a provider in Models

### 3. SSH (optional)

```bash
ssh root@your-droplet-ip
```

If no `MODEL_ACCESS_KEY` was set at create time, the first-login wizard can configure DigitalOcean Serverless Inference. Create keys at https://cloud.digitalocean.com/gen-ai/model-access-keys.

Check status with `/opt/status-nod.sh`. Review secrets only when needed:

```bash
sudo grep '^NOD_AUTH_TOKEN=' /opt/nod/deployment/self-host/.env
```

## DigitalOcean Serverless Inference

Nod uses the OpenAI-compatible endpoint `https://inference.do-ai.run/v1`:

| Variable | Purpose |
|----------|---------|
| `MODEL_ACCESS_KEY` | Model access key (required for auto-config) |
| `INFERENCE_MODEL` | Model id from `GET https://inference.do-ai.run/v1/models` |
| `DO_INFERENCE_ROUTER` | Optional Intelligent Inference Router name → `router:<name>` |

```bash
sudo /opt/apply-inference-from-env.sh
sudo /opt/restart-nod.sh
# or interactive:
sudo /etc/setup_wizard.sh --force
```

Settings land in `/opt/nod/deployment/self-host/.env` as `LLM_PROVIDER=compatible`, `OPENAI_COMPATIBLE_*`, and `LLM_MODEL`.

## Managing Nod

| Action | Command |
|--------|---------|
| Start | `/opt/start-nod.sh` or `systemctl start nod` |
| Stop | `/opt/stop-nod.sh` or `systemctl stop nod` |
| Restart | `/opt/restart-nod.sh` or `systemctl restart nod` |
| Status | `/opt/status-nod.sh` |
| Logs | `/opt/nod-compose.sh logs -f` |
| Update | `sudo /opt/update-nod.sh` |
| Domain TLS | `sudo /opt/setup-nod-domain.sh` |

## Updates

```bash
sudo /opt/update-nod.sh            # latest nod-v* tag
sudo /opt/update-nod.sh nod-v0.7.2 # pin a specific tag
```

Back up `/opt/nod/deployment/self-host/.env` before upgrading — especially `NOD_VAULT_KEY`. The database alone cannot recover saved credentials without that key. Official backup helpers live under `/opt/nod/deployment/self-host/` (`backup.sh` / `restore.sh`).

## Custom Domain

HTTPS already works on the droplet IP. For a hostname:

1. Point DNS A record at the droplet
2. Run `sudo /opt/setup-nod-domain.sh`
3. Open `https://your-domain` and use the same access token

## Security Notes

- Nod binds to loopback; only Caddy is public on 80/443
- One server belongs to one person — the access token grants full control
- Keep workspace firewall settings from upstream Compose; they block cloud metadata from the sandbox
- Rotate or restrict SSH keys; use UFW as configured

## Support & Docs

- Self-host guide: https://nod.n8n.io/docs/deploy/self-host/
- Configuration: https://nod.n8n.io/docs/deploy/configuration/
- GitHub: https://github.com/n8n-io/nod
- Nod is a research preview from n8n GmbH (Apache-2.0)
