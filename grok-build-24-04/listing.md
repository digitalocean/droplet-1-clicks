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
- **curl**, **jq**, **python3**, **unzip** – Utilities
- **UFW Firewall** – SSH only (rate-limited)

## Getting Started

### 1. Deploy the Droplet

1. Select this 1-Click App from the DigitalOcean Marketplace
2. Choose a Droplet size (1 GB RAM minimum)
3. Add your SSH key for secure access
4. Create the Droplet

Optional: pass `MODEL_ACCESS_KEY` (and optionally `DO_INFERENCE_MODEL` or `DO_INFERENCE_ROUTER`) as droplet environment variables to skip the wizard.

### 2. SSH In

```bash
ssh root@your-droplet-ip
```

### 3. Complete the Setup Wizard

If you passed `MODEL_ACCESS_KEY` at create time, Grok Build is already configured — skip to step 4.

Otherwise, on first login the setup wizard prompts for your **DigitalOcean model access key**. To create one:

1. Go to <https://cloud.digitalocean.com/model-studio/manage-keys>
2. Or from the cloud console, navigate to **Inference > Manage**
3. Click **Create Model Access Key** and copy it
4. Paste it when prompted — the wizard then lists **current** chat models from `GET https://inference.do-ai.run/v1/models`
5. Pick a default from that live list, or `R` for the Intelligent Inference Router

The wizard verifies the key against the inference API, rebuilds the DigitalOcean entries in `/root/.grok/config.toml` from that live list, and sets the default. If the key is rejected you can re-enter it, or type a model id to continue without a live list. Change the model later with `/model` in the TUI or `-m <alias>`.

Prefer to use xAI directly? Press Enter at the model-access-key prompt to choose **xAI account sign-in** or to enter an **xAI API key**.

> **No browser needed.** With a model access key (or any API key), Grok authenticates with the API directly — there is no OAuth browser step. Because the droplet has no desktop browser, the xAI account path uses **device-code sign-in** (`/opt/grok-login.sh` or `grok login --device-auth`), which shows a short URL and code to open on your laptop or phone. Avoid running a bare `grok login`, which would try to launch a local browser.

If `grok` reports no API key in the same session right after setup (or in a non-login shell), load it with `source /etc/profile.d/grok-build-key.sh`.

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

The default model is the one you picked in the wizard. If you auto-configured without `DO_INFERENCE_MODEL`, apply prefers **GPT-5.5** (`openai-gpt-5.5` / alias `gpt-5-5`) when that id is still in the live catalog; otherwise it uses the first chat-capable model returned by the API. Switch with `/model` in the TUI or `-m <alias>` headlessly.

## Models

The image does **not** pin a marketplace catalog. After you enter a model access key, the setup wizard (and `/opt/apply-inference-from-env.sh`) load chat-capable models from [Retrieve available models](https://docs.digitalocean.com/products/inference/how-to/retrieve-available-models/) and rewrite the DigitalOcean `[model.*]` block in `/root/.grok/config.toml`. New models appear and deprecated ones drop off. Existing aliases (for example `gpt-5-5`) are kept when that id is still available. Pick `R` for the Intelligent Inference Router.

List the live set on the droplet with:

```bash
curl -s -H "Authorization: Bearer $MODEL_ACCESS_KEY" \
  https://inference.do-ai.run/v1/models | jq -r '.data[].id'
```

Use the alias from `config.toml` with `-m` or `/model`. The router alias is `router` (`router:<name>`). Re-run `/opt/apply-inference-from-env.sh` or the setup wizard after new models ship. To add a provider that is not on Serverless Inference, uncomment a `[model.<alias>]` example at the bottom of `/root/.grok/config.toml`.

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
| Apply inference from env | `/opt/apply-inference-from-env.sh` |
| Sign in with xAI account (no browser) | `/opt/grok-login.sh` |

### Configuration

- **Grok config**: `/root/.grok/config.toml`
- **API key env template**: `/opt/grok-build.env` (`MODEL_ACCESS_KEY`, `DO_INFERENCE_MODEL`, `DO_INFERENCE_ROUTER`, `XAI_API_KEY`)
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

Then `source /etc/profile.d/grok-build-key.sh` (or start a new SSH session). Create keys at <https://cloud.digitalocean.com/model-studio/manage-keys> (Inference > Manage).

## Additional Resources

- **Grok Build docs**: <https://docs.x.ai/build/overview>
- **Custom models reference**: <https://docs.x.ai/build/overview#custom-models>
- **Retrieve available models**: <https://docs.digitalocean.com/products/inference/how-to/retrieve-available-models/>
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
