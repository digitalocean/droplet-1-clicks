# ZeroClaw 1-Click Droplet

This Packer template builds a DigitalOcean Marketplace 1-Click image for [ZeroClaw](https://github.com/zeroclaw-labs/zeroclaw) — a fast, small, and fully autonomous AI assistant infrastructure written in Rust.

## What's Included

- **ZeroClaw** v0.1.9a (pre-built binary)
- **Caddy** reverse proxy with automatic TLS via Let's Encrypt
- **UFW** firewall (ports 80, 443, 22)
- **fail2ban** for SSH brute-force protection
- **Ubuntu 24.04 LTS** base image

## How It Works

ZeroClaw is installed as a pre-built binary at `/usr/local/bin/zeroclaw`. It runs as a systemd service under a dedicated `zeroclaw` user. On first SSH login, an interactive setup wizard prompts you to select an AI provider (DigitalOcean Gradient, OpenAI, Anthropic, or OpenRouter) and enter your API key.

Caddy provides HTTPS via IP-based TLS certificates from Let's Encrypt, reverse-proxying to ZeroClaw's gateway on port 42617.

## Building

```bash
export DIGITALOCEAN_API_TOKEN="your-token"
packer validate zeroclaw-24-04/template.json
packer build zeroclaw-24-04/template.json
```

## Droplet Size

ZeroClaw is extremely lightweight (<5MB RAM, ~8.8MB binary). The minimum `s-1vcpu-1gb` droplet is more than sufficient.

## Files

| Path | Purpose |
|------|---------|
| `template.json` | Packer build template |
| `scripts/010-zeroclaw.sh` | Main install script |
| `files/etc/setup_wizard.sh` | Interactive first-login provider setup |
| `files/etc/config/*.toml` | Provider config templates |
| `files/etc/systemd/system/zeroclaw.service` | Systemd unit file |
| `files/etc/caddy/Caddyfile.tmp` | Caddy config template |
| `files/etc/update-motd.d/99-one-click` | MOTD with usage instructions |
| `files/opt/zeroclaw.env` | Environment configuration |
| `files/opt/*.sh` | Helper scripts (restart, status, update, domain, cli) |
| `files/var/lib/cloud/scripts/per-instance/001_onboot` | First-boot initialization |
