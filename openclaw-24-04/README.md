# OpenClaw 1-Click Droplet

This Packer configuration creates a DigitalOcean Marketplace 1-Click Droplet for OpenClaw, a personal AI assistant platform.

## Overview

OpenClaw is a personal AI assistant you run on your own infrastructure. This 1-Click installs and configures OpenClaw on Ubuntu 24.04 with:

- Node.js 22 runtime
- Docker for sandboxed execution
- OpenClaw Gateway service
- Web-based control UI
- Helper scripts for management

## What Gets Installed

- **OpenClaw** - Latest version (v2026.1.30) from npm
- **Node.js 22** - Required runtime
- **Docker** - For sandboxed tool execution
- **Caddy** - Reverse proxy with automatic TLS
- **Systemd service** - Auto-starting gateway service
- **Helper scripts** - Management utilities
- **Firewall rules** - UFW configured for ports 22, 80, 443, 18789

## Directory Structure

```
/usr/local/lib/node_modules/openclaw/ - OpenClaw npm installation
/opt/openclaw.env           - Environment configuration
/opt/restart-openclaw.sh    - Restart helper script
/opt/status-openclaw.sh     - Status check script
/opt/update-openclaw.sh     - Update helper script
/opt/openclaw-cli.sh        - CLI wrapper script
/opt/setup-openclaw-domain.sh - Domain/HTTPS setup script

/home/openclaw/             - OpenClaw user home
/home/openclaw/.openclaw/   - Configuration directory
/home/openclaw/workspace/   - Agent workspace

/etc/systemd/system/openclaw.service - Service definition
/etc/update-motd.d/99-one-click      - Login message
/etc/token_setup.sh                  - Interactive AI provider setup
```

## Building the Image

### Prerequisites

- Packer installed
- DigitalOcean API token set as `DIGITALOCEAN_API_TOKEN` environment variable
- Access to the droplet-1-clicks repository

### Build Command

From the repository root:

```bash
packer build openclaw-24-04/template.json
```

Or using the Makefile (if available):

```bash
make build-openclaw-24-04
```

## Configuration

The installation creates a default configuration that needs to be customized:

### Required Configuration

After deployment, users must configure at least one AI model provider:

1. SSH into the Droplet
2. Run the interactive setup script (recommended):
   ```bash
   sudo /etc/token_setup.sh
   ```
   This script lets you choose between Anthropic, OpenAI, or GradientAI and will prompt for your API key.

   Alternatively, manually edit `/opt/openclaw.env` and add your API key:
   ```bash
   ANTHROPIC_API_KEY=your_key_here
   # OR
   OPENAI_API_KEY=your_key_here
   ```
3. Restart the service: `systemctl restart openclaw`

### Optional Configuration

- **Messaging channels** - Configure tokens in `/opt/openclaw.env`
- **Detailed settings** - Edit `/home/openclaw/.openclaw/openclaw.json`
- **Gateway settings** - Port, bind address, etc. in `/opt/openclaw.env`

## First Boot

On first boot, the `001_onboot` script:

1. Generates a unique gateway token
2. Saves token to `/home/openclaw/.openclaw/gateway-token.txt`
3. Configures Caddy with the droplet IP
4. Starts the OpenClaw service

Users can access the gateway at `http://droplet-ip:18789` with the generated token.

## Service Management

The OpenClaw Gateway runs as a systemd service:

```bash
# Status
systemctl status openclaw

# Start
systemctl start openclaw

# Stop
systemctl stop openclaw

# Restart
systemctl restart openclaw

# Logs
journalctl -u openclaw -f
```

## Helper Scripts

### restart-openclaw.sh
Restarts the service and checks status

### status-openclaw.sh
Shows service status, gateway token, and URL

### update-openclaw.sh
Updates to latest version from npm:
- Stops service
- Updates OpenClaw package
- Restarts service

### openclaw-cli.sh
Wrapper to run CLI commands as the openclaw user:
```bash
/opt/openclaw-cli.sh <command>
```

### setup-openclaw-domain.sh
Configures a custom domain with HTTPS:
- Sets up Caddy reverse proxy
- Obtains Let's Encrypt certificate
- Updates gateway bind settings

## Security

- Gateway token auto-generated per instance
- Firewall configured with UFW
- Service runs as unprivileged `openclaw` user
- Docker sandboxing available for tool execution
- DM pairing enabled by default
- Fail2ban is preconfigured to ban IPs emitting repeated HTTP 403s in the Caddy access log

## Network Ports

- **22** - SSH (limited by UFW)
- **80** - HTTP (Caddy/HTTP challenge)
- **443** - HTTPS (Caddy reverse proxy)
- **18789** - OpenClaw Gateway

## HTTPS and Custom Domains

Caddy is preinstalled to handle TLS. After pointing a domain at the droplet, run:

```bash
sudo /opt/setup-openclaw-domain.sh
```

The script will prompt for your domain (and optional email for Let's Encrypt), set the gateway bind to `127.0.0.1`, write the Caddyfile, and restart Caddy and OpenClaw. Caddy will obtain and renew certificates automatically.

## Abuse Protection

Fail2ban watches `/var/log/caddy/access.json` for repeated 403 responses and bans offenders.

```bash
sudo fail2ban-client status caddy-403
sudo fail2ban-regex /var/log/caddy/access.json /etc/fail2ban/filter.d/caddy-403.conf
```

## Testing

After building, test the image by:

1. Creating a Droplet from the snapshot
2. SSH in and verify MOTD displays
3. Check service status: `systemctl status openclaw`
4. Retrieve gateway token: `/opt/status-openclaw.sh`
5. Access UI: `http://droplet-ip:18789`
6. Configure an API key and test functionality

## Troubleshooting Build Issues

### Node.js Installation Fails
Ensure the NodeSource repository is accessible. The script uses Node.js 22.

### Build Takes Too Long
The build includes:
- System updates
- Node.js installation
- OpenClaw npm package installation
- Docker setup

Expect 10-15 minutes for a full build.

### Docker Build Fails
The sandbox image build may fail if Docker isn't fully initialized. This is handled gracefully with a warning.

### Service Won't Start
Check:
- OpenClaw is installed: `which openclaw`
- Service logs: `journalctl -u openclaw -xe`
- Permissions on `/home/openclaw` directories

## Marketplace Requirements

This 1-Click meets DigitalOcean Marketplace requirements:

- ✅ Ubuntu 24.04 LTS base
- ✅ Systemd service enabled
- ✅ MOTD with usage instructions
- ✅ UFW firewall configured
- ✅ SSH logout script removed on first boot
- ✅ Application tag applied
- ✅ Cleanup script run
- ✅ Documentation provided

## Resources

- **OpenClaw GitHub**: https://github.com/openclaw/openclaw
- **Documentation**: https://docs.openclaw.ai/
- **Marketplace Guidelines**: https://www.digitalocean.com/community/tutorials/how-to-create-a-digitalocean-marketplace-1-click-app

## Notes

- The service will not be fully functional until an AI model API key is configured
- OpenClaw is installed globally via npm
- Docker sandbox will be built on first use if initial build fails
- Gateway token is unique per Droplet instance
- All data persists in `/home/openclaw/` directories

## License

This 1-Click configuration follows the same MIT License as OpenClaw itself.
