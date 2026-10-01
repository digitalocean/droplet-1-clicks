# QM 1-Click Application

Deploy [QM](https://github.com/yc-software/qm), an open-source (MIT) multiplayer agent harness: each employee gets an isolated agent workspace (memory, files, permissions, a sandbox) that can also collaborate with teammates through Slack channels, group chats, and shared projects.

## What is QM?

QM is a self-hosted control plane for AI coding/ops agents. It runs a web UI, an admin console, and a sign-in portal, backed by Postgres, and hands each agent turn off to an isolated sandbox so agent-run code never touches this droplet directly.

- **Self-hosted control plane** – Web UI, admin, and sign-in stay on your droplet
- **Isolated agent sandboxes** – Every agent turn runs in an external e2b sandbox, not on this box
- **Single admin, no domain required** – Password sign-in out of the box over HTTPS (a Let's Encrypt certificate for the bare droplet IP — no DNS needed); add email/SSO later
- **Bundled Postgres** – No managed database to provision for a first look

## Key Features

- Generated admin password and signing secrets, shown once in the SSH MOTD
- Interactive setup wizard: choose Anthropic or OpenAI as the model provider, plus an e2b key for agent sandboxes
- Helper scripts for start/stop/restart/status/update
- Ubuntu 24.04 LTS with UFW and fail2ban

## System Requirements

| Use Case | RAM | CPU | Storage |
|----------|-----|-----|---------|
| Minimum | 8 GB | 4 vCPU | 80 GB |

The agent sandboxes themselves run on e2b, not on this droplet — the size above covers Postgres plus QM's core/web-ui/portal services.

## Included System Components

- **Ubuntu 24.04 LTS**
- **QM** (`ghcr.io/yc-software/qm/{core,web-ui,portal}`, release v0.1.13)
- **Postgres 16** sidecar
- **Caddy** (HTTPS on the droplet's public IP)
- **UFW** and **fail2ban**

## Getting Started

### 1. Deploy the Droplet

1. Select this 1-Click App from the DigitalOcean Marketplace
2. Choose a Droplet size (8 GB RAM minimum recommended)
3. Add your SSH key
4. Optionally set droplet environment variables `ADMIN_EMAIL`, one of `ANTHROPIC_API_KEY`/`OPENAI_API_KEY` (optionally with `MODEL_PROVIDER` to disambiguate), and `E2B_API_KEY` (and optionally `ADMIN_PASSWORD`) to skip the interactive wizard
5. Create the Droplet

### 2. Finish setup over SSH (unless you set the environment variables above)

```bash
ssh root@your-droplet-ip
```

The setup wizard runs automatically on first login and asks for your admin email, a password, your choice of model provider ([Anthropic](https://console.anthropic.com/settings/keys) or [OpenAI](https://platform.openai.com/api-keys)) with its API key, and an [e2b API key](https://e2b.dev).

### 3. Open the dashboard

Visit `https://your-droplet-ip` and sign in with the email/password from setup. Your browser will likely warn on first visit — this droplet uses Let's Encrypt's short-lived certificate program for bare IP addresses, which isn't yet in every browser's trust store; the connection is still genuinely encrypted. QM's sign-in flow requires HTTPS (or `localhost`) and refuses to work over plain `http://`, so don't turn this off.

## Managing QM

| Action | Command |
|--------|---------|
| Start | `/opt/start-qm.sh` |
| Stop | `/opt/stop-qm.sh` |
| Restart | `/opt/restart-qm.sh` |
| Status | `/opt/status-qm.sh` |
| Update | `/opt/update-qm.sh` |
| Re-run setup | `/etc/setup_wizard.sh --force` |
| Logs | `docker compose -f /opt/qm/compose.yml logs -f` |

### Configuration paths

- Env / secrets: `/opt/qm/.env` (symlink `/opt/qm.env`)
- Compose stack: `/opt/qm`
- Getting started: `/root/qm_info.txt`

## Security notes

- Portal is served over **HTTPS** via Caddy on the droplet's public IP, using Let's Encrypt's short-lived certificate program for bare IPs (no domain needed). Expect a browser warning on first visit until that program is more widely trusted — the connection is still encrypted.
- Only `portal`'s port is reachable from Caddy (bound to loopback in the compose network); `core`, `web-ui`, and Postgres stay entirely internal. Prefer a DigitalOcean Cloud Firewall restricting SSH (and optionally HTTP/HTTPS) to your IP.
- Keep every value in `/opt/qm/.env` private — it holds the signing secrets, the admin password hash, and both API keys.

## Additional Resources

- GitHub: https://github.com/yc-software/qm
- QM documentation: https://github.com/yc-software/qm/tree/main/docs
- Report an issue upstream: https://github.com/yc-software/qm/issues
