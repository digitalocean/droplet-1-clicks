# Moltbot 1-Click Droplet

This Packer configuration creates a DigitalOcean Marketplace 1-Click Droplet for Moltbot, a personal AI assistant platform.

## Overview

Moltbot is a personal AI assistant you run on your own infrastructure. This 1-Click installs and configures Moltbot on Ubuntu 24.04 with:

- Node.js 22 runtime
- Docker for sandboxed execution
- Moltbot Gateway service
- Web-based control UI
- Helper scripts for management

## What Gets Installed

- **Moltbot** - Latest version from GitHub
- **Node.js 22** - Required runtime
- **Caddy 2** - Web server with automatic HTTPS
- **Docker** - For sandboxed tool execution
- **pnpm** - Package manager
- **Systemd service** - Auto-starting gateway service
- **Helper scripts** - Management utilities
- **Firewall rules** - UFW configured for ports 22, 80, 443, 18789

## Directory Structure

```
/opt/moltbot/              - Moltbot installation
/opt/moltbot.env           - Environment configuration
/opt/restart-moltbot.sh    - Restart helper script
/opt/status-moltbot.sh     - Status check script
/opt/update-moltbot.sh     - Update helper script
/opt/moltbot-cli.sh        - CLI wrapper script
/opt/enable-https-moltbot.sh - HTTPS setup script

/home/moltbot/             - Moltbot user home
/home/moltbot/.moltbot/   - Configuration directory
/home/moltbot/molt/       - Agent workspace

/etc/caddy/Caddyfile        - Caddy reverse proxy config
/etc/systemd/system/moltbot.service - Service definition
/etc/update-motd.d/99-one-click      - Login message
```

## Building the Image

### Prerequisites

- Packer installed
- DigitalOcean API token set as `DIGITALOCEAN_API_TOKEN` environment variable
- Access to the droplet-1-clicks repository

### Build Command

From the repository root:

```bash
packer build moltbot-24-04/template.json
```

Or using the Makefile (if available):

```bash
make build-moltbot-24-04
```

## Configuration

The installation creates a default configuration that needs to be customized:

### Required Configuration

After deployment, users must configure at least one AI model provider:

1. SSH into the Droplet
2. Edit `/opt/moltbot.env`
3. Add API key for Anthropic or OpenAI:
   ```bash
   ANTHROPIC_API_KEY=your_key_here
   # OR
   OPENAI_API_KEY=your_key_here
   ```
4. Restart the service: `systemctl restart moltbot`

### Optional Configuration

- **Messaging channels** - Configure tokens in `/opt/moltbot.env`
- **Detailed settings** - Edit `/home/moltbot/.moltbot/moltbot.json`
- **Gateway settings** - Port, bind address, etc. in `/opt/moltbot.env`

## First Boot

On first boot, the `001_onboot` script:

1. Generates a unique gateway token
2. Saves token to `/home/moltbot/.moltbot/gateway-token.txt`
3. Creates minimal configuration with gateway.mode=local
4. Starts the Moltbot service
5. Starts Caddy web server (ready for HTTPS setup)

Users can access the gateway at `http://droplet-ip:18789` with the generated token, or set up HTTPS with `/opt/enable-https-moltbot.sh`.

## HTTPS Setup

To enable HTTPS with automatic Let's Encrypt certificates:

1. Point a domain to the Droplet's IP address
2. Wait for DNS propagation
3. Run: `/opt/enable-https-moltbot.sh`
4. Enter your domain when prompted

The script will:
- Configure Caddy as a reverse proxy
- Obtain SSL certificates automatically
- Update Gateway to bind to localhost
- Enable secure WebSocket connections

## Service Management

The Moltbot Gateway runs as a systemd service:

```bash
# Status
systemctl status moltbot

# Start
systemctl start moltbot

# Stop
systemctl stop moltbot

# Restart
systemctl restart moltbot

# Logs
journalctl -u moltbot -f
```

## Helper Scripts

### restart-moltbot.sh
Restarts the service and checks status

### status-moltbot.sh
Shows service status, gateway token, and URL

### update-moltbot.sh
Updates to latest version from GitHub:
- Stops service
- Pulls latest code
- Rebuilds application
- Restarts service

### moltbot-cli.sh
Wrapper to run CLI commands as the moltbot user:
```bash
/opt/moltbot-cli.sh <command>
```

### enable-https-moltbot.sh
Configures Caddy reverse proxy with automatic Let's Encrypt SSL:
- Prompts for domain name
- Configures Caddyfile
- Updates Gateway to bind to localhost
- Obtains SSL certificates automatically

## Security

- Gateway token auto-generated per instance
- Firewall configured with UFW
- Service runs as unprivileged `moltbot` user
- Docker sandboxing available for tool execution
- DM pairing enabled by default

## Network Ports

- **22** - SSH (limited by UFW)
- **80** - HTTP (for future reverse proxy)
- **443** - HTTPS (for future reverse proxy)
- **18789** - Moltbot Gateway

## Testing

After building, test the image by:

1. Creating a Droplet from the snapshot
2. SSH in and verify MOTD displays
3. Check service status: `systemctl status moltbot`
4. Retrieve gateway token: `/opt/status-moltbot.sh`
5. Access UI: `http://droplet-ip:18789`
6. Configure an API key and test functionality

## Troubleshooting Build Issues

### Node.js Installation Fails
Ensure the NodeSource repository is accessible. The script uses Node.js 22.

### Build Takes Too Long
The build includes:
- System updates
- Node.js installation
- Repository cloning
- pnpm install (large dependency tree)
- Building the application (TypeScript compilation)
- Building the UI (React application)
- Building the sandbox image

Expect 15-30 minutes for a full build.

### pnpm Install Fails
Check that corepack is properly enabled. The script runs:
```bash
corepack enable
corepack prepare pnpm@latest --activate
```

### Docker Build Fails
The sandbox image build may fail if Docker isn't fully initialized. This is handled gracefully with a warning.

### Service Won't Start
Check:
- `/opt/moltbot/dist/index.js` exists (build completed)
- Dependencies installed in `/opt/moltbot/node_modules`
- Permissions on `/home/moltbot` directories
- Logs: `journalctl -u moltbot -xe`

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

- **Moltbot GitHub**: https://github.com/moltbot/moltbot
- **Documentation**: https://docs.molt.bot/
- **Marketplace Guidelines**: https://www.digitalocean.com/community/tutorials/how-to-create-a-digitalocean-marketplace-1-click-app

## Notes

- The service will not be fully functional until an AI model API key is configured
- First build includes full dependency installation and compilation
- Sandbox image is built during provisioning
- Gateway token is unique per Droplet instance
- All data persists in `/home/moltbot/` directories

## License

This 1-Click configuration follows the same MIT License as Moltbot itself.
