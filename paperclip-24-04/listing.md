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
- Generated per-droplet admin email/password in MOTD (`/root/paperclip_admin_credentials`)
- **DO Inference via OpenCode adapter; no Claude/OpenAI key required when `MODEL_ACCESS_KEY` is set**
- First DigitalOcean OpenCode agent hired server-side on boot (company + agent ready after sign-in)
- Codex pointed at `https://inference.do-ai.run/v1` when no separate OpenAI key is set
- Helper scripts for start/stop/restart/status/update, inference apply, DO agent hire, and custom domain TLS
- Ubuntu 24.04 LTS with UFW and fail2ban

## System Requirements

Paperclip runs the Node.js server and local PostgreSQL on the host. Prefer at least 4 GB RAM for deployed Droplets. Packer image builds use an 8 GB Droplet (`s-4vcpu-8gb` in `template.json`) only during bake; that size is not the Marketplace runtime minimum.

| Use Case | RAM | CPU | Storage |
|----------|-----|-----|---------|
| Minimum | 4 GB | 2 vCPU | 50 GB |
| Recommended | 8 GB | 2–4 vCPU | 100 GB |

## Included System Components

- **Ubuntu 24.04 LTS**
- **Paperclip** `2026.1117.0` (managed CLI install, version pinned in the image build)
- **Node.js 24.22.3** at `/usr/bin/node` (pinned in the image build). Paperclip will not start on an older Node; first boot and updates reinstall the pinned NodeSource package when needed.
- **OpenCode CLI 1.19.6** at `/usr/local/bin/opencode` (version-pinned; digest verified from the GitHub release), required for DigitalOcean Inference agent verification.
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
2. Open `https://your-droplet-ip` and sign in with those credentials (also in `/root/paperclip_admin_credentials`)
3. When `MODEL_ACCESS_KEY` was set at create time, the organization and DigitalOcean agent are already present — no Claude/OpenAI connect step is required. Define a goal and start working.

If credentials were not generated, use the bootstrap invite in `/root/paperclip_bootstrap_invite.txt` instead.

### 3. SSH (optional setup wizard)

```bash
ssh root@your-droplet-ip
cat /root/paperclip_info.txt
```

If you passed `MODEL_ACCESS_KEY` as a droplet environment variable, first boot configures Serverless Inference, hires the DigitalOcean OpenCode agent, and skips the wizard. Otherwise the first-login wizard asks for a key. Create keys at https://cloud.digitalocean.com/model-studio/manage-keys (Inference > Manage > Create Model Access Key). `MODEL_ACCESS_KEY` is optional.

After the key is applied (at create time or via the wizard), agents use the OpenCode CLI with model `digitalocean/<model>` (or `digitalocean/router:<name>`). The first agent is named **DigitalOcean** and is created by `/opt/bootstrap-paperclip-do-agent.sh` — not by injecting scripts into the Paperclip UI.

If you see **Agent verification failed** / **Execution configuration check failed**, or the agent stays **Live** and **paused**, the host hello probe could not run OpenCode against Inference. Tasks stay queued until verification passes. On the Droplet:

```bash
# OpenCode CLI must exist for the paperclip service
/usr/local/bin/opencode --version
sudo /opt/ensure-paperclip-opencode.sh

# Inference env + OpenCode provider config, then restart Paperclip
grep -E '^(MODEL_ACCESS_KEY|PAPERCLIP_OPENCODE_PROVIDERS|OPENCODE_ALLOW_ALL_MODELS)=' /opt/paperclip.env
sudo /opt/apply-inference-from-env.sh
sudo systemctl daemon-reload
sudo systemctl restart paperclip
sudo /opt/bootstrap-paperclip-do-agent.sh

# Sanity-check the probe (as the paperclip user; MODEL_ACCESS_KEY from service env)
KEY="$(sed -n 's/^MODEL_ACCESS_KEY=//p' /opt/paperclip.env | tail -n1)"
sudo -u paperclip -H env PATH=/usr/bin:/bin:/usr/local/bin \
  "MODEL_ACCESS_KEY=${KEY}" \
  /usr/local/bin/opencode models | head
sudo -u paperclip -H env PATH=/usr/bin:/bin:/usr/local/bin \
  "MODEL_ACCESS_KEY=${KEY}" \
  /usr/local/bin/opencode run --format json --model digitalocean/<your-model> <<<'Respond with hello.'
```

Then open the agent → **Configuration** → set **Command** to `/usr/local/bin/opencode` if blank → **Harness / Runtime** → **Run test**, or click **Retry now**.

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
sudo /opt/bootstrap-paperclip-do-agent.sh

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
| Update (specific version) | `sudo /opt/update-paperclip.sh 2026.1117.0` |
| Rollback | `sudo /opt/update-paperclip.sh --rollback` |
| Domain TLS | `/opt/setup-paperclip-domain.sh` |
| Apply DO inference | `/opt/apply-inference-from-env.sh` |
| Hire DO agent | `/opt/bootstrap-paperclip-do-agent.sh` |
| Inference wizard | `/etc/setup_wizard.sh` |
| Doctor | `su - paperclip -c "paperclipai doctor"` |
| Logs | `journalctl -u paperclip -f` |

### Updating Paperclip

```bash
# Install the latest stable managed release
sudo /opt/update-paperclip.sh

# Install a specific version
sudo /opt/update-paperclip.sh 2026.1117.0

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
- Keep `/opt/paperclip.env` (`DATABASE_URL`, `ADMIN_EMAIL`, `MODEL_ACCESS_KEY`), `/root/paperclip_admin_credentials`, bootstrap invites, and `/home/paperclip/.paperclip` private
- `INITIAL_PASSWORD` is stored in `/root/paperclip_admin_credentials` and is **not** loaded into the `paperclip` systemd unit environment
- Prefer a Cloud Firewall that restricts SSH to your IP
- First admin is auto-claimed on loopback before Caddy exposes HTTPS; open signup is locked afterward (also on claim failure when a user already exists). On health timeout, Caddy stays stopped so signup is not public until repair.
- Local PostgreSQL listens on localhost only; authenticated/public mode does **not** use embedded Postgres

## Support / Docs

- Docs: https://docs.paperclip.ing
- GitHub: https://github.com/paperclipai/paperclip
- Website: https://paperclip.ing
- Installing guide: https://github.com/paperclipai/paperclip/blob/master/doc/INSTALLING.md
