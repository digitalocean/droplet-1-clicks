# ZeroClaw

## Overview

ZeroClaw is a fast, small, and fully autonomous AI assistant infrastructure built in Rust. It serves as the runtime operating system for agentic workflows — abstracting models, tools, memory, and execution so agents can be built once and run anywhere.

With a memory footprint under 5MB and cold start times under 10ms, ZeroClaw is designed for cost-efficient deployment on minimal hardware.

## Features

- **Lean Runtime:** Single Rust binary with <5MB RAM usage and near-instant startup
- **Provider Agnostic:** Supports OpenAI, Anthropic, OpenRouter, Ollama, and any OpenAI-compatible endpoint
- **Multi-Channel:** CLI, Telegram, Discord, Slack, WhatsApp, and more
- **Built-in Memory:** SQLite hybrid search with vector + keyword retrieval
- **Secure by Default:** Gateway pairing, sandbox execution, filesystem scoping, encrypted secrets
- **Fully Swappable:** Every subsystem is a trait — swap providers, channels, tools, and memory with config changes

## System Components

| Component | Details |
|-----------|---------|
| ZeroClaw | v0.1.9a (pre-built Rust binary) |
| Caddy | Reverse proxy with automatic TLS |
| UFW | Firewall (HTTP, HTTPS, SSH) |
| fail2ban | SSH brute-force protection |
| Ubuntu | 24.04 LTS |

## Getting Started

1. **Create a Droplet** using this 1-Click image
2. **SSH into your Droplet** — the setup wizard will run automatically on first login
3. **Select an AI provider** (DigitalOcean Gradient, OpenAI, Anthropic, or OpenRouter)
4. **Enter your API key** when prompted
5. **Access the gateway** at `https://your-droplet-ip`

## Managing ZeroClaw

### Service Control

```bash
# Restart the service
systemctl restart zeroclaw

# Check service status
systemctl status zeroclaw

# View logs
journalctl -u zeroclaw -f
```

### Helper Scripts

```bash
# Restart with status check
/opt/restart-zeroclaw.sh

# Show status and version
/opt/status-zeroclaw.sh

# Update to latest version
sudo /opt/update-zeroclaw.sh

# Configure custom domain with TLS
sudo /opt/setup-zeroclaw-domain.sh

# Run CLI commands
/opt/zeroclaw-cli.sh status
/opt/zeroclaw-cli.sh doctor
/opt/zeroclaw-cli.sh agent -m "Hello, ZeroClaw!"
```

### Reconfigure Provider

```bash
sudo /etc/setup_wizard.sh
```

### Custom Domain with HTTPS

Point your domain's DNS to your Droplet's IP, then run:

```bash
sudo /opt/setup-zeroclaw-domain.sh
```

This configures Caddy with automatic Let's Encrypt TLS certificates.

### Update ZeroClaw

```bash
sudo /opt/update-zeroclaw.sh
```

This downloads the latest release binary from GitHub and restarts the service.

## Configuration

The main configuration file is located at `/home/zeroclaw/.zeroclaw/config.toml`. See the [ZeroClaw documentation](https://zeroclawlabs.ai) for all configuration options.

## Resources

- [ZeroClaw GitHub](https://github.com/zeroclaw-labs/zeroclaw)
- [ZeroClaw Documentation](https://zeroclawlabs.ai)
- [ZeroClaw Releases](https://github.com/zeroclaw-labs/zeroclaw/releases)
