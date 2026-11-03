# Hermes Agent 1-Click Application

Hermes Agent, the self-improving AI agent built by Nous Research, runs on your machine or server and lets you chat with an AI assistant through the terminal, a TUI, or messaging platforms like Telegram, Discord, Slack, WhatsApp, Signal, and email. It is designed for long-running personal automation: it can remember context across sessions, use tools, create and improve skills, run scheduled jobs, and work from a cloud VM instead of being tied to your laptop.

On this Droplet, Hermes is installed for the dedicated `hermes` user. Start with:

```shell
hermes
```

To configure or change your model provider:

```shell
hermes setup
hermes model
```

For DigitalOcean Serverless Inference, use a model access key and the preconfigured endpoint [https://inference.do-ai.run/v1](https://inference.do-ai.run/v1). The first-login wizard loads the current chat-model catalog from that API. If you do not choose a model, it uses the first chat-model id in alphabetical order.

**Useful commands:**

```shell
hermes doctor          # diagnose setup issues
hermes gateway setup   # configure messaging platforms
hermes gateway start   # start the messaging gateway
hermes tools           # configure available tools
```

Update with `sudo /opt/hermes/update-hermes.sh`. That helper installs a GitHub release tag. A bare `hermes update` can fail on the image's tag checkout.

**Important paths:**

```shell
/home/hermes/.hermes/config.yaml
/home/hermes/.hermes/.env
/home/hermes/workspace
/opt/hermes/
```

**Tips:**

- Run `hermes doctor` after setup if anything feels off.
- Use `hermes model` to switch providers or models later.
- Use `hermes gateway setup` only if you want messaging integrations.
- Keep API keys in `/home/hermes/.hermes/.env`, not in shell history.

**Links:**

- Docs: [https://hermes-agent.nousresearch.com/docs/](https://hermes-agent.nousresearch.com/docs/)
- GitHub: [https://github.com/NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent)
- DigitalOcean Serverless Inference: [https://cloud.digitalocean.com/model-studio/serverless-inference](https://cloud.digitalocean.com/model-studio/serverless-inference)

## Getting Started

Follow these steps to get your Hermes Agent instance running as a Droplet on DigitalOcean.

### 1. Deploy the Droplet

- Deploy the **Hermes Agent 1-Click App** from the DigitalOcean Marketplace.
- Wait for the Droplet to finish provisioning.
- The DigitalOcean dashboard may say "ready" before SSH is available. If SSH fails, wait about 60 seconds and retry.

### 2. Connect via SSH

```bash
ssh root@your-droplet-ip
```

On first login, you will see the Hermes welcome message. If a model access key was not set at create time, the setup wizard runs automatically.

### 3. Configure Hermes

Hermes is installed for the dedicated `hermes` user. The first-login wizard asks you to choose:

1. DigitalOcean Serverless Inference
2. Hermes setup (`hermes setup`)

For Serverless Inference, create a model access key at [https://cloud.digitalocean.com/model-studio/manage-keys](https://cloud.digitalocean.com/model-studio/manage-keys), then pick a model from the live catalog.

### 4. Start Chatting

```shell
hermes
```

This starts an interactive Hermes Agent session in your terminal.

### 5. Verify Installation

Check Hermes health:

```shell
hermes doctor
```

Check template status:

```shell
/opt/hermes/status-hermes.sh
```

Check the configured model or provider:

```shell
hermes model
```

### 6. Configure DigitalOcean Serverless Inference Manually

Edit `/etc/environment` or `/opt/hermes/hermes.env` and set:

```shell
MODEL_ACCESS_KEY=your_model_access_key
INFERENCE_MODEL=minimax-m2.5
```

`INFERENCE_MODEL` is optional. Leave it empty to use the first chat-model id in alphabetical order. `minimax-m2.5` is an example model id, not a model baked into the image.

Apply the config:

```shell
sudo /opt/hermes/apply-inference-from-env.sh
```

Hermes writes provider secrets to `/home/hermes/.hermes/.env` and model config to `/home/hermes/.hermes/config.yaml`.

### 7. Configure Messaging Channels

Hermes can connect to messaging platforms such as Telegram, Discord, Slack, WhatsApp, Signal, and email.

```shell
hermes gateway setup
hermes gateway start
hermes gateway status
```

## Managing Hermes

Hermes is an interactive CLI. The messaging gateway is the long-running piece.

| Action | Command |
|--------|---------|
| Start a chat | `hermes` |
| Reconfigure | `hermes setup` or `sudo /etc/setup_wizard.sh --force` |
| Gateway status | `hermes gateway status` |
| Status | `/opt/hermes/status-hermes.sh` |
| Update to latest | `sudo /opt/hermes/update-hermes.sh` |
| Update to a release | `sudo /opt/hermes/update-hermes.sh v0.22.6` |
| Doctor | `/opt/hermes/doctor-hermes.sh` |
| Apply a key | `sudo /opt/hermes/apply-inference-from-env.sh` |
