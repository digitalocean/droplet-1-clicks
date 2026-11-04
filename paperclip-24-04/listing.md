# Paperclip 1-Click Application

Deploy Paperclip, the open-source control plane for orchestrating teams of AI agents. Define company goals, hire agents (OpenClaw, Claude Code, Codex, Cursor, and more), set budgets, and govern work from one dashboard.

## What is Paperclip?

Paperclip looks like a task manager. Under the hood it provides org charts, budgets, governance, goal alignment, heartbeats, and agent coordination.

- **Self-hosted** – Instance data stays on your Droplet under `/home/paperclip/.paperclip`
- **Browser dashboard** – HTTPS on your droplet IP (Caddy reverse proxy + shortlived TLS)
- **Authenticated / public** – Login required; first-admin email/password shown in SSH MOTD
- **Bring your own agents** – Wire OpenClaw, Claude Code, Codex, Cursor, HTTP bots, and more
- **Cost control** – Budgets and usage tracking to stop runaway spend

## Key Features

- Always-on Paperclip server with local PostgreSQL (`DATABASE_URL`)
- Caddy reverse proxy (ports 80/443 → loopback `:3100`) with shortlived TLS by IP
- Generated admin email/password in MOTD
- Optional DigitalOcean Serverless Inference (`MODEL_ACCESS_KEY`, live model list, Intelligent Inference Router)
- Onboarding "Connect a model" offers DigitalOcean Inference when `MODEL_ACCESS_KEY` is set, and hires OpenCode on `digitalocean/<model>`
- Codex pointed at `https://inference.do-ai.run/v1` when no separate OpenAI key is set
- Helper scripts for start/stop/restart/status/update, inference apply, and custom domain TLS
- Ubuntu 24.04 LTS with UFW and fail2ban

## System Requirements

Paperclip runs the Node.js server and local PostgreSQL on the host. Prefer at least 4 GB RAM.

| Use Case | RAM | CPU | Storage |
|----------|-----|-----|---------|
| Minimum | 4 GB | 2 vCPU | 50 GB |
| Recommended | 8 GB | 2–4 vCPU | 100 GB |

## Included System Components

- **Ubuntu 24.04 LTS**
- **Paperclip** `2026.1023.0` (managed CLI install, version pinned in the image build)
- **Node.js 24.22.1 or later** at `/usr/bin/node`. Paperclip will not start on an older Node, and first boot and updates install a newer NodeSource 24.x package when needed.
- **OpenCode CLI** at `/usr/local/bin/opencode`, required for DigitalOcean Inference agent verification.
- **PostgreSQL** (local; required for authenticated/public deployments)
- **Caddy** reverse proxy (ports 80/443 → `127.0.0.1:3100`)
- **UFW** and **fail2ban**
- Dedicated **`paperclip`** system user

## Getting Started

### 1. Deploy the Droplet

1. Select this 1-Click App from the DigitalOcean Marketplace
2. Choose a Droplet size (4 GB RAM minimum)
3. Add your SSH key
4. Optionally set droplet environment variables `MODEL_ACCESS_KEY`, `INFERENCE_MODEL`, and `DO_INFERENCE_ROUTER` (or `OPENAI_API_KEY` / `ANTHROPIC_API_KEY`)
5. Create the Droplet

### 2. Sign in (first admin)

1. SSH in (or read the MOTD) and note **Email** / **Password**
2. Open `https://your-droplet-ip` and sign in with those credentials (also in `/opt/paperclip.env` as `ADMIN_EMAIL` / `INITIAL_PASSWORD`)
3. Create a company, hire agents, and define a goal

If credentials were not generated, use the bootstrap invite in `/root/paperclip_bootstrap_invite.txt` instead.

### 3. SSH (optional setup wizard)

```bash
ssh root@your-droplet-ip
cat /root/paperclip_info.txt
```

If you passed `MODEL_ACCESS_KEY` as a droplet environment variable, first boot configures Serverless Inference and skips the wizard. Otherwise the first-login wizard asks for a key. Create keys at https://cloud.digitalocean.com/model-studio/manage-keys (Inference > Manage > Create Model Access Key). `MODEL_ACCESS_KEY` is optional.

After the key is applied, the onboarding "Connect a model" step shows DigitalOcean Inference next to Claude and OpenAI. Choosing it hires the agent on OpenCode with `digitalocean/<model>` (or `digitalocean/router:<name>`) and does not ask for a subscription or a pasted key.

Codex can still use the raw model id with `OPENAI_BASE_URL=https://inference.do-ai.run/v1` when you did not set a separate `OPENAI_API_KEY`.

Claude stays on `ANTHROPIC_API_KEY`. DigitalOcean Inference is an OpenAI-compatible endpoint.

If the invite was not generated, run:

```bash
su - paperclip -c "paperclipai auth bootstrap-ceo --base-url https://your-droplet-ip"
```

### 4. Add provider keys (optional)

```bash
# DigitalOcean Serverless Inference (preferred on Marketplace)
sudo /etc/setup_wizard.sh
# or:
sudo nano /opt/paperclip.env   # MODEL_ACCESS_KEY=...
sudo /opt/apply-inference-from-env.sh
# Then the onboarding Connect step offers DigitalOcean Inference.

# Or other providers:
sudo nano /opt/paperclip.env
# add OPENAI_API_KEY=... and/or ANTHROPIC_API_KEY=...
sudo systemctl restart paperclip
```

## Managing Paperclip

| Action | Command |
|--------|---------|
| Start | `/opt/start-paperclip.sh` |
| Stop | `/opt/stop-paperclip.sh` |
| Restart | `/opt/restart-paperclip.sh` |
| Status | `/opt/status-paperclip.sh` |
| Update (latest) | `sudo /opt/update-paperclip.sh` |
| Update (specific version) | `sudo /opt/update-paperclip.sh 2026.1023.0` |
| Rollback | `sudo /opt/update-paperclip.sh --rollback` |
| Domain TLS | `/opt/setup-paperclip-domain.sh` |
| Apply DO inference | `/opt/apply-inference-from-env.sh` |
| Inference wizard | `/etc/setup_wizard.sh` |
| Doctor | `su - paperclip -c "paperclipai doctor"` |
| Logs | `journalctl -u paperclip -f` |

### Updating Paperclip

```bash
# Install the latest stable managed release
sudo /opt/update-paperclip.sh

# Install a specific version
sudo /opt/update-paperclip.sh 2026.1023.0

# Roll back to the previous managed CLI payload
sudo /opt/update-paperclip.sh --rollback
```

### Custom domain

HTTPS already works on the droplet IP via Caddy shortlived certificates. For a custom domain:

1. Point DNS A/AAAA records at the droplet
2. Run `sudo /opt/setup-paperclip-domain.sh`
3. Re-issue the bootstrap invite if you still need first-admin setup with the new URL

## Security Notes

- Paperclip binds to `127.0.0.1:3100`; only Caddy exposes 80/443
- Keep `/opt/paperclip.env` (including `DATABASE_URL`, `ADMIN_EMAIL`, `INITIAL_PASSWORD`), bootstrap invites, and `/home/paperclip/.paperclip` private
- Prefer a Cloud Firewall that restricts SSH to your IP
- First admin is auto-claimed on boot; open signup is locked afterward
- Local PostgreSQL listens on localhost only; authenticated/public mode does **not** use embedded Postgres

## Support / Docs

- GitHub: https://github.com/paperclipai/paperclip
- Website: https://paperclip.ing
- Installing guide: https://github.com/paperclipai/paperclip/blob/master/doc/INSTALLING.md
