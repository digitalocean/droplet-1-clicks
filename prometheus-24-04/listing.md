# Prometheus 1-Click Application

Deploy [Prometheus](https://prometheus.io/), an open-source systems monitoring and alerting toolkit, on Ubuntu 24.04 with HTTPS by default.

## System Components

| Component | Details |
|-----------|---------|
| Ubuntu | 24.04 LTS |
| Prometheus | 3.15.0 |
| Caddy | Reverse proxy with automatic Let's Encrypt TLS |
| UFW | Firewall (SSH 22, HTTP 80, HTTPS 443) |

## System Requirements

**Minimum Droplet size: `s-1vcpu-1gb` (1 GB RAM).** Increase CPU and memory for larger scrape loads or longer retention.

## Getting Started

1. **Create a Droplet** from this 1-Click image.
2. **Open Prometheus** at `https://your-droplet-ip` (Caddy terminates TLS with a short-lived Let's Encrypt certificate for the Droplet IP).
3. **Edit scrape config** at `/etc/prometheus/prometheus.yml`, then `systemctl restart prometheus`.

Prometheus listens on `127.0.0.1:9090` only. Public access is through Caddy on ports 80/443.

**Breaking change from older Prometheus 1-Clicks:** the UI is no longer at `http://IP:9090/`. Use `https://IP/` instead.

### Custom Domain (Recommended)

1. Create a DNS A record pointing your domain to the Droplet IP.
2. SSH in and run:

```bash
sudo /opt/setup-prometheus-domain.sh
```

3. Visit `https://your-domain` — Caddy obtains a Let's Encrypt certificate automatically.

## Managing Prometheus

### systemd

```bash
systemctl start prometheus
systemctl stop prometheus
systemctl restart prometheus
systemctl status prometheus
systemctl status caddy
```

### Helper scripts

```bash
/opt/start-prometheus.sh
/opt/stop-prometheus.sh
/opt/restart-prometheus.sh
/opt/status-prometheus.sh
sudo /opt/setup-prometheus-domain.sh
```

## Data Locations

| Path | Purpose |
|------|---------|
| `/etc/prometheus/prometheus.yml` | Scrape and rule configuration |
| `/var/lib/prometheus` | TSDB data |
| `/etc/caddy/Caddyfile` | Reverse proxy / TLS config |
| `/root/prometheus_info.txt` | First-boot access summary |

## Firewall

By default UFW allows SSH (22), HTTP (80), and HTTPS (443). Port 9090 is denied from the public internet.
