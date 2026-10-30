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
- Optional DigitalOcean Serverless Inference (`MODEL_ACCESS_KEY`, model list, Intelligent Inference Router)
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
- **Paperclip** `2026.916.1` (managed CLI install, version pinned in the image build)
- **Node.js 24**
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

If you passed `MODEL_ACCESS_KEY` as a droplet environment variable, the key is staged in `/opt/paperclip.env` (wizard skipped). Otherwise the first-login wizard can stage a key. Connect providers in the Paperclip UI after bootstrap. Create keys at https://cloud.digitalocean.com/model-studio/manage-keys (Inference > Manage > Create Model Access Key). `MODEL_ACCESS_KEY` is optional.

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
| Update (specific version) | `sudo /opt/update-paperclip.sh 2026.916.1` |
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
sudo /opt/update-paperclip.sh 2026.916.1

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
