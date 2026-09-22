# OmniRoute 1-Click Application

Deploy OmniRoute, a self-hosted AI gateway with a web dashboard and OpenAI-compatible API. Route requests across providers from one endpoint on your Droplet, with optional DigitalOcean Serverless Inference (including Intelligent Inference Router) as the preferred provider.

## What is OmniRoute?

OmniRoute is an open-source AI gateway: connect providers once, then point Claude Code, Codex, Cursor, OpenCode, and other tools at a single local/HTTPS endpoint with smart routing, combos, and a live model catalog.

- **Self-hosted** – Gateway, dashboard, and data stay on your Droplet
- **Browser dashboard** – HTTPS on your droplet IP (Caddy reverse proxy)
- **OpenAI-compatible API** – `https://<droplet-ip>/v1`
- **DigitalOcean Serverless Inference** – Optional one-key setup with live model fetch
- **Intelligent Inference Router** – Optional `router:<name>` default via wizard or env

## Key Features

- Always-on gateway with Redis-backed rate limiting
- Generated admin password shown in SSH MOTD
- Optional DigitalOcean model access key configuration at first login
- Helper scripts for start/stop/restart/status/update and custom domain TLS
- Ubuntu 24.04 LTS with UFW and fail2ban

## System Requirements

Prefer at least 4 GB RAM for the dashboard and light chat.

| Use Case | RAM | CPU | Storage |
|----------|-----|-----|---------|
| Minimum (dashboard / light chat) | 4 GB | 2 vCPU | 50 GB |
| Recommended (coding agents) | 8–16 GB | 4 vCPU | 100 GB |

## Included System Components

- **Ubuntu 24.04 LTS**
- **OmniRoute** (`diegosouzapw/omniroute:latest` at image build time)
- **Redis** sidecar
- **Caddy** reverse proxy (ports 80/443 → OmniRoute on localhost:20128)
- **UFW** and **fail2ban**

## Getting Started

### 1. Deploy the Droplet

1. Select this 1-Click App from the DigitalOcean Marketplace
2. Choose a Droplet size (4 GB RAM minimum recommended)
3. Add your SSH key
4. Optionally set droplet environment variables `MODEL_ACCESS_KEY`, `INFERENCE_MODEL`, and `DO_INFERENCE_ROUTER`
5. Create the Droplet

### 2. Open the Dashboard

1. Visit `https://your-droplet-ip`
2. Sign in with the **password** shown in the SSH MOTD (also `/opt/omniroute/.env` as `INITIAL_PASSWORD`)

### 3. SSH (optional setup wizard)

```bash
ssh root@your-droplet-ip
```

If Serverless Inference was not passed at create time, the first-login wizard can configure a DigitalOcean Serverless Inference model access key. After the key, press Enter for the default/live model, enter a model id, or `R` for the Intelligent Inference Router. Create keys at https://cloud.digitalocean.com/gen-ai/model-access-keys.

### 4. Create an Endpoint API key and call the API

1. In the dashboard, open **Endpoints** and create an API key
2. Point clients at:

```txt
Base URL: https://your-droplet-ip/v1
API Key:  <endpoint key from dashboard>
Model:    digitalocean/<model-id>   # or auto / router:<name>
```

Example:

```bash
curl https://your-droplet-ip/v1/chat/completions \
  -H "Authorization: Bearer YOUR_ENDPOINT_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"auto","messages":[{"role":"user","content":"Hello!"}]}'
```

## Managing OmniRoute

| Action | Command |
|--------|---------|
| Start | `/opt/start-omniroute.sh` |
| Stop | `/opt/stop-omniroute.sh` |
| Restart | `/opt/restart-omniroute.sh` |
| Status | `/opt/status-omniroute.sh` |
| Update | `/opt/update-omniroute.sh` |
| Domain TLS | `/opt/setup-omniroute-domain.sh` |
| Re-run setup | `/etc/setup_wizard.sh` |
| Logs | `/opt/omniroute/run.sh logs` |

systemd: `systemctl {start|stop|restart|status} omniroute`  
Logs: `journalctl -u omniroute -f`

### Configuration paths

- Env / secrets: `/opt/omniroute/.env` (symlink `/opt/omniroute.env`)
- Compose stack: `/opt/omniroute/`
- Getting started: `/root/omniroute_info.txt`

### DigitalOcean Serverless Inference

When configured, OmniRoute connects the built-in `digitalocean` provider to:

- Base URL: `https://inference.do-ai.run/v1`
- Models: live fetch from `GET /v1/models` (passthrough catalog)
- Intelligent Inference Router: set `DO_INFERENCE_ROUTER=<name>` (or pick `R` in the setup wizard) to use `router:<name>` with the same model access key

### Custom domain (HTTPS)

Point a DNS A record at the droplet, then:

```bash
sudo /opt/setup-omniroute-domain.sh
```

## Security notes

- Port 20128 is bound to localhost; only HTTPS (80/443 via Caddy) is public
- Keep `INITIAL_PASSWORD`, `JWT_SECRET`, `API_KEY_SECRET`, and `REDIS_PASSWORD` private
- Prefer a DigitalOcean Cloud Firewall restricting SSH (and optionally HTTP/HTTPS) to your IP
- For production, use a custom domain with TLS via `/opt/setup-omniroute-domain.sh`

## Additional Resources

- GitHub: https://github.com/diegosouzapw/OmniRoute
- Website: https://omniroute.online
- Docker Hub: https://hub.docker.com/r/diegosouzapw/omniroute
- Serverless Inference: https://docs.digitalocean.com/products/inference/
- Inference Router: https://docs.digitalocean.com/products/inference/how-to/use-inference-router/
