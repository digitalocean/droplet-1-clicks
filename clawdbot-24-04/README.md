# Clawdbot 1-Click Droplet

This Packer configuration creates a DigitalOcean Marketplace 1-Click Droplet for Clawdbot, a personal AI assistant platform.

## Overview

Clawdbot is a personal AI assistant you run on your own infrastructure. This 1-Click installs and configures Clawdbot on Ubuntu 24.04 with:

- Node.js 22 runtime
- Docker for sandboxed execution
- Clawdbot Gateway service
- Web-based control UI
- Helper scripts for management

## What Gets Installed

- **Clawdbot** - Latest version from GitHub
- **Node.js 22** - Required runtime
- **Docker** - For sandboxed tool execution
- **pnpm** - Package manager
- **Systemd service** - Auto-starting gateway service
- **Helper scripts** - Management utilities
- **Firewall rules** - UFW configured for ports 22, 80, 443, 18789

## Directory Structure

```
/opt/clawdbot/              - Clawdbot installation
/opt/clawdbot.env           - Environment configuration
/opt/restart-clawdbot.sh    - Restart helper script
/opt/status-clawdbot.sh     - Status check script
/opt/update-clawdbot.sh     - Update helper script
/opt/clawdbot-cli.sh        - CLI wrapper script

/home/clawdbot/             - Clawdbot user home
/home/clawdbot/.clawdbot/   - Configuration directory
/home/clawdbot/clawd/       - Agent workspace

/etc/systemd/system/clawdbot.service - Service definition
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
packer build clawdbot-24-04/template.json
```

Or using the Makefile (if available):

```bash
make build-clawdbot-24-04
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

   Alternatively, manually edit `/opt/clawdbot.env` and add your API key:
   ```bash
   ANTHROPIC_API_KEY=your_key_here
   # OR
   OPENAI_API_KEY=your_key_here
   ```
3. Restart the service: `systemctl restart clawdbot`

### Optional Configuration

- **Messaging channels** - Configure tokens in `/opt/clawdbot.env`
- **Detailed settings** - Edit `/home/clawdbot/.clawdbot/clawdbot.json`
- **Gateway settings** - Port, bind address, etc. in `/opt/clawdbot.env`

## First Boot

On first boot, the `001_onboot` script:

1. Generates a unique gateway token
2. Saves token to `/home/clawdbot/.clawdbot/gateway-token.txt`
3. Runs initial onboarding (non-interactive)
4. Starts the Clawdbot service

Users can access the gateway at `http://droplet-ip:18789` with the generated token.

## Service Management

The Clawdbot Gateway runs as a systemd service:

```bash
# Status
systemctl status clawdbot

# Start
systemctl start clawdbot

# Stop
systemctl stop clawdbot

# Restart
systemctl restart clawdbot

# Logs
journalctl -u clawdbot -f
```

## Helper Scripts

### restart-clawdbot.sh
Restarts the service and checks status

### status-clawdbot.sh
Shows service status, gateway token, and URL

### update-clawdbot.sh
Updates to latest version from GitHub:
- Stops service
- Pulls latest code
- Rebuilds application
- Restarts service

### clawdbot-cli.sh
Wrapper to run CLI commands as the clawdbot user:
```bash
/opt/clawdbot-cli.sh <command>
```

## Security

- Gateway token auto-generated per instance
- Firewall configured with UFW
- Service runs as unprivileged `clawdbot` user
- Docker sandboxing available for tool execution
- DM pairing enabled by default
- Fail2ban is preconfigured to ban IPs emitting repeated HTTP 403s in the Caddy access log

## Network Ports

- **22** - SSH (limited by UFW)
- **80** - HTTP (Caddy/HTTP challenge)
- **443** - HTTPS (Caddy reverse proxy)
- **18789** - Clawdbot Gateway

## HTTPS and Custom Domains

Caddy is preinstalled to handle TLS. After pointing a domain at the droplet, run:

```bash
sudo /opt/setup-clawdbot-domain.sh
```

The script will prompt for your domain (and optional email for Let's Encrypt), set the gateway bind to `127.0.0.1`, write the Caddyfile, and restart Caddy and Clawdbot. Caddy will obtain and renew certificates automatically.

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
3. Check service status: `systemctl status clawdbot`
4. Retrieve gateway token: `/opt/status-clawdbot.sh`
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
- `/opt/clawdbot/dist/index.js` exists (build completed)
- Dependencies installed in `/opt/clawdbot/node_modules`
- Permissions on `/home/clawdbot` directories
- Logs: `journalctl -u clawdbot -xe`

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

- **Clawdbot GitHub**: https://github.com/clawdbot/clawdbot
- **Documentation**: https://docs.clawd.bot/
- **Marketplace Guidelines**: https://www.digitalocean.com/community/tutorials/how-to-create-a-digitalocean-marketplace-1-click-app

## Notes

- The service will not be fully functional until an AI model API key is configured
- First build includes full dependency installation and compilation
- Sandbox image is built during provisioning
- Gateway token is unique per Droplet instance
- All data persists in `/home/clawdbot/` directories

## License

This 1-Click configuration follows the same MIT License as Clawdbot itself.
