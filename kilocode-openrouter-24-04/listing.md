# Kilo Code CLI (OpenRouter) 1-Click Application

Deploy [Kilo Code](https://openrouter.ai/apps/kilo-code) as an OpenRouter coding agent on your Droplet. Kilo helps you plan, write, debug, and refactor code from an SSH session using models available through OpenRouter.

## What is Kilo Code?

Kilo Code is an open-source AI coding agent for VS Code, JetBrains, and CLI. This 1-Click focuses on the terminal CLI and wires OpenRouter so usage can attribute to the official [Kilo Code OpenRouter app](https://openrouter.ai/apps/kilo-code).

## Key Features

- **OpenRouter coding agent** - Same Kilo Code agent tracked at https://openrouter.ai/apps/kilo-code
- **Terminal-first AI agent** - Run `kilo` from any project directory
- **OpenRouter API key setup** - Optional helper saves `OPENROUTER_API_KEY` for shell sessions
- **App attribution headers** - Config sets `HTTP-Referer` / title / `cli-agent,cloud-agent` categories per [OpenRouter app attribution](https://openrouter.ai/docs/app-attribution)
- **SSH only** - No public web interface is exposed by default

## System Requirements

Kilo Code is lightweight; most compute happens at the model provider.

| Use Case | RAM | CPU | Storage |
|----------|-----|-----|---------|
| Minimum | 1 GB | 1 vCPU | 25 GB |
| Recommended | 2 GB | 2 vCPU | 50 GB |

## Included System Components

- **Ubuntu 24.04 LTS** - Base operating system
- **Kilo Code CLI** - Installed from npm as `@kilocode/cli`
- **Node.js LTS** - Runtime for Kilo Code CLI
- **Git**, **curl**, **jq**, **unzip** - Common development utilities
- **UFW Firewall** - SSH only, rate-limited

## Getting Started

### 1. Deploy the Droplet

1. Select this 1-Click App from the DigitalOcean Marketplace
2. Choose a Droplet size
3. Add your SSH key for secure access
4. Create the Droplet

### 2. SSH In

```bash
ssh root@your-droplet-ip
```

### 3. Optional OpenRouter API Key Setup

On first login, the setup helper asks for `OPENROUTER_API_KEY`. If you do not have a key, press Enter to skip setup. Kilo starts automatically after the prompt either way.

Create an OpenRouter API key at https://openrouter.ai/keys, export it as `OPENROUTER_API_KEY`, and apply it:

```bash
export OPENROUTER_API_KEY=your_key_here
/opt/apply-openrouter-token.sh
```

The helper stores the key for future shell sessions. OpenRouter attribution headers ship in `/root/.config/kilo/kilo.jsonc` at image build time. If you do not have a key yet, skip this step and Kilo will still start.

### 4. Run Kilo Code Later

```bash
cd /path/to/your/project
kilo
```

## Managing Kilo Code

| Action | Command |
|--------|---------|
| Start Kilo | `kilo` |
| Stop Kilo | `Ctrl+C` or exit the CLI session |
| Update Kilo Code | `/opt/update-kilocode.sh` |
| Re-run setup | `/opt/setup-kilocode-openrouter.sh --force` |

## Configuration

- **OpenRouter key env**: `OPENROUTER_API_KEY`
- **Kilo provider env**: `KILO_PROVIDER_TYPE=openrouter`
- **Kilo config**: `/root/.config/kilo/kilo.jsonc`
- **OpenRouter app**: https://openrouter.ai/apps/kilo-code
- **Getting started guide**: `cat /root/kilocode_info.txt`

## Troubleshooting

### Kilo not found in PATH

Open a new login shell or check the npm global binary path:

```bash
npm bin -g
```

### OpenRouter inference is not working

Verify the key is available and re-apply it:

```bash
export OPENROUTER_API_KEY=your_key_here
/opt/apply-openrouter-token.sh
```

Ensure your OpenRouter account has credits for the models you select. See https://openrouter.ai/apps/kilo-code for Kilo Code usage on OpenRouter.

## Additional Resources

- **Kilo Code on OpenRouter**: https://openrouter.ai/apps/kilo-code
- **OpenRouter app attribution**: https://openrouter.ai/docs/app-attribution
- **OpenRouter with Kilo docs**: https://kilo.ai/docs/ai-providers/openrouter
- **OpenRouter keys**: https://openrouter.ai/keys
- **CLI Guide**: https://kilo.ai/docs/code-with-ai/platforms/cli

---

**Note**: This 1-Click installs Kilo Code CLI via npm and includes optional OpenRouter API key setup for the Kilo Code agent. SSH is the only exposed port.
