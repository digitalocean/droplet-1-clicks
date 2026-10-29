# QM 1-Click Application

Deploy [QM](https://github.com/yc-software/qm), an open-source (MIT) multiplayer agent harness: each employee gets an isolated agent workspace (memory, files, permissions, a sandbox) that can also collaborate with teammates through Slack channels, group chats, and shared projects.

## What is QM?

QM is a self-hosted control plane for AI coding/ops agents. It runs a web UI, an admin console, and a sign-in portal, backed by Postgres, and hands each agent turn off to an isolated sandbox so agent-run code never touches this droplet directly.

- **Self-hosted control plane** – Web UI, admin, and sign-in stay on your droplet
- **Isolated agent sandboxes** – Every agent turn runs in an external sandbox, not on this box — [DigitalOcean Managed Agents](https://github.com/nkurraDO/qm) or e2b, your choice
- **Single admin, no domain required** – Password sign-in out of the box over HTTPS (a Let's Encrypt certificate for the bare droplet IP — no DNS needed); add email/SSO later
- **Bundled Postgres** – No managed database to provision for a first look, or attach a DigitalOcean Managed Database at creation time and QM switches to it automatically (local Postgres turns off)

## Key Features

- Generated admin password and signing secrets, shown once in the SSH MOTD
- Interactive setup wizard: choose DigitalOcean Serverless Inference, Anthropic, or OpenAI as the model provider, plus DigitalOcean Managed Agents or e2b for agent sandboxes (each question auto-skipped independently if DigitalOcean's own internal automation already provisioned that credential on this droplet)
- Helper scripts for start/stop/restart/status/update
- Ubuntu 24.04 LTS with UFW and fail2ban

## System Requirements

| Use Case | RAM | CPU | Storage |
|----------|-----|-----|---------|
| Minimum | 8 GB | 4 vCPU | 80 GB |

The agent sandboxes themselves run on DigitalOcean Managed Agents or e2b, not on this droplet — the size above covers Postgres plus QM's core/web-ui/portal services.

## Included System Components

- **Ubuntu 24.04 LTS**
- **QM** `web-ui`, `portal` (`ghcr.io/yc-software/qm/{web-ui,portal}`, release v0.1.13); `core` built from the DigitalOcean Managed Agents sandbox-backend fork
- **Postgres 16** sidecar (or an attached DigitalOcean Managed Database — see above)
- **Docker-in-Docker sidecar** — an isolated Docker daemon for QM's app-publishing feature
- **Caddy** (HTTPS on the droplet's public IP)
- **UFW** and **fail2ban**

## Getting Started

### 1. Deploy the Droplet

1. Select this 1-Click App from the DigitalOcean Marketplace
2. Choose a Droplet size (8 GB RAM minimum recommended)
3. Add your SSH key
4. Optionally set droplet environment variables `ADMIN_EMAIL`, one of `DO_SERVERLESS_INFERENCE_API_KEY`/`ANTHROPIC_API_KEY`/`OPENAI_API_KEY` (optionally with `MODEL_PROVIDER` to disambiguate), and one of `DO_AGENTS_API_TOKEN`/`E2B_API_KEY` (optionally with `SANDBOX_BACKEND` to disambiguate; and optionally `ADMIN_PASSWORD`) to skip the interactive wizard
5. Create the Droplet

### 2. Finish setup over SSH (unless you set the environment variables above)

```bash
ssh root@your-droplet-ip
```

The setup wizard runs automatically on first login and asks for your admin email, a password, your choice of model provider ([DigitalOcean Serverless Inference](https://cloud.digitalocean.com/model-studio/manage-keys) — the default, using the `deepseek-v4.1-flash` model, registered automatically, no Anthropic/OpenAI key needed — [Anthropic](https://console.anthropic.com/settings/keys), or [OpenAI](https://platform.openai.com/api-keys)) with its key, and your choice of sandbox backend ([DigitalOcean Managed Agents](https://cloud.digitalocean.com/account/api/tokens) — the default, a standard DO personal access token, nothing else to set up — or [e2b](https://e2b.dev)) with its credential.

### 3. Open the dashboard

Visit `https://your-droplet-ip` and sign in with the email/password from setup. Your browser will likely warn on first visit — this droplet uses Let's Encrypt's short-lived certificate program for bare IP addresses, which isn't yet in every browser's trust store; the connection is still genuinely encrypted. QM's sign-in flow requires HTTPS (or `localhost`) and refuses to work over plain `http://`, so don't turn this off.

## Managing QM

| Action | Command |
|--------|---------|
| Start | `/srv/qm/start-qm.sh` |
| Stop | `/srv/qm/stop-qm.sh` |
| Restart | `/srv/qm/restart-qm.sh` |
| Status | `/srv/qm/status-qm.sh` |
| Update | `/srv/qm/update-qm.sh` |
| Re-run setup | `/etc/setup_wizard.sh --force` |
| Logs | `docker compose -f /srv/qm/compose.yml logs -f` |

### Configuration paths

- Env / secrets: `/srv/qm/.env` (symlink `/srv/qm.env`)
- Compose stack: `/srv/qm`
- Getting started: `/root/qm_info.txt`

## Security notes

- Portal is served over **HTTPS** via Caddy on the droplet's public IP, using Let's Encrypt's short-lived certificate program for bare IPs (no domain needed). Expect a browser warning on first visit until that program is more widely trusted — the connection is still encrypted.
- Only `portal`'s port is reachable from Caddy (bound to loopback in the compose network); `core`, `web-ui`, and Postgres stay entirely internal. Prefer a DigitalOcean Cloud Firewall restricting SSH (and optionally HTTP/HTTPS) to your IP.
- Keep every value in `/srv/qm/.env` private — it holds the signing secrets, the admin password hash, and your model-provider and sandbox-backend credentials.
- A dedicated, isolated Docker-in-Docker container (`qm-dind`) runs QM's "publish a web app" feature, kept separate from the droplet's own Docker daemon — not the host's own `docker.sock` — though it does run `privileged`, the access level a nested Docker daemon needs to operate at all.

## Additional Resources

- GitHub: https://github.com/yc-software/qm
- QM documentation: https://github.com/yc-software/qm/tree/main/docs
- Report an issue upstream: https://github.com/yc-software/qm/issues
