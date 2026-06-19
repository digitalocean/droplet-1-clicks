# Kilo Code CLI 1-Click Application

Deploy Kilo Code CLI, an open-source AI coding agent that runs in your terminal. Kilo helps you plan, write, debug, and refactor code from an SSH session, with optional DigitalOcean model access key setup.

## What is Kilo Code?

Kilo Code is an AI coding agent for terminal-first development workflows. It uses the same foundation as the Kilo IDE extension and provides a keyboard-first command-line experience for working on code directly on your Droplet.

## Key Features

- **Terminal-first AI agent** - Run `kilo` from any project directory
- **DigitalOcean model access key setup** - Optional helper saves `DIGITALOCEAN_ACCESS_TOKEN` for shell sessions
- **Agent modes** - Plan, debug, ask questions, and orchestrate coding work
- **Provider flexibility** - Start Kilo and configure providers from the CLI when needed
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

### 3. Optional DigitalOcean Model Access Key Setup

On first login, the setup helper asks for `DIGITALOCEAN_ACCESS_TOKEN`. If you do not have a token, press Enter to skip setup. Kilo starts automatically after the prompt either way.

Create a DigitalOcean model access key at https://cloud.digitalocean.com/model-studio/manage-keys, export it as `DIGITALOCEAN_ACCESS_TOKEN`, and apply it:

```bash
export DIGITALOCEAN_ACCESS_TOKEN=your_token_here
/opt/apply-digitalocean-token.sh
```

The helper stores the token for future shell sessions. If you do not have a token yet, skip this step and Kilo will still start.

### 4. Run Kilo Code Later

```bash
cd /path/to/your/project
kilo
```

## Managing Kilo Code

| Action | Command |
|--------|---------|
| Update Kilo Code | `/opt/update-kilocode.sh` |
| Re-run setup | `/opt/setup-kilocode.sh --force` |

## Configuration

- **DigitalOcean token env**: `DIGITALOCEAN_ACCESS_TOKEN`
- **Kilo provider env**: `KILO_PROVIDER_TYPE=digitalocean`
- **Getting started guide**: `cat /root/kilocode_info.txt`

## Troubleshooting

### Kilo not found in PATH

Open a new login shell or check the npm global binary path:

```bash
npm bin -g
```

### DigitalOcean inference is not working

Verify the token is available and re-apply it:

```bash
export DIGITALOCEAN_ACCESS_TOKEN=your_token_here
/opt/apply-digitalocean-token.sh
```

If you do not want to use a DigitalOcean model access key, start Kilo and
configure providers from inside the CLI when needed.

## Additional Resources

- **Documentation**: https://kilo.ai/docs
- **CLI Guide**: https://kilo.ai/docs/code-with-ai/platforms/cli
- **Install Guide**: https://kilo.ai/docs/getting-started/installing

---

**Note**: This 1-Click installs Kilo Code CLI via npm and includes optional DigitalOcean model access key setup. SSH is the only exposed port.
