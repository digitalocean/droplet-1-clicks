# Moltbot 1-Click Application

Deploy your own personal AI assistant with Moltbot, a powerful open-source platform that runs entirely on your infrastructure. Moltbot connects to the messaging platforms you already use - WhatsApp, Telegram, Slack, Discord, Signal, and more - giving you AI assistance wherever you communicate.

## What is Moltbot?

Moltbot is a personal AI assistant you run on your own devices. It provides a local-first Gateway that acts as the control plane for sessions, channels, tools, and events. Built with privacy and control in mind, Moltbot lets you:

- **Multi-channel inbox** - Connect to WhatsApp, Telegram, Slack, Discord, Google Chat, Signal, iMessage, Microsoft Teams, and more
- **Multi-agent routing** - Route inbound channels to isolated agents with different configurations
- **AI model flexibility** - Use Claude (Anthropic), GPT (OpenAI), or other models
- **Browser control** - Automated web browsing and interaction capabilities
- **Voice capabilities** - Text-to-speech and speech-to-text support
- **Self-hosted** - Complete control over your data and privacy
- **Skills platform** - Extend capabilities with bundled and custom skills

## Key Features

- **Gateway control plane** - WebSocket-based control plane for managing sessions and channels
- **Real-time messaging** - Instant AI responses across all connected platforms
- **Tool execution** - Execute commands, browse the web, manipulate files, and more
- **Session management** - Isolated conversations with context preservation
- **Docker integration** - Built-in support for containerized deployments
- **Web UI** - Browser-based control panel for configuration and monitoring
- **Security-first** - Pairing codes, allowlists, and sandboxed execution
- **Extensible** - Plugin system for custom tools and integrations

## System Requirements

Moltbot runs directly on Ubuntu 24.04 with Node.js 22 and Docker. Choose the appropriate Droplet size based on your usage:

| Usage Level | RAM | CPU | Recommended For |
|------------|-----|-----|-----------------|
| Personal (1-5 users) | 4GB | 2CPU | Individual use, few channels |
| Small Team (5-20 users) | 8GB | 4CPU | Small team, multiple channels |
| Medium Team (20-50 users) | 16GB | 8CPU | Medium team, heavy usage |
| Large Team (50+ users) | 32GB | 16CPU | Large deployment, high volume |

**Note**: This 1-Click includes Docker for sandboxed execution. Additional resources may be needed if you enable multiple sandbox instances or browser automation.

## Getting Started

### Quick Start

1. **Deploy the Droplet** - Select this 1-Click App from the DigitalOcean Marketplace
2. **SSH into your Droplet**
   ```bash
   ssh root@your-droplet-ip
   ```
3. **Get your Gateway token**
   ```bash
   /opt/status-moltbot.sh
   ```
   This displays your gateway access URL with the embedded token. Copy the full URL including the `?token=` parameter.

4. **Enable HTTPS (Recommended)**
   
   For secure WebSocket connections and production use, enable HTTPS:
   
   a. Point your domain to this Droplet's IP address
   b. Wait for DNS propagation (test with `dig +short yourdomain.com`)
   c. Run the HTTPS setup script:
   ```bash
   /opt/enable-https-moltbot.sh
   ```
   d. Follow the prompts to enter your domain name
   
   Caddy will automatically obtain and renew Let's Encrypt SSL certificates. Your Gateway will then be accessible at `https://yourdomain.com`.
   
   **Note**: If you skip HTTPS setup, you can access the Gateway at `http://your-droplet-ip:18789`, but WebSocket connections may require an SSH tunnel for security. See "Accessing Without HTTPS" below.

5. **Configure an AI Model Provider**
   
   Edit the configuration file:
   ```bash
   nano /opt/moltbot.env
   ```
   
   Add your API key for Anthropic Claude (recommended) or OpenAI:
   ```bash
   # For Anthropic Claude (recommended)
   ANTHROPIC_API_KEY=your_api_key_here
   
   # OR for OpenAI
   OPENAI_API_KEY=your_api_key_here
   ```
   
   Save the file and restart:
   ```bash
   systemctl restart moltbot
   ```

6. **Access the Control UI**
   
   - **With HTTPS**: Open `https://yourdomain.com?token=YOUR_TOKEN` (if you completed step 4)
   - **Without HTTPS**: Open the full URL from step 3 (including `?token=` parameter)
   - **Via SSH tunnel**: See "Accessing Without HTTPS" section below
   
   The token is embedded in the URL as a query parameter. If you see an "unauthorized" error, ensure you're using the full URL with `?token=` from the status script.

### Accessing Without HTTPS

If you haven't set up a domain with HTTPS, the Control UI requires a secure context for WebSocket connections. You can access it via SSH tunnel:

```bash
ssh -L 18789:localhost:18789 root@your-droplet-ip
```

Then get your tokenized URL:
```bash
/opt/status-moltbot.sh
```

Copy the localhost URL (with token) and paste it into your browser on your local machine.

Alternatively, run `/opt/enable-https-moltbot.sh` to set up HTTPS with your domain.

### Configure Messaging Channels

Once you have the Gateway running with an AI model configured, you can add messaging channels:

#### Telegram Bot

1. Create a bot with [@BotFather](https://t.me/botfather) on Telegram
2. Copy the bot token
3. Edit `/opt/moltbot.env`:
   ```bash
   TELEGRAM_BOT_TOKEN=your_bot_token_here
   ```
4. Restart: `systemctl restart moltbot`

#### Discord Bot

1. Create a bot in the [Discord Developer Portal](https://discord.com/developers/applications)
2. Copy the bot token
3. Edit `/opt/moltbot.env`:
   ```bash
   DISCORD_BOT_TOKEN=your_bot_token_here
   ```
4. Restart: `systemctl restart moltbot`

#### WhatsApp

WhatsApp requires QR code pairing. Use the CLI:
```bash
/opt/moltbot-cli.sh channels login
```

Follow the prompts to scan the QR code with your WhatsApp app.

#### Other Channels

Moltbot supports many more channels including Slack, Signal, Google Chat, Microsoft Teams, and iMessage. See the [channels documentation](https://docs.molt.bot/channels) for setup instructions.

### Security Configuration

By default, Moltbot uses a pairing-based security model for DMs. Unknown senders must be approved:

1. When someone messages your bot, they receive a pairing code
2. Approve them with:
   ```bash
   /opt/moltbot-cli.sh pairing approve <channel> <code>
   ```

You can also configure allowlists in `/home/moltbot/.moltbot/moltbot.json`. See the [security documentation](https://docs.molt.bot/gateway/security) for details.

## Managing Moltbot

### Service Commands

```bash
# Check status
systemctl status moltbot

# View logs
journalctl -u moltbot -f

# Restart service
systemctl restart moltbot

# Stop service
systemctl stop moltbot

# Start service
systemctl start moltbot
```

### Helper Scripts

The installation includes convenient helper scripts:

```bash
# Restart with status check
/opt/restart-moltbot.sh

# Show status and gateway token
/opt/status-moltbot.sh

# Update to latest version
/opt/update-moltbot.sh

# Run CLI commands
/opt/moltbot-cli.sh <command>

# Enable HTTPS with your domain
/opt/enable-https-moltbot.sh
```

## Updating Moltbot

To update to the latest version:

```bash
/opt/update-moltbot.sh
```

This script will:
- Pull the latest code from GitHub
- Rebuild the application
- Restart the service
- Preserve all your configuration and data

## Configuration Files

- **Service Configuration**: `/opt/moltbot.env` - Environment variables for the service
- **User Configuration**: `/home/moltbot/.moltbot/moltbot.json` - Detailed configuration
- **Workspace**: `/home/moltbot/molt` - Agent workspace and skills
- **Gateway Token**: `/home/moltbot/.moltbot/gateway-token.txt` - Your gateway access token

## Advanced Configuration

### Custom Domain with HTTPS

This 1-Click includes Caddy reverse proxy with automatic Let's Encrypt SSL. To enable HTTPS:

```bash
/opt/enable-https-moltbot.sh
```

This script will:
1. Prompt you for your domain name
2. Configure Caddy to reverse proxy to the Gateway
3. Automatically obtain Let's Encrypt SSL certificates
4. Update the Gateway to bind to localhost (more secure)
5. Reload services

**Requirements:**
- Domain name pointed to this Droplet's IP address
- DNS propagation complete (verify with `dig +short yourdomain.com`)
- Ports 80 and 443 open (already configured)

Once complete, your Gateway will be accessible at `https://yourdomain.com` with automatic SSL certificate renewal.

### Sandbox Configuration

Moltbot includes Docker-based sandboxing for tool execution. The sandbox is built during installation. To configure sandbox settings, edit `/home/moltbot/.moltbot/moltbot.json`.

See the [sandboxing documentation](https://docs.molt.bot/gateway/sandboxing) for details.

### Browser Automation

To enable browser automation capabilities:

```bash
cd /opt/moltbot
su - moltbot -c "bash scripts/sandbox-browser-setup.sh"
```

Then configure browser settings in `/home/moltbot/.moltbot/moltbot.json`.

## Troubleshooting

### Service won't start

Check logs for errors:
```bash
journalctl -u moltbot -n 50
```

Verify configuration:
```bash
/opt/status-moltbot.sh
```

### Can't connect to Gateway

Ensure the firewall allows port 18789:
```bash
ufw status
```

Check if the service is running:
```bash
systemctl status moltbot
```

### Missing API Key

If you see model errors, ensure you've configured an AI provider in `/opt/moltbot.env`:
```bash
grep "API_KEY" /opt/moltbot.env
```

### Gateway Token Lost

Retrieve your full tokenized URL:
```bash
/opt/status-moltbot.sh
```

Or get just the token:
```bash
cat /home/moltbot/.moltbot/gateway-token.txt
```

Add it to your URL as: `http://your-ip:18789?token=YOUR_TOKEN`

## Post-Deployment

After deployment, Moltbot Gateway will be accessible on port 18789 (HTTP) or via your domain with HTTPS. The installation includes:

- **Gateway Service**: Running as a systemd service
- **Caddy Web Server**: Installed and ready for HTTPS setup
- **Docker**: Installed and configured for sandboxing
- **Node.js 22**: Required runtime environment
- **pnpm**: Package manager for Node.js
- **Helper Scripts**: Convenient management utilities

## System Components

- **Ubuntu 24.04 LTS**: Base operating system
- **Node.js 22**: JavaScript runtime
- **Caddy 2**: Web server with automatic HTTPS
- **Docker**: Container runtime for sandboxing
- **Moltbot Gateway**: AI assistant control plane
- **UFW Firewall**: Configured for ports 22, 80, 443, and 18789

## Resources

- **Documentation**: [https://docs.molt.bot/](https://docs.molt.bot/)
- **GitHub Repository**: [https://github.com/moltbot/moltbot](https://github.com/moltbot/moltbot)
- **Getting Started Guide**: [https://docs.molt.bot/start/getting-started](https://docs.molt.bot/start/getting-started)
- **Configuration Reference**: [https://docs.molt.bot/gateway/configuration](https://docs.molt.bot/gateway/configuration)
- **Channel Setup**: [https://docs.molt.bot/channels](https://docs.molt.bot/channels)
- **Security Guide**: [https://docs.molt.bot/gateway/security](https://docs.molt.bot/gateway/security)
- **Discord Community**: [https://discord.gg/molt](https://discord.gg/molt)

## Support

For issues and questions:
- Check the [documentation](https://docs.molt.bot/)
- Search [GitHub Issues](https://github.com/moltbot/moltbot/issues)
- Join the [Discord community](https://discord.gg/molt)
- Review the [FAQ](https://docs.molt.bot/start/faq)

## License

Moltbot is open source software licensed under the MIT License.
