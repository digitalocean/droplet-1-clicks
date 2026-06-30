# Grok Build 1-Click Application

Deploy Grok Build, xAI's terminal-native AI coding agent, pre-configured to run on **DigitalOcean Serverless Inference**. SSH in and run `grok` to plan, write, review, and refactor code directly from your shell — no IDE required, and no separate model subscription needed.

## What is Grok Build?

Grok Build is a command-line coding agent (with an interactive terminal UI) from xAI. Describe what you want in natural language and Grok plans the work, edits files, runs commands, and shows clean diffs for review. This image wires Grok Build to DigitalOcean's OpenAI-compatible serverless inference endpoint, so a single model access key unlocks GPT-5.5, Claude, Llama, Kimi, GLM, DeepSeek, Qwen, MiniMax and more — plus DigitalOcean's Intelligent Inference Router.

- **Terminal-first** – Works natively in your shell; no web interface required
- **DigitalOcean Serverless Inference** – Pre-configured inference with one model access key
- **Intelligent Inference Router** – Optionally route each prompt to the best-fit model
- **Plan mode** – Generate a plan, comment on or rewrite steps, then approve before changes
- **Parallel subagents** – Delegate large tasks to subagents that run in parallel
- **Headless mode** – Run agents non-interactively in scripts with `grok -p`
- **Works with your conventions** – Picks up `AGENTS.md`, plugins, hooks, skills, and MCP servers

## Key Features

- Natural-language, agentic coding assistance in the terminal
- Pre-configured with DigitalOcean Serverless Inference (GPT, Claude, Llama, DeepSeek, and more)
- Optional DigitalOcean Intelligent Inference Router (`router:<name>`)
- Plan / review / approve workflow with clean diffs
- Headless scripting (`-p`) with `plain`, `json`, and `streaming-json` output
- xAI account sign-in supported as an alternative provider

## System Requirements

Grok Build is lightweight; most compute happens at the inference service.

| Use Case | RAM | CPU | Storage |
|----------|-----|-----|---------|
| Minimum | 1 GB | 1 vCPU | 25 GB |
| Recommended | 2 GB | 2 vCPU | 50 GB |

## Included System Components

- **Ubuntu 24.04 LTS** – Base operating system
- **Grok Build** – xAI terminal coding agent (version 0.2.51)
- **DigitalOcean Serverless Inference** – Pre-configured inference provider
- **Git** – Version control
- **curl**, **jq**, **unzip** – Utilities
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

On first login, the setup wizard prompts for your **DigitalOcean model access key**. To create one:

1. Go to <https://cloud.digitalocean.com/model-studio/manage-keys>
2. Or from the cloud console, navigate to **Inference > Manage**
3. Click **Create Model Access Key** and copy it
4. Paste it when prompted, then **pick your default model from the list** (or choose the Intelligent Inference Router)

The wizard verifies the key against `https://inference.do-ai.run/v1` and configures Grok Build automatically. You can change the model later with `/model` in the TUI or `-m <alias>`.

Prefer to use xAI directly? Press Enter at the model-access-key prompt to choose **xAI account sign-in** or to enter an **xAI API key**.

> **No browser needed.** With a model access key (or any API key), Grok authenticates with the API directly — there is no OAuth browser step. Because the droplet has no desktop browser, the xAI account path uses **device-code sign-in** (`/opt/grok-login.sh`), which shows a short URL and code to open on your laptop or phone. Avoid running a bare `grok login`, which would try to launch a local browser.

### 4. Run Grok Build

```bash
cd /path/to/your/project
grok
```

For automation:

```bash
grok -p "Explain this codebase"
grok -p "Review this diff" --output-format json --always-approve
```

The default model is **GPT-5.5** (`gpt-5-5` via DigitalOcean Serverless Inference). Switch with `/model` in the TUI or `-m <alias>` headlessly.

## Pre-Configured Models

All models below are available via DigitalOcean Serverless Inference with just a model access key. The setup wizard lets you pick the default from this list (or a router). Switch any time with the alias via `-m` or `/model`; configuration lives in `/root/.grok/config.toml`.

| Alias | Model | ID |
|-------|-------|----|
| `gpt-5-5` (default) | GPT-5.5 | `openai-gpt-5.5` |
| `gpt-5-4` | GPT-5.4 | `openai-gpt-5.4` |
| `gpt-5-3-codex` | GPT-5.3 Codex | `openai-gpt-5.3-codex` |
| `gpt-5-2` | GPT-5.2 | `openai-gpt-5.2` |
| `gpt-5-1-codex-max` | GPT-5.1 Codex Max | `openai-gpt-5.1-codex-max` |
| `gpt-5` | GPT-5 | `openai-gpt-5` |
| `gpt-4-1` | GPT-4.1 | `openai-gpt-4.1` |
| `claude-opus-4-8` | Claude Opus 4.8 | `anthropic-claude-opus-4.8` |
| `claude-opus-4-6` | Claude Opus 4.6 | `anthropic-claude-opus-4.6` |
| `claude-sonnet-4-6` | Claude Sonnet 4.6 | `anthropic-claude-4.6-sonnet` |
| `claude-sonnet-4-5` | Claude Sonnet 4.5 | `anthropic-claude-4.5-sonnet` |
| `claude-haiku-4-5` | Claude Haiku 4.5 | `anthropic-claude-haiku-4.5` |
| `deepseek-v4-pro` | DeepSeek V4 Pro | `deepseek-v4-pro` |
| `deepseek-4-flash` | DeepSeek 4 Flash | `deepseek-4-flash` |
| `kimi-k2-6` | Kimi K2.6 | `kimi-k2.6` |
| `minimax-m2-5` | MiniMax M2.5 | `minimax-m2.5` |
| `glm-5` | GLM-5 | `glm-5` |
| `qwen3-coder-flash` | Qwen3 Coder Flash | `qwen3-coder-flash` |
| `qwen3-5` | Qwen3.5 397B | `qwen3.5-397b-a17b` |
| `llama-4-maverick` | Llama 4 Maverick | `llama-4-maverick` |
| `nemotron-3-super-120b` | NVIDIA Nemotron 3 Super 120B | `nvidia-nemotron-3-super-120b` |
| `router` | DigitalOcean Intelligent Inference Router | `router:<name>` |

DigitalOcean's serverless catalog grows over time. List the live set on the droplet with:

```bash
curl -s -H "Authorization: Bearer $MODEL_ACCESS_KEY" \
  https://inference.do-ai.run/v1/models | jq -r '.data[].id'
```

To use a model that isn't pre-configured, add a `[model.<alias>]` block to `/root/.grok/config.toml` (copy an existing DigitalOcean entry and change `model` to the catalog ID).

## Intelligent Inference Router

DigitalOcean's Inference Router classifies each prompt and sends it to the best-fit model based on rules you define (optimizing for cost or latency).

1. Create a router under **Inference > Routers** in the control panel (or via the API) and attach it to the same model access key you use for the droplet.
2. Set `DO_INFERENCE_ROUTER=<router-name>` in `/opt/grok-build.env` (or as a droplet env var) and run `/opt/apply-inference-from-env.sh`, **or** enter the router name in the setup wizard.

This points the `router` alias at `router:<router-name>` on `https://inference.do-ai.run/v1` and makes it the default. The router authenticates with the same `MODEL_ACCESS_KEY` as the direct models — no extra key needed. Using the router is a drop-in replacement for a specific model.

## Managing Grok Build

### Helper Scripts

| Action | Command |
|--------|---------|
| Check version | `grok --version` |
| Update to latest | `/opt/update-grok-build.sh` |
| Re-run setup wizard | `/opt/setup-grok-build.sh` |
| Sign in with xAI account (no browser) | `/opt/grok-login.sh` |

### Configuration

- **Grok config**: `/root/.grok/config.toml`
- **API key env template**: `/opt/grok-build.env`
- **Active key**: `/etc/profile.d/grok-build-key.sh` (`MODEL_ACCESS_KEY` or `XAI_API_KEY`)
- **Getting started guide**: `cat /root/grok_build_info.txt`

## Start, Stop, Restart, and Update

Grok Build is an interactive CLI, not a long-running background service, so there is no daemon to start, stop, or restart.

- **Start** a session: `grok` (or `grok -p "..."` for headless)
- **Stop** a session: exit the TUI (`Ctrl-C` / `/exit`) or end the headless command
- **Restart**: simply run `grok` again
- **Update**: `/opt/update-grok-build.sh` (re-runs the official installer for the latest stable release)

## Troubleshooting

### `grok` not found in PATH

Ensure you're in a login shell (SSH session) where PATH is set, or run directly:

```bash
/root/.grok/bin/grok
```

### AI features not working

Re-run the setup wizard to reconfigure your DigitalOcean model access key:

```bash
/opt/setup-grok-build.sh
```

Or set the key manually and reload your shell:

```bash
echo 'export MODEL_ACCESS_KEY="<your key>"' > /etc/profile.d/grok-build-key.sh
chmod 600 /etc/profile.d/grok-build-key.sh
```

Create keys at <https://cloud.digitalocean.com/model-studio/manage-keys> (Inference > Manage).

## Additional Resources

- **Grok Build docs**: <https://docs.x.ai/build/overview>
- **Custom models reference**: <https://docs.x.ai/build/overview#custom-models>
- **DigitalOcean Inference Router**: <https://docs.digitalocean.com/products/inference/how-to/use-inference-router/>
- **Announcement**: <https://x.ai/news/grok-build-cli>

## Support

For Grok Build-specific issues:
- Documentation: <https://docs.x.ai/build/overview>
- Send feedback from inside the CLI with `/feedback`

For DigitalOcean Droplet issues:
- DigitalOcean Support: <https://www.digitalocean.com/support>
- Community Tutorials: <https://www.digitalocean.com/community>

---

**Note**: This 1-Click installs Grok Build via the official xAI installer and pre-configures DigitalOcean Serverless Inference as the inference provider. SSH is the only exposed port; there is no web interface. You can alternatively authenticate with an xAI account (SuperGrok / X Premium+) or an xAI API key.
