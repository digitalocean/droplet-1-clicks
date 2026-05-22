# Codex CLI 1-Click Application

Deploy Codex CLI, OpenAI's terminal-based coding agent, pre-configured to use DigitalOcean Gradient AI for inference. Use natural language to write, debug, and refactor code. Code and context stay on your server.

## What is Codex CLI?

Codex CLI brings OpenAI's coding agent into your terminal. It can read, edit, and run code in your project directory. This droplet is pre-configured with DigitalOcean Gradient AI, giving you access to GPT, Claude, DeepSeek, Llama, Kimi, and more using a single Gradient model access key.

- **Terminal-first** – Native TUI in your shell, no web interface required
- **DigitalOcean Gradient AI** – Pre-configured inference via Gradient
- **Subagents** – Parallelize complex tasks with subagents
- **Sandboxed execution** – Controlled filesystem and network access
- **MCP support** – Connect third-party tools via Model Context Protocol
- **Scriptable** – Automate workflows with `codex exec`

## Key Features

- Natural language coding assistance in the terminal
- Pre-configured with DigitalOcean Gradient AI
- Works with existing projects—navigate, edit, and run code
- No IDE required—pure terminal workflow
- Optional ChatGPT subscription auth via `codex login`

## System Requirements

Codex CLI is lightweight; most compute happens at the inference provider.

| Use Case | RAM | CPU | Storage |
|----------|-----|-----|---------|
| Minimum | 1 GB | 1 vCPU | 25 GB |
| Recommended | 2 GB | 2 vCPU | 50 GB |

## Included System Components

- **Ubuntu 24.04 LTS** – Base operating system
- **Codex CLI** – OpenAI terminal coding agent (version 0.133.0)
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
3. Copy the new key
4. Paste the key when prompted by the setup wizard

The wizard verifies your key and configures Codex CLI automatically.

### 4. Run Codex CLI

```bash
cd /path/to/your/project
codex
```

The default model is **GPT-5.1 Codex Max** (`openai-gpt-5.1-codex-max`). Change it with `codex -m "openai-gpt-5.2"` or the `/model` command inside Codex.

## Managing Codex CLI

### Helper Scripts

| Action | Command |
|--------|---------|
| Check version | `/opt/codex-cli-version.sh` |
| Update to latest | `/opt/update-codex-cli.sh` |
| Re-run setup wizard | `/opt/setup-codex-cli.sh` |

### Configuration

- **Codex config**: `/root/.codex/config.toml`
- **API key**: `/root/.codex/env` (`MODEL_ACCESS_KEY`)
- **Getting started guide**: `cat /root/codex_cli_info.txt`

### Available Models

Use model IDs from the Gradient Model Catalog with `codex -m "<model-id>"` or edit `model` in `/root/.codex/config.toml`.

| Model | Model ID |
|-------|----------|
| GPT-5.1 Codex Max (default) | `openai-gpt-5.1-codex-max` |
| GPT-5.2 | `openai-gpt-5.2` |
| GPT-5 | `openai-gpt-5` |
| GPT-4.1 | `openai-gpt-4.1` |
| OpenAI o3 | `openai-o3` |
| DeepSeek R1 Distill Llama 70B | `deepseek-r1-distill-llama-70b` |
| Qwen3 32B | `alibaba-qwen3-32b` |
| Llama 3.3 70B Instruct | `llama3.3-70b-instruct` |
| Kimi K2.5 | `kimi-k2.5` |
| glm-5 | `glm-5` |
| MiniMax M2.5 | `minimax-m2.5` |
| Claude Opus 4.6 | `anthropic-claude-opus-4-6` |
| Claude Sonnet 4.5 | `anthropic-claude-4.5-sonnet` |

List all available models:

```bash
curl -s -H "Authorization: Bearer $MODEL_ACCESS_KEY" \
  https://inference.do-ai.run/v1/models | jq '.data[].id'
```

### Using ChatGPT Subscription Auth

If you prefer ChatGPT Plus/Pro/Business subscription auth instead of Gradient:

1. Skip the setup wizard (press Enter)
2. Run `codex login` and follow the OAuth flow

## Updating

To update Codex CLI to the latest version:

```bash
/opt/update-codex-cli.sh
```

## Troubleshooting

### Codex not found in PATH

Run directly:

```bash
/usr/local/bin/codex
```

### Auth error or 401

Re-run the setup wizard:

```bash
/opt/setup-codex-cli.sh
```

Or verify your key is exported:

```bash
echo $MODEL_ACCESS_KEY
source /root/.codex/env
```

### Model not found or 404

Retrieve current model IDs from the Gradient API and update `model` in `/root/.codex/config.toml`.

## Additional Resources

- **Documentation**: https://developers.openai.com/codex/cli
- **Config reference**: https://developers.openai.com/codex/config-basic
- **Gradient + Codex guide**: https://docs.digitalocean.com/products/inference/how-to/use-with-coding-agents/
- **GitHub**: https://github.com/openai/codex

## Support

For Codex CLI-specific issues:

- Documentation: https://developers.openai.com/codex/cli
- GitHub: https://github.com/openai/codex

For DigitalOcean Droplet issues:

- DigitalOcean Support: https://www.digitalocean.com/support
- Community Tutorials: https://www.digitalocean.com/community

---

**Note**: This 1-Click installs Codex CLI from official GitHub releases and pre-configures DigitalOcean Gradient AI as the inference provider. SSH is the only exposed port; there is no web interface.
