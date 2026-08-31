# OpenCode 1-Click Application

Deploy OpenCode, an open-source AI coding agent that runs in your terminal, pre-configured to use DigitalOcean Gradient AI for inference. Use natural language to write, debug, and refactor code. Code and context stay local by default.

## What is OpenCode?

OpenCode brings AI assistance into the command line. It's a terminal-based coding agent pre-configured with DigitalOcean Gradient AI, giving you access to Llama 3.3 70B, Qwen3, DeepSeek, and more using a single Gradient model access key.

- **Terminal-first** – Works natively in your shell, no web interface required
- **DigitalOcean Gradient AI** – Pre-configured with open-source models via Gradient inference
- **Intelligent Inference Router** – Optionally route each prompt to the best-fit model
- **Multiple sessions** – Run multiple agents for different tasks
- **File references** – Use `@filename` to include files in context
- **Shell commands** – Execute commands with `!` prefix
- **Slash commands** – `/init`, `/connect`, `/share` and more
- **Privacy-focused** – Code stays on your server by default

## Key Features

- Natural language coding assistance in the terminal
- Pre-configured with DigitalOcean Gradient AI (Claude, GPT, DeepSeek, Llama, and more)
- Optional DigitalOcean Intelligent Inference Router (`router:<name>`)
- Live model list at first login from `GET https://inference.do-ai.run/v1/models`
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

If you passed `GRADIENT_KEY` as a droplet environment variable, OpenCode is already configured — skip to step 4.

Otherwise, on first login the setup wizard will prompt for your DigitalOcean Gradient model access key. To create one:

1. Go to https://cloud.digitalocean.com/gen-ai/model-access-keys
2. Click **Create Model Access Key**
3. Copy the new key
4. Paste the key when prompted — the wizard then lists **current** chat models from the Gradient inference API (or `R` for the Intelligent Inference Router)

The wizard verifies your key, lets you pick a default model from that live list, and configures OpenCode automatically.

### 4. Run OpenCode

```bash
cd /path/to/your/project
opencode
```

The default model is the one you picked in the wizard (or the first chat-capable model from the live catalog if you auto-configured without `GRADIENT_MODEL`). Change it in `/root/.config/opencode/opencode.json` or use `/models` inside OpenCode. To use an Intelligent Inference Router, pick `R` in the setup wizard or set `DO_INFERENCE_ROUTER`.

## Managing OpenCode

### Helper Scripts

| Action | Command |
|--------|---------|
| Check version | `/opt/opencode-version.sh` |
| Update to latest | `/opt/update-opencode.sh` |
| Re-run setup wizard | `/opt/setup-opencode.sh` |
| Apply Gradient from env | `/opt/apply-gradient-from-env.sh` |

### Configuration

- **OpenCode config**: `/root/.config/opencode/opencode.json`
- **Auth / API key**: `/root/.local/share/opencode/auth.json`
- **Gradient env vars**: `/opt/opencode.env` (`GRADIENT_KEY`, `GRADIENT_MODEL`, `DO_INFERENCE_ROUTER`)
- **Getting started guide**: `cat /root/opencode_info.txt`

### Inference usage (Gradient)

API `usage` may list cache-related fields, but on DigitalOcean Gradient’s OpenAI-compatible inference they are **often zero** regardless of model. Treat **DigitalOcean billing and documentation** as the source of truth for charges. The same note is in `/root/opencode_info.txt`. If you add providers with `/connect`, their APIs define usage and any prompt-cache behavior.

### Available models

The image does **not** hardcode a model catalog. After you enter a Gradient model access key, the setup wizard (and `/opt/apply-gradient-from-env.sh`) load chat-capable models from:

```bash
curl -s -H "Authorization: Bearer $GRADIENT_KEY" \
  https://inference.do-ai.run/v1/models | jq -r '.data[].id'
```

See [Retrieve available models](https://docs.digitalocean.com/products/inference/how-to/retrieve-available-models/). Use `digitalocean/<id>` in OpenCode or in `"model"` in `opencode.json`. The Intelligent Inference Router is `digitalocean/router:<name>`.

To change the default model, edit `"model"` in `/root/.config/opencode/opencode.json` or re-run `/opt/setup-opencode.sh`.

### Intelligent Inference Router

DigitalOcean's Inference Router classifies each prompt and sends it to the best-fit model based on rules you define (optimizing for cost or latency).

1. Create a router under **Inference > Routers** in the control panel (or via the API) and attach it to the same model access key you use for the droplet.
2. Set `DO_INFERENCE_ROUTER=<router-name>` in `/opt/opencode.env` (or as a droplet env var) and run `/opt/apply-gradient-from-env.sh`, **or** enter the router name in the setup wizard (`R`).

This points OpenCode at `digitalocean/router:<router-name>` on `https://inference.do-ai.run/v1` and makes it the default. The router authenticates with the same `GRADIENT_KEY` as the direct models — no extra key needed.

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

Or manually edit `/root/.local/share/opencode/auth.json` — set `digitalocean` to `{"type": "api", "key": "<your key>"}`. Create keys at https://cloud.digitalocean.com/gen-ai/model-access-keys.

## Additional Resources

- **Documentation**: https://opencode.ai/docs
- **CLI Reference**: https://opencode.ai/docs/cli/
- **GitHub**: https://github.com/anomalyco/opencode
- **Retrieve available models**: https://docs.digitalocean.com/products/inference/how-to/retrieve-available-models/
- **DigitalOcean Inference Router**: https://docs.digitalocean.com/products/inference/how-to/use-inference-router/

## Support

For OpenCode-specific issues:
- Documentation: https://opencode.ai/docs
- GitHub: https://github.com/anomalyco/opencode

For DigitalOcean Droplet issues:
- DigitalOcean Support: https://www.digitalocean.com/support
- Community Tutorials: https://www.digitalocean.com/community

---

**Note**: This 1-Click installs OpenCode via the official install script and pre-configures DigitalOcean Gradient AI as the inference provider. SSH is the only exposed port; there is no web interface. Commercial models (Anthropic Claude, OpenAI GPT) are also available through Gradient but require their respective provider API keys configured in the DigitalOcean console.
