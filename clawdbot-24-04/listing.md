# Clawdbot 1-Click Application

Deploy your own personal AI assistant with Clawdbot, a powerful open-source platform that runs entirely on your infrastructure. Clawdbot connects to the messaging platforms you already use - WhatsApp, Telegram, Slack, Discord, Signal, and more - giving you AI assistance wherever you communicate.

## What is Clawdbot?

Clawdbot is a personal AI assistant you run on your own devices. It provides a local-first Gateway that acts as the control plane for sessions, channels, tools, and events. Built with privacy and control in mind, Clawdbot lets you:

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

Clawdbot runs directly on Ubuntu 24.04 with Node.js 22 and Docker. Choose the appropriate Droplet size based on your usage:

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
   /opt/status-clawdbot.sh
   ```
   This displays your auto-generated gateway token and the Gateway URL.

4. **Configure an AI Model Provider**
   
   Edit the configuration file:
   ```bash
   nano /opt/clawdbot.env
   ```
   
   Add your API key for Anthropic Claude (recommended) or OpenAI:
   ```bash
   # For Anthropic Claude (recommended)
   ANTHROPIC_API_KEY=your_api_key_here
   
   # OR for OpenAI
   OPENAI_API_KEY=your_api_key_here
   ```
   
   For GradientAI, run the setup script:
   ```bash
   sudo /etc/gradient_token_setup.sh
   ```
   
   This script will prompt you for your GradientAI API key and configure it in the Clawdbot configuration file.
   
   Save the file and restart:
   ```bash
   systemctl restart clawdbot
   ```

5. **Access the Control UI**
   
   Open your browser to `http://your-droplet-ip:18789`
   
   Enter the gateway token from step 3 when prompted.

### Configure Messaging Channels

Once you have the Gateway running with an AI model configured, you can add messaging channels:

#### Telegram Bot

1. Create a bot with [@BotFather](https://t.me/botfather) on Telegram
2. Copy the bot token
3. Edit `/opt/clawdbot.env`:
   ```bash
   TELEGRAM_BOT_TOKEN=your_bot_token_here
   ```
4. Restart: `systemctl restart clawdbot`

#### Discord Bot

1. Create a bot in the [Discord Developer Portal](https://discord.com/developers/applications)
2. Copy the bot token
3. Edit `/opt/clawdbot.env`:
   ```bash
   DISCORD_BOT_TOKEN=your_bot_token_here
   ```
4. Restart: `systemctl restart clawdbot`

#### WhatsApp

WhatsApp requires QR code pairing. Use the CLI:
```bash
/opt/clawdbot-cli.sh channels login
```

Follow the prompts to scan the QR code with your WhatsApp app.

#### Other Channels

Clawdbot supports many more channels including Slack, Signal, Google Chat, Microsoft Teams, and iMessage. See the [channels documentation](https://docs.clawd.bot/channels) for setup instructions.

### Security Configuration

By default, Clawdbot uses a pairing-based security model for DMs. Unknown senders must be approved:

1. When someone messages your bot, they receive a pairing code
2. Approve them with:
   ```bash
   /opt/clawdbot-cli.sh pairing approve <channel> <code>
   ```

You can also configure allowlists in `/home/clawdbot/.clawdbot/clawdbot.json`. See the [security documentation](https://docs.clawd.bot/gateway/security) for details.

## Managing Clawdbot

### Service Commands

```bash
# Check status
systemctl status clawdbot

# View logs
journalctl -u clawdbot -f

# Restart service
systemctl restart clawdbot

# Stop service
systemctl stop clawdbot

# Start service
systemctl start clawdbot
```

### Helper Scripts

The installation includes convenient helper scripts:

```bash
# Restart with status check
/opt/restart-clawdbot.sh

# Show status and gateway token
/opt/status-clawdbot.sh

# Update to latest version
/opt/update-clawdbot.sh

# Run CLI commands
/opt/clawdbot-cli.sh <command>
```

## Updating Clawdbot

To update to the latest version:

```bash
/opt/update-clawdbot.sh
```

This script will:
- Pull the latest code from GitHub
- Rebuild the application
- Restart the service
- Preserve all your configuration and data

## Configuration Files

- **Service Configuration**: `/opt/clawdbot.env` - Environment variables for the service
- **User Configuration**: `/home/clawdbot/.clawdbot/clawdbot.json` - Detailed configuration
- **Workspace**: `/home/clawdbot/clawd` - Agent workspace and skills
- **Gateway Token**: `/home/clawdbot/.clawdbot/gateway-token.txt` - Your gateway access token

## Advanced Configuration

### Custom Domain with HTTPS

For production use, we recommend setting up a reverse proxy with Caddy (preinstalled) or Nginx:

1. Point your domain to the Droplet's IP
2. Run `sudo /opt/setup-clawdbot-domain.sh` to supply the domain (and optional email)
3. The script sets `CLAWDBOT_GATEWAY_BIND=127.0.0.1`, writes `/etc/caddy/Caddyfile`, enables HTTPS with Let's Encrypt, and reloads services
4. If you prefer Nginx, configure it to proxy `localhost:18789` and bind the gateway to `127.0.0.1`

**What this does:**
- Configures Caddy to handle TLS/SSL termination
- Obtains free Let's Encrypt certificates automatically
- Renews certificates automatically before expiration
- Proxies HTTPS traffic to the Clawdbot gateway
- Makes your gateway accessible via `https://your-domain.com` instead of `http://ip:18789`

Fail2ban is preconfigured to watch `/var/log/caddy/access.json` and ban IPs that trigger repeated HTTP 403 responses. Check status with `fail2ban-client status caddy-403`.

### Sandbox Configuration

Clawdbot includes Docker-based sandboxing for tool execution. The sandbox is built during installation. To configure sandbox settings, edit `/home/clawdbot/.clawdbot/clawdbot.json`.

See the [sandboxing documentation](https://docs.clawd.bot/gateway/sandboxing) for details.

### Browser Automation

To enable browser automation capabilities:

```bash
cd /opt/clawdbot
su - clawdbot -c "bash scripts/sandbox-browser-setup.sh"
```

Then configure browser settings in `/home/clawdbot/.clawdbot/clawdbot.json`.

## Troubleshooting

### Service won't start

Check logs for errors:
```bash
journalctl -u clawdbot -n 50
```

Verify configuration:
```bash
/opt/status-clawdbot.sh
```

### Can't connect to Gateway

Ensure the firewall allows port 18789:
```bash
ufw status
```

Check if the service is running:
```bash
systemctl status clawdbot
```

### Missing API Key

If you see model errors, ensure you've configured an AI provider in `/opt/clawdbot.env`:
```bash
grep "API_KEY" /opt/clawdbot.env
```

### Gateway Token Lost

Retrieve your token:
```bash
cat /home/clawdbot/.clawdbot/gateway-token.txt
```

## Post-Deployment

After deployment, Clawdbot Gateway will be accessible on port 18789. The installation includes:

- **Gateway Service**: Running as a systemd service
- **Docker**: Installed and configured for sandboxing
- **Node.js 22**: Required runtime environment
- **pnpm**: Package manager for Node.js
- **Helper Scripts**: Convenient management utilities

## System Components

- **Ubuntu 24.04 LTS**: Base operating system
- **Node.js 22**: JavaScript runtime
- **Docker**: Container runtime for sandboxing
- **Clawdbot Gateway**: AI assistant control plane
- **UFW Firewall**: Configured for ports 22, 80, 443, and 18789

## Resources

- **Documentation**: [https://docs.clawd.bot/](https://docs.clawd.bot/)
- **GitHub Repository**: [https://github.com/clawdbot/clawdbot](https://github.com/clawdbot/clawdbot)
- **Getting Started Guide**: [https://docs.clawd.bot/start/getting-started](https://docs.clawd.bot/start/getting-started)
- **Configuration Reference**: [https://docs.clawd.bot/gateway/configuration](https://docs.clawd.bot/gateway/configuration)
- **Channel Setup**: [https://docs.clawd.bot/channels](https://docs.clawd.bot/channels)
- **Security Guide**: [https://docs.clawd.bot/gateway/security](https://docs.clawd.bot/gateway/security)
- **Discord Community**: [https://discord.gg/clawd](https://discord.gg/clawd)

## Support

For issues and questions:
- Check the [documentation](https://docs.clawd.bot/)
- Search [GitHub Issues](https://github.com/clawdbot/clawdbot/issues)
- Join the [Discord community](https://discord.gg/clawd)
- Review the [FAQ](https://docs.clawd.bot/start/faq)

## License

Clawdbot is open source software licensed under the MIT License.
