# OpenClaw OpenShell 1-Click

Deploy **OpenClaw** inside an **NVIDIA OpenShell** sandbox on a DigitalOcean Droplet. OpenClaw runs in an isolated sandbox with port 18789 forwarded; Caddy provides HTTPS (same configuration as the OpenClaw 1-Click).

## What's included

- Ubuntu 24.04 LTS
- Node.js 22, Docker, Caddy
- [NVIDIA OpenShell](https://github.com/NVIDIA/OpenShell) CLI
- OpenClaw (npm) and OpenShell sandbox `openclaw-sandbox` (forward 18789)
- Fail2ban, UFW (80, 443, SSH limited)

## Getting started

1. Deploy the Droplet from the Marketplace (OpenClaw OpenShell 1-Click).
2. SSH as root: `ssh root@your-droplet-ip`
3. On first login, the setup wizard will prompt for your **GradientAI API key** and **model** (e.g. Claude 4.5 Sonnet). Config is uploaded into the sandbox automatically.
4. Open the dashboard: `https://your-droplet-ip` (gateway token is in the MOTD and `/opt/openclaw.env`).

## Management

- **Restart sandbox**: `systemctl restart openclaw-sandbox` or `/opt/restart-openclaw-sandbox.sh`
- **Status**: `systemctl status openclaw-sandbox` or `/opt/status-openclaw-sandbox.sh`
- **Update**: `/opt/update-openclaw-sandbox.sh`
- **Logs**: `journalctl -u openclaw-sandbox -f`

## Custom domain and TLS

1. Point a DNS A record to your Droplet IP.
2. Run: `sudo /opt/setup-openclaw-domain.sh` and enter domain and optional email.
3. Caddy will obtain a Let's Encrypt certificate and proxy HTTPS to the sandbox (port 18789).

## Configuration

- **Env**: `/opt/openclaw.env` – gateway port, token (auto-generated on first boot).
- **OpenClaw config**: Managed by the setup wizard (GradientAI key and model); stored inside the sandbox at `/home/openclaw/.openclaw/openclaw.json`. To change later, edit a local json and run: `openshell sandbox upload openclaw-sandbox /path/to/openclaw.json /home/openclaw/.openclaw/openclaw.json`, then restart the sandbox.

## References

- [OpenClaw](https://github.com/openclaw/openclaw)
- [NVIDIA OpenShell](https://github.com/NVIDIA/OpenShell)
