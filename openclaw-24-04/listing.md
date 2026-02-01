# OpenClaw 1-Click Application

Deploy your own personal AI assistant with OpenClaw, a powerful open-source platform that runs entirely on your infrastructure. OpenClaw connects to the messaging platforms you already use - WhatsApp, Telegram, Slack, Discord, Signal, and more - giving you AI assistance wherever you communicate.

## What is OpenClaw?

OpenClaw is a personal AI assistant you run on your own devices. It provides a local-first Gateway that acts as the control plane for sessions, channels, tools, and events. Built with privacy and control in mind, OpenClaw lets you:

- **Multi-channel inbox** - Connect to WhatsApp, Telegram, Slack, Discord, Google Chat, Signal, iMessage, BlueBubbles, Microsoft Teams, Matrix, Zalo, and WebChat
- **Multi-agent routing** - Route inbound channels to isolated agents with different configurations
- **AI model flexibility** - Use Claude (Anthropic), GPT (OpenAI), or other models
- **Browser control** - Automated web browsing and interaction capabilities
- **Voice capabilities** - Text-to-speech and speech-to-text support via Voice Wake and Talk Mode
- **Self-hosted** - Complete control over your data and privacy
- **Skills platform** - Extend capabilities with bundled, managed, and workspace skills

## Key Features

- **Gateway control plane** - WebSocket-based control plane for managing sessions and channels
- **Real-time messaging** - Instant AI responses across all connected platforms
- **Tool execution** - Execute commands, browse the web, manipulate files, and more
- **Session management** - Isolated conversations with context preservation
- **Docker integration** - Built-in support for containerized and sandboxed execution
- **Web UI** - Browser-based control panel for configuration and monitoring
- **Security-first** - Pairing codes, allowlists, and sandboxed execution
- **Extensible** - Plugin system for custom tools and integrations
- **Canvas support** - Agent-driven visual workspace with A2UI
- **Cron & automation** - Schedule tasks and set up webhooks

## System Requirements

OpenClaw runs directly on Ubuntu 24.04 with Node.js 22 and Docker. Choose the appropriate Droplet size based on your usage:

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
   /opt/status-openclaw.sh
   ```
   This displays your auto-generated gateway token and the Gateway URL.

4. **Configure an AI Model Provider**
   
   Run the interactive setup script (recommended):
   ```bash
   sudo /etc/token_setup.sh
   ```
   
   This script will guide you through selecting a provider (Anthropic, OpenAI, or GradientAI) and configuring your API key.
   
   Alternatively, you can manually edit the configuration file:
   ```bash
   nano /opt/openclaw.env
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
   systemctl restart openclaw
   ```

5. **Access the Control UI**
   
   Open your browser to `http://your-droplet-ip:18789`
   
   Enter the gateway token from step 3 when prompted.

### Configure Messaging Channels

Once you have the Gateway running with an AI model configured, you can add messaging channels:

#### Telegram Bot

1. Create a bot with [@BotFather](https://t.me/botfather) on Telegram
2. Copy the bot token
3. Edit `/opt/openclaw.env`:
   ```bash
   TELEGRAM_BOT_TOKEN=your_bot_token_here
   ```
4. Restart: `systemctl restart openclaw`

#### Discord Bot

1. Create a bot in the [Discord Developer Portal](https://discord.com/developers/applications)
2. Copy the bot token
3. Edit `/opt/openclaw.env`:
   ```bash
   DISCORD_BOT_TOKEN=your_bot_token_here
   ```
4. Restart: `systemctl restart openclaw`

#### WhatsApp

WhatsApp requires QR code pairing. Use the CLI:
```bash
/opt/openclaw-cli.sh channels login
```

Follow the prompts to scan the QR code with your WhatsApp app.

#### Other Channels

OpenClaw supports many more channels including Slack, Signal, Google Chat, Microsoft Teams, Matrix, and iMessage. See the [channels documentation](https://docs.openclaw.ai/channels) for setup instructions.

### Security Configuration

By default, OpenClaw uses a pairing-based security model for DMs. Unknown senders must be approved:

1. When someone messages your bot, they receive a pairing code
2. Approve them with:
   ```bash
   /opt/openclaw-cli.sh pairing approve <channel> <code>
   ```

You can also configure allowlists in `/home/openclaw/.openclaw/openclaw.json`. See the [security documentation](https://docs.openclaw.ai/gateway/security) for details.

## Managing OpenClaw

### Service Commands

```bash
# Check status
systemctl status openclaw

# View logs
journalctl -u openclaw -f

# Restart service
systemctl restart openclaw

# Stop service
systemctl stop openclaw

# Start service
systemctl start openclaw
```

### Helper Scripts

The installation includes convenient helper scripts:

```bash
# Restart with status check
/opt/restart-openclaw.sh

# Show status and gateway token
/opt/status-openclaw.sh

# Update to latest version
/opt/update-openclaw.sh

# Run CLI commands
/opt/openclaw-cli.sh <command>

# Launch interactive TUI
/opt/openclaw-tui.sh

# Setup custom domain with HTTPS
/opt/setup-openclaw-domain.sh
```

## Updating OpenClaw

To update to the latest version:

```bash
/opt/update-openclaw.sh
```

This script will:
- Update OpenClaw from npm
- Restart the service
- Preserve all your configuration and data

## Configuration Files

- **Service Configuration**: `/opt/openclaw.env` - Environment variables for the service
- **User Configuration**: `/home/openclaw/.openclaw/openclaw.json` - Detailed configuration
- **Workspace**: `/home/openclaw/workspace` - Agent workspace and skills
- **Gateway Token**: `/home/openclaw/.openclaw/gateway-token.txt` - Your gateway access token

## Advanced Configuration

### HTTPS with Custom Domain

1. Point your domain's A record to your droplet's IP address
2. Run the domain setup script:
   ```bash
   /opt/setup-openclaw-domain.sh
   ```
3. Enter your domain and optional email for Let's Encrypt
4. Caddy will automatically obtain and renew SSL certificates

### Remote Gateway Access

OpenClaw can be accessed remotely over:
- **Tailscale Serve/Funnel** - Secure access via Tailscale network
- **SSH Tunnels** - Port forwarding for secure remote connections

See the [remote access documentation](https://docs.openclaw.ai/gateway/remote) for setup instructions.

### Skills and Tools

OpenClaw includes a skills platform for extending functionality:

- **Bundled skills** - Pre-installed skills
- **Managed skills** - Skills from ClawHub registry
- **Workspace skills** - Custom skills in your workspace

Skills are stored in `/home/openclaw/workspace/skills/`. See the [skills documentation](https://docs.openclaw.ai/tools/skills) for more information.

## Chat Commands

Send these commands in any connected channel:

- `/status` - Display session status and token usage
- `/new` or `/reset` - Reset the session
- `/compact` - Compact session context (summary)
- `/think <level>` - Set thinking level: off|minimal|low|medium|high|xhigh
- `/verbose on|off` - Toggle verbose output
- `/usage off|tokens|full` - Set usage footer display
- `/activation mention|always` - Group activation mode (groups only)

## System Components

This 1-Click includes:

- **Ubuntu 24.04 LTS** - Long-term support base OS
- **Node.js 22** - JavaScript runtime
- **OpenClaw v2026.1.30** - Latest release from npm
- **Docker** - Container runtime for sandboxed execution
- **Caddy** - Modern web server with automatic HTTPS
- **UFW** - Uncomplicated Firewall (pre-configured)
- **Fail2ban** - Intrusion prevention (configured for Caddy)

## Troubleshooting

### Service Won't Start

Check the logs:
```bash
journalctl -u openclaw -xe
```

Common issues:
- Build not completed (check for `/opt/openclaw/dist/index.js`)
- Missing dependencies (run update script)
- Permission issues (check ownership of `/home/openclaw`)

### Gateway Token Not Working

Retrieve your token:
```bash
cat /home/openclaw/.openclaw/gateway-token.txt
```

Or regenerate by editing `/opt/openclaw.env` and restarting.

### Channels Not Connecting

1. Verify tokens in `/opt/openclaw.env`
2. Check logs: `journalctl -u openclaw -f`
3. Ensure firewall allows traffic: `ufw status`
4. Refer to [channel troubleshooting](https://docs.openclaw.ai/channels/troubleshooting)

### Update Failed

If the update script fails:
1. Check internet connectivity
2. Verify npm is working: `npm --version`
3. Manually update:
   ```bash
   systemctl stop openclaw
   npm update -g openclaw
   systemctl restart openclaw
   ```

## Security Best Practices

1. **Change default gateway token** - Generate a new token after deployment
2. **Enable HTTPS** - Use the domain setup script to enable TLS
3. **Configure allowlists** - Restrict who can message your bot
4. **Enable sandboxing** - Use Docker sandboxes for non-main sessions
5. **Regular updates** - Keep OpenClaw updated with the update script
6. **Monitor logs** - Watch for suspicious activity
7. **Use strong API keys** - Protect your AI provider credentials

## Support and Documentation

- **Official Documentation**: https://docs.openclaw.ai/
- **GitHub Repository**: https://github.com/openclaw/openclaw
- **Discord Community**: https://discord.gg/clawd
- **Getting Started Guide**: https://docs.openclaw.ai/start/getting-started
- **FAQ**: https://docs.openclaw.ai/start/faq
- **Troubleshooting**: https://docs.openclaw.ai/channels/troubleshooting

## About OpenClaw

OpenClaw is an open-source personal AI assistant platform built by Peter Steinberger (@steipete) and the community. It's designed to give you a powerful AI assistant that you control completely, running on your own infrastructure with your choice of AI models and messaging channels.

The platform emphasizes privacy, flexibility, and extensibility - allowing you to customize every aspect of your AI assistant while maintaining full ownership of your data.

## License

OpenClaw is released under the MIT License. See the [LICENSE](https://github.com/openclaw/openclaw/blob/main/LICENSE) file for details.
