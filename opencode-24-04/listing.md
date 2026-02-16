# OpenCode 1-Click Application

Deploy OpenCode, an open-source AI coding agent that runs in your terminal. Use natural language to write, debug, and refactor code. Code and context stay local by default.

## What is OpenCode?

OpenCode brings AI assistance into the command line. It's a terminal-based coding agent that works with your favorite LLM providers—Claude, GPT, Gemini, and more—via Models.dev or your own API keys.

- **Terminal-first** – Works natively in your shell, no web interface required
- **Multiple sessions** – Run multiple agents for different tasks
- **File references** – Use `@filename` to include files in context
- **Shell commands** – Execute commands with `!` prefix
- **Slash commands** – `/init`, `/connect`, `/share` and more
- **Privacy-focused** – Code stays on your server by default

## Key Features

- Natural language coding assistance in the terminal
- Support for many LLM providers (Claude, OpenAI, Gemini, etc.)
- Free models available via Models.dev / OpenCode Zen
- Works with existing projects—navigate, edit, and run code
- No IDE required—pure terminal workflow

## System Requirements

OpenCode is lightweight; most compute happens at the LLM provider.

| Use Case | RAM | CPU | Storage |
|----------|-----|-----|---------|
| Minimum | 1 GB | 1 vCPU | 25 GB |
| Recommended | 2 GB | 2 vCPU | 50 GB |

## Included System Components

- **Ubuntu 24.04 LTS** – Base operating system
- **OpenCode** – AI coding agent (version 1.2.5)
- **Git** – Version control
- **UFW Firewall** – SSH only (rate-limited)

## Getting Started

### 1. Deploy the Droplet

1. Select this 1-Click App from the DigitalOcean Marketplace
2. Choose a Droplet size (1 GB RAM minimum)
3. Add your SSH key for secure access
4. Create the Droplet

### 2. SSH In and Configure

```bash
ssh root@your-droplet-ip
```

### 3. Set Up Your LLM Provider (Required)

OpenCode needs an LLM to operate. Choose one:

**Free option (recommended for getting started):**
- Visit https://opencode.ai/auth
- Sign in and connect your Models.dev account for free models

**Or use your own API keys:**
- Set your provider's API key in OpenCode's configuration
- See https://opencode.ai/docs for provider-specific setup

### 4. Run OpenCode

```bash
cd /path/to/your/project
opencode
```

## Managing OpenCode

### Helper Scripts

| Action | Command |
|--------|---------|
| Check version | `/opt/opencode-version.sh` |
| Update to latest | `/opt/update-opencode.sh` |

### Configuration

- **Config directory**: `/root/.config/opencode/`
- **Getting started guide**: `cat /root/opencode_info.txt`

## Updating

To update OpenCode to the latest version:

```bash
/opt/update-opencode.sh
```

## Troubleshooting

### OpenCode not found in PATH

Ensure you're in a login shell (SSH session) where PATH is set. Or run directly:

```bash
/root/.opencode/bin/opencode
```

### AI features not working

Configure your LLM provider at https://opencode.ai/auth or add your API key. See the docs: https://opencode.ai/docs

## Additional Resources

- **Documentation**: https://opencode.ai/docs
- **CLI Reference**: https://opencode.ai/docs/cli/
- **GitHub**: https://github.com/anomalyco/opencode

## Support

For OpenCode-specific issues:
- Documentation: https://opencode.ai/docs
- GitHub: https://github.com/anomalyco/opencode

For DigitalOcean Droplet issues:
- DigitalOcean Support: https://www.digitalocean.com/support
- Community Tutorials: https://www.digitalocean.com/community

---

**Note**: This 1-Click installs OpenCode via the official install script. SSH is the only exposed port; there is no web interface.
