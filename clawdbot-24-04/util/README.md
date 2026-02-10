# Clawdbot to OpenClaw Update Script

This directory contains the `update-clawdbot.sh` script for migrating existing clawdbot droplets to the latest OpenClaw version.

## What it does

The script:
- Migrates clawdbot configuration and data to OpenClaw
- Copies `/opt/clawdbot.env` → `/opt/openclaw.env` (preserves API keys, tokens)
- Copies `/home/clawdbot/.clawdbot/` → `/home/openclaw/.openclaw/` (preserves config files)
- Installs and builds the latest OpenClaw from GitHub
- Updates the Message of the Day (MOTD) with new dashboard URL and tools
- Stops clawdbot and starts OpenClaw service

## Usage

### Option 1: Direct curl execution (recommended)

Run directly on your droplet via SSH:

```bash
curl -fsSL https://raw.githubusercontent.com/digitalocean/droplet-1-clicks/main/clawdbot-24-04/util/update-clawdbot.sh | sudo bash
```

### Option 2: Download, review, then execute

```bash
# Download the script
curl -fsSL https://raw.githubusercontent.com/digitalocean/droplet-1-clicks/main/clawdbot-24-04/util/update-clawdbot.sh -o update-clawdbot.sh

# Review the script
less update-clawdbot.sh

# Make it executable
chmod +x update-clawdbot.sh

# Run it
sudo ./update-clawdbot.sh
```

### Option 3: Using wget

```bash
wget -O - https://raw.githubusercontent.com/digitalocean/droplet-1-clicks/main/clawdbot-24-04/util/update-clawdbot.sh | sudo bash
```

## Prerequisites

- Existing clawdbot droplet (DigitalOcean 1-Click)
- Root/sudo access
- Internet connection
- At least 2GB free disk space

## What gets migrated

✅ **Preserved:**
- API keys (Anthropic, OpenAI, etc.) from `/opt/clawdbot.env`
- Channel tokens (Telegram, Discord, Slack, etc.)
- Configuration files from `/home/clawdbot/.clawdbot/`
- Gateway token (or generates new one if missing)

✅ **Updated:**
- Service name: `clawdbot` → `openclaw`
- User: `clawdbot` → `openclaw`
- Paths: `/opt/clawdbot/` → `/opt/openclaw/`
- Message of the Day (MOTD) with new dashboard URL

## After running

1. **Check service status:**
   ```bash
   systemctl status openclaw
   ```

2. **View logs:**
   ```bash
   journalctl -u openclaw -f
   ```

3. **Access dashboard:**
   - The new dashboard URL is shown in the MOTD when you log in
   - Format: `https://<your-droplet-ip>`
   - The dashboard will prompt for your gateway token on first access

4. **Available tools:**
   - `/opt/restart-openclaw.sh` - restart with status check
   - `/opt/status-openclaw.sh` - show status and token
   - `/opt/update-openclaw.sh` - update to latest version
   - `/opt/openclaw-cli.sh` - run CLI commands
   - `/opt/openclaw-tui.sh` - launch TUI interface

## Troubleshooting

### Service won't start

Check logs for errors:
```bash
journalctl -u openclaw -n 100 --no-pager
```

Common issues:
- **Build failed:** Re-run the script; pnpm builds can fail due to transient issues
- **Missing dependencies:** Ensure Node.js 22+ is installed
- **Docker not running:** `systemctl start docker` (required for sandbox)

### Connection refused error

If `openclaw status` shows "ECONNREFUSED":

1. Check bind setting in `/opt/openclaw.env`:
   ```bash
   grep OPENCLAW_GATEWAY_BIND /opt/openclaw.env
   ```

2. Change to `loopback` if needed:
   ```bash
   sed -i 's/OPENCLAW_GATEWAY_BIND=lan/OPENCLAW_GATEWAY_BIND=loopback/' /opt/openclaw.env
   systemctl restart openclaw
   ```

### Config not migrated

If your clawbot config wasn't migrated, manually copy it:

```bash
# Copy environment
sudo cp /opt/clawdbot.env /opt/openclaw.env

# Copy config directory
sudo cp -r /home/clawdbot/.clawdbot /home/openclaw/.openclaw
sudo chown -R openclaw:openclaw /home/openclaw/.openclaw

# Restart
sudo systemctl restart openclaw
```

## Reverting (if needed)

To go back to clawdbot:

```bash
# Stop openclaw
sudo systemctl stop openclaw
sudo systemctl disable openclaw

# Start clawdbot
sudo systemctl enable clawdbot
sudo systemctl start clawdbot
```

## Support

- **Documentation:** https://docs.clawd.bot/
- **GitHub:** https://github.com/openclaw/openclaw
- **Issues:** https://github.com/openclaw/openclaw/issues

## Script version

This README corresponds to the OpenClaw v2026.2.3 update script.
