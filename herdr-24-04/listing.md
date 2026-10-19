# Herdr 1-Click Application

Deploy Herdr, the terminal runtime coding agents run in, with Claude Code, Codex, OpenCode, Grok Build, Kilo Code CLI, and Cursor Agent CLI already installed. SSH in, run `herdr`, and start an agent in a pane. You do not install those CLIs yourself.

## What is Herdr?

Herdr is a terminal multiplexer for coding agents. Each agent keeps its own pane. You can detach, close the laptop, or drop the SSH session, and the agents keep working. Reattach later with `herdr`.

This image installs Herdr as a systemd service and preinstalls six agent CLIs Herdr already knows how to run:

| Command | Agent |
|---------|--------|
| `claude` | Claude Code |
| `codex` | OpenAI Codex CLI |
| `opencode` | OpenCode |
| `grok` | Grok Build |
| `kilo` | Kilo Code CLI |
| `cursor-agent` | Cursor Agent CLI |

Herdr integrations for those agents are installed too, so Herdr can restore their sessions after the server restarts.

## Key Features

- Herdr server starts on boot and survives SSH disconnects
- Six coding-agent CLIs on `PATH` from the first login
- Session-restore integrations for Claude Code, Codex, OpenCode, Grok Build, Kilo Code, and Cursor Agent CLI
- SSH only — there is no web interface
- Helper scripts to start, stop, restart, and update Herdr and the agents

## System Requirements

The agents do most of their work at the model provider. The Droplet needs enough memory to run Herdr plus one or more agent processes.

| Use Case | RAM | CPU | Storage |
|----------|-----|-----|---------|
| Minimum | 4 GB | 2 vCPU | 80 GB |
| Recommended | 8 GB | 4 vCPU | 160 GB |

## Included System Components

- **Ubuntu 24.04 LTS** — Base operating system
- **Herdr 0.9.3** — Terminal runtime for coding agents (`herdr.service`)
- **Claude Code 2.1.289** — Anthropic coding agent
- **Codex CLI 0.160.0** — OpenAI coding agent
- **OpenCode 1.18.34** — Open-source coding agent
- **Grok Build 1.0.46** — xAI coding agent
- **Kilo Code CLI 7.8.3** — Kilo coding agent
- **Cursor Agent CLI 2026.10.01-e373342** — Cursor coding agent (`cursor-agent`)
- **Node.js 22** — Used to install Kilo Code CLI
- **Git**, **ripgrep**, **curl**, **jq**, **unzip**, **build-essential** — Development utilities
- **UFW Firewall** — SSH only, rate-limited

## Getting Started

### 1. Deploy the Droplet

1. Select this 1-Click App from the DigitalOcean Marketplace
2. Choose a Droplet size (4 GB RAM minimum; 8 GB recommended)
3. Add your SSH key
4. Create the Droplet

### 2. SSH In

```bash
ssh root@your-droplet-ip
```

### 3. Attach on the Droplet

The Herdr server is already running.

```bash
herdr
```

Detach with **Ctrl-b** then **q**. Agents keep running. Run `herdr` again to reattach.

### 4. Attach from your laptop

Install Herdr on the laptop, then point an SSH config entry at the Droplet. Herdr uses that host name with `--remote`, so the local client draws the UI and the Droplet keeps the panes.

On the laptop:

```bash
curl -fsSL https://herdr.dev/install.sh | sh
```

Add this to `~/.ssh/config`. Use the SSH key you added when you created the Droplet. `Host` is the name you will pass to Herdr.

```
Host herdr-droplet
  HostName your-droplet-ip
  User root
  IdentityFile ~/.ssh/id_ed25519
```

Confirm the host alias from the laptop, then exit that shell and attach:

```bash
ssh herdr-droplet
exit
herdr --remote herdr-droplet
```

Without an SSH config entry, the same attach is:

```bash
herdr --remote ssh://root@your-droplet-ip
```

Detach from the laptop with **Ctrl-b** then **q**. The agents stay on the Droplet. Run `herdr --remote herdr-droplet` again to come back. Remote attach uses your laptop's Herdr keybindings.

### 5. Start an Agent

Inside a Herdr pane:

```bash
cd /root/workspace
claude
```

The same pane can run `codex`, `opencode`, `grok`, `kilo`, or `cursor-agent`. Each CLI is already installed.

### 6. Sign In Once Per Agent

The binaries are on the image. Each product still needs your own account or API key the first time you launch it:

| Agent | First sign-in |
|-------|----------------|
| Claude Code | `claude` |
| Codex | `codex login` |
| OpenCode | `opencode auth login` |
| Grok Build | `grok login --device-auth` |
| Kilo Code | `kilo auth` |
| Cursor | `cursor-agent login` |

Grok Build can also use an API key in the environment (`XAI_API_KEY`, or the key its CLI documents) instead of device login.

## Managing Herdr

Herdr runs as `herdr.service`.

| Action | Command |
|--------|---------|
| Start | `/opt/start-herdr.sh` |
| Stop | `/opt/stop-herdr.sh` |
| Restart | `/opt/restart-herdr.sh` |
| Status and versions | `/opt/status-herdr.sh` |
| Update Herdr | `/opt/update-herdr.sh` |
| Update the agents | `/opt/update-agents.sh` |

The same actions through systemd:

```bash
systemctl start herdr
systemctl stop herdr
systemctl restart herdr
systemctl status herdr
```

Stopping the server ends live panes. Herdr restores the saved layout on the next start, and the preinstalled integrations let it resume agent sessions.

## Configuration

- **Herdr binary**: `/usr/local/bin/herdr`
- **systemd unit**: `/etc/systemd/system/herdr.service`
- **Agent binaries**: `/usr/local/bin/claude`, `codex`, `opencode`, `grok`, `kilo`, `cursor-agent`
- **Getting started guide**: `cat /root/herdr_info.txt`
- **Workspace directory**: `/root/workspace`

## Troubleshooting

### `herdr` does not attach

Check the service, then start it:

```bash
/opt/status-herdr.sh
/opt/start-herdr.sh
```

### An agent command is not found

Open a new login shell, or run the binary directly:

```bash
/usr/local/bin/claude --version
/usr/local/bin/codex --version
/usr/local/bin/opencode --version
/usr/local/bin/grok --version
/usr/local/bin/kilo --version
/usr/local/bin/cursor-agent --version
```

### An agent asks to sign in

That is expected on first launch. Use the sign-in command in the table above. The CLI is already installed.

## Additional Resources

- **Herdr docs**: <https://herdr.dev/docs/>
- **Remote attach**: <https://herdr.dev/docs/how-to-work/>
- **Supported agents**: <https://herdr.dev/docs/agents/>
- **Integrations**: <https://herdr.dev/docs/integrations/>

## Support

For Herdr issues, see <https://herdr.dev/docs/> and <https://github.com/herdrdev/herdr>.

For DigitalOcean Droplet issues:

- DigitalOcean Support: <https://www.digitalocean.com/support>
- Community Tutorials: <https://www.digitalocean.com/community>
