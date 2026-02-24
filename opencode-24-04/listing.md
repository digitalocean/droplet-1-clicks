# OpenCode 1-Click Application

Deploy OpenCode, an open-source AI coding agent that runs in your terminal, pre-configured to use DigitalOcean Gradient AI for inference. Use natural language to write, debug, and refactor code. Code and context stay local by default.

## What is OpenCode?

OpenCode brings AI assistance into the command line. It's a terminal-based coding agent pre-configured with DigitalOcean Gradient AI, giving you access to Llama 3.3 70B, Qwen3, DeepSeek, and more using a single Gradient model access key.

- **Terminal-first** – Works natively in your shell, no web interface required
- **DigitalOcean Gradient AI** – Pre-configured with open-source models via Gradient inference
- **Multiple sessions** – Run multiple agents for different tasks
- **File references** – Use `@filename` to include files in context
- **Shell commands** – Execute commands with `!` prefix
- **Slash commands** – `/init`, `/connect`, `/share` and more
- **Privacy-focused** – Code stays on your server by default

## Key Features

- Natural language coding assistance in the terminal
- Pre-configured with DigitalOcean Gradient AI (Claude, GPT, DeepSeek, Llama, and more)
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
- **OpenCode** – AI coding agent (version 1.2.6)
- **DigitalOcean Gradient AI** – Pre-configured inference provider
- **Git** – Version control
- **UFW Firewall** – SSH only (rate-limited)

## Getting Started

### 1. Deploy the Droplet

1. Select this 1-Click App from the DigitalOcean Marketplace
2. Choose a Droplet size (1 GB RAM minimum)
3. Add your SSH key for secure access
4. Create the Droplet

### 2. SSH In

```bash
ssh root@your-droplet-ip
```

### 3. Complete the Setup Wizard

On first login, the setup wizard will prompt for your DigitalOcean Gradient model access key. To create one:

1. Go to https://cloud.digitalocean.com/gen-ai/model-access-keys
2. Click **Create Model Access Key**
4. Paste the key when prompted by the setup wizard

The wizard verifies your key and configures OpenCode automatically.

### 4. Run OpenCode

```bash
cd /path/to/your/project
opencode
```

The default model is **Claude Sonnet 4.5** (via DigitalOcean Gradient). You can change it in `/root/.config/opencode/opencode.json` or use the `/models` command inside OpenCode.

## Managing OpenCode

### Helper Scripts

| Action | Command |
|--------|---------|
| Check version | `/opt/opencode-version.sh` |
| Update to latest | `/opt/update-opencode.sh` |
| Re-run setup wizard | `/opt/setup-opencode.sh` |

### Configuration

- **OpenCode config**: `/root/.config/opencode/opencode.json`
- **Auth / API key**: `/root/.local/share/opencode/auth.json`
- **Getting started guide**: `cat /root/opencode_info.txt`

### Pre-Configured Models

The following top-rated coding models are available via DigitalOcean Gradient (only a Gradient model access key is required):

| Model | ID | Provider |
|-------|----|----------|
| Claude Opus 4.6 | `anthropic-claude-opus-4.6` | Anthropic |
| Claude Opus 4.5 | `anthropic-claude-opus-4.5` | Anthropic |
| Claude Sonnet 4.5 (default) | `anthropic-claude-4.5-sonnet` | Anthropic |
| Claude Sonnet 4 | `anthropic-claude-sonnet-4` | Anthropic |
| Claude 3.7 Sonnet | `anthropic-claude-3.7-sonnet` | Anthropic |
| GPT-5.2 | `openai-gpt-5.2` | OpenAI |
| GPT-5 | `openai-gpt-5` | OpenAI |
| GPT-5.1 Codex Max | `openai-gpt-5.1-codex-max` | OpenAI |
| GPT-4.1 | `openai-gpt-4.1` | OpenAI |
| o3 | `openai-o3` | OpenAI |
| DeepSeek R1 Distill Llama 70B | `deepseek-r1-distill-llama-70b` | DeepSeek |
| Qwen3 32B | `alibaba-qwen3-32b` | Alibaba |
| Llama 3.3 70B Instruct | `llama3.3-70b-instruct` | Meta |

To change the default model, edit `"model"` in `/root/.config/opencode/opencode.json`.

### Using OpenCode's Built-in Providers

If you prefer to use OpenCode's standard providers (Anthropic, OpenAI, Google, etc.) with your own API keys instead of Gradient, skip the setup wizard by pressing Enter, then use the `/connect` command inside OpenCode to add your API keys for any of 75+ supported providers.

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

Re-run the setup wizard to reconfigure your Gradient model access key:

```bash
/opt/setup-opencode.sh
```

Or manually edit `/root/.local/share/opencode/auth.json` with a valid key. You can create a new key at https://cloud.digitalocean.com/gen-ai/model-access-keys.

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

**Note**: This 1-Click installs OpenCode via the official install script and pre-configures DigitalOcean Gradient AI as the inference provider. SSH is the only exposed port; there is no web interface. Commercial models (Anthropic Claude, OpenAI GPT) are also available through Gradient but require their respective provider API keys configured in the DigitalOcean console.
