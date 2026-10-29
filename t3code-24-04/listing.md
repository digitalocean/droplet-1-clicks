# T3 Code 1-Click Application

Deploy [T3 Code](https://t3.codes/), an open-source control plane for coding agents. The droplet runs the T3 Code server behind Caddy, with the native provider CLIs installed, and can use DigitalOcean Serverless Inference.

## What is T3 Code?

T3 Code orchestrates coding-agent harnesses from a web, desktop, or mobile client. This image runs `t3 serve` on the droplet. You pair a browser or the mobile app to it, then sign in to the harnesses you already use.

## Key Features

- T3 Code server on loopback, published with Caddy and short-lived TLS
- Native provider CLIs installed for the `t3` user
- Optional DigitalOcean Serverless Inference provider
- Pairing link generated on first boot
- Helper scripts for start, stop, restart, status, update, and custom-domain TLS

## System Requirements

Prefer at least 4 GB RAM. The server, Claude Code, and T3's browser tooling need that headroom.

| Use Case | RAM | CPU | Storage |
|----------|-----|-----|---------|
| Minimum | 4 GB | 2 vCPU | 80 GB |
| Recommended | 8 GB | 4 vCPU | 160 GB |

## Included System Components

- Ubuntu 24.04 LTS
- T3 Code current stable release, and the provider CLIs that release marks compatible
- Node.js 22 (≥22.23.4, CVE-2026-111497)
- Caddy reverse proxy (ports 80/443 to 127.0.0.1:3773)
- UFW and fail2ban
- Dedicated `t3` user and `/home/t3/workspace`

### Native providers

Versions are chosen when the image is built, from that T3 Code release's compatibility ranges. Sign in as user `t3`.

| Provider | Sign in |
|----------|---------|
| Claude Code | `runuser -u t3 -- bash -lc 'claude auth login'` |
| Codex | `runuser -u t3 -- bash -lc 'codex login'` |
| Cursor Agent | `runuser -u t3 -- bash -lc 'agent login'` |
| Grok Build | `runuser -u t3 -- bash -lc 'grok login'` |
| OpenCode | `runuser -u t3 -- bash -lc 'opencode auth login'` |
| Antigravity | Settings, then Providers, in the web UI |
| Pi | `runuser -u t3 -- bash -lc 'pi'` then `/login` |
| Muse Code | `runuser -u t3 -- bash -lc 'muse login'` |
| fx | `runuser -u t3 -- bash -lc 'fx login'` |

Muse Code's official installer does not accept a version pin. The image installs whatever the stable channel published when the snapshot was built.

Sign in as `t3`. A login created as root is invisible to the server.

## Getting Started

### 1. Deploy the Droplet

1. Select this 1-Click from the DigitalOcean Marketplace
2. Choose a droplet with at least 4 GB RAM
3. Add your SSH key
4. Optionally set `MODEL_ACCESS_KEY`, `INFERENCE_MODEL`, and `DO_INFERENCE_ROUTER`
5. Create the droplet

### 2. Pair a client

1. SSH in and read `/root/.t3code-pairing.txt`, or the login MOTD
2. Open that link in a browser, the desktop app, or the mobile app
3. The link is valid for 24 hours. Create another with `/opt/create-t3code-pairing.sh`

The web UI is `https://your-droplet-ip`.

### 3. Choose a provider

Sign in to any installed harness with the commands above, then enable or refresh it under Settings, then Providers.

To use DigitalOcean Serverless Inference, either pass `MODEL_ACCESS_KEY` at create time or run `/etc/setup_wizard.sh` on first login. Create a key at https://cloud.digitalocean.com/model-studio/manage-keys. In T3 Code, select the **DigitalOcean Inference** provider and its model.

### 4. Work

Put projects in `/home/t3/workspace` and start a thread.

## Managing T3 Code

| Action | Command |
|--------|---------|
| Start | `/opt/start-t3code.sh` |
| Stop | `/opt/stop-t3code.sh` |
| Restart | `/opt/restart-t3code.sh` |
| Status | `/opt/status-t3code.sh` |
| Update T3 Code | `sudo /opt/update-t3code.sh` |
| Domain TLS | `/opt/setup-t3code-domain.sh` |
| New pairing link | `/opt/create-t3code-pairing.sh` |
| Inference setup | `/etc/setup_wizard.sh` |

systemd: `systemctl {start|stop|restart|status} t3code`  
Logs: `journalctl -u t3code -f`

`/opt/update-t3code.sh` updates the T3 Code server only. Provider CLIs stay on the versions installed in the image until you update them with their own installers.

### Configuration paths

- Service env: `/opt/t3code.env` (no model key; loaded by systemd)
- Inference secrets: `/opt/t3code-inference.env`
- Pairing link: `/root/.t3code-pairing.txt`
- T3 home: `/home/t3/.t3`
- Provider settings: `/home/t3/.t3/userdata/settings.json`
- Inference provider settings: `/home/t3/.claude-digitalocean`
- Getting started: `/root/t3code_info.txt`
- Workspace: `/home/t3/workspace`

### DigitalOcean Serverless Inference

When configured, the DigitalOcean Inference provider uses:

- Base URL: `https://inference.do-ai.run` (Claude calls `/v1/messages`)
- Credential: your model access key, read by Claude Code's `apiKeyHelper` (`printenv MODEL_ACCESS_KEY`). The key is set only on this provider instance. `ANTHROPIC_API_KEY` and `ANTHROPIC_AUTH_TOKEN` are left unset.
- Model: the catalog id chosen at setup (Claude-family ids are preferred), or `router:<name>` when `DO_INFERENCE_ROUTER` is set

### Custom domain

Point a DNS A record at the droplet, then:

```bash
sudo /opt/setup-t3code-domain.sh
sudo /opt/create-t3code-pairing.sh https://your.domain
```
