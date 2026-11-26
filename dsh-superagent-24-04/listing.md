# DSH Superagent 1-Click Application

DSH Superagent is a proactive coding agent for one GitHub repository. It runs on DeepSeek Harness (DSH), and it listens for requests on GitHub: when someone on the allowed list mentions the agent in an Issue or comment, it opens a work item, works on it in its own session and checkout, and replies in the same conversation, for example with a pull request. A web panel shows what needs a person.

The agent acts only when asked, or when a rule your team wrote allows it, and it speaks only when someone must act or can use a result.

This 1-Click runs the upstream [dsh-superagent-prototype](https://github.com/deepseek-ai/dsh-superagent-prototype) research prototype. It is not an official DeepSeek product and is not production-ready software. Review it before you rely on it.

## System components

* **DSH Superagent** (upstream commit `8c32a9d`), installed from the public repository and built on the Droplet
* **DeepSeek Harness** CLI `@deepseek-ai/dsh` 0.2.1-rc.3, with a dedicated `superagent` profile that serves the panel on `127.0.0.1:3082`
* **DigitalOcean Serverless Inference**, optional, through the OpenAI-compatible gateway at `https://inference.do-ai.run/v1`
* **Node.js 24** and **pnpm 11.7.0**
* **GitHub CLI** 2.103.3, used only through a wrapper that signs in as the agent account
* **git** and **tmux**
* **systemd** units for the service and for an hourly recovery check
* **UFW** (SSH only) and **fail2ban**

## System requirements

| Item | Recommendation |
|------|----------------|
| Droplet size | 2 vCPU and 4 GB RAM or more. The runtime keeps several agent sessions in memory. |
| Accounts | A DigitalOcean model access key or a DeepSeek API key, a GitHub account dedicated to the agent, and a GitHub repository the agent may write to |
| Network | Outbound HTTPS to GitHub and to `https://inference.do-ai.run` or the DeepSeek API. The panel is not exposed publicly. |

## Getting started

### 1. Deploy the Droplet

* Deploy the **DSH Superagent 1-Click App** from the DigitalOcean Marketplace.
* Wait for the Droplet to finish provisioning. If SSH fails right away, wait about 60 seconds and try again.

### 2. Connect and run the setup wizard

```shell
ssh root@your-droplet-ip
```

On your first login the setup wizard starts. It asks for:

1. A model provider. **DigitalOcean Serverless Inference** is the default. Create a model access key at [https://cloud.digitalocean.com/model-studio/manage-keys](https://cloud.digitalocean.com/model-studio/manage-keys). The wizard lists the chat models that key can use. You can choose a DeepSeek API key instead.

To configure Inference when you create the Droplet, set `MODEL_ACCESS_KEY` in the Droplet environment. `INFERENCE_MODEL` and `DO_INFERENCE_ROUTER` are optional. The key is copied into the `superagent` user's environment and removed from `/etc/environment`. Eval and executor sessions then use that model. The panel's own chat still uses the DeepSeek default until you change it under Settings, then Models.
2. The **agent's GitHub account**. Sign in as the dedicated agent account, not as yourself. The wizard shows a one-time code to enter in a browser.
3. The **repository** as `owner/name`. The wizard then asks you to invite the agent account with write access and accept the invitation as that account. It checks access before it continues.
4. Your **GitHub login**, or the logins that may ask the agent for work. Only these accounts can create work.

The wizard then starts the service, saves its settings, and tells you what to do next. You can run it again at any time with `sudo /etc/setup_wizard.sh --force`.

### 3. Open the panel

The panel listens on `127.0.0.1` only. From your computer, open an SSH tunnel:

```shell
ssh -L 3082:127.0.0.1:3082 root@your-droplet-ip
```

Then run this on the Droplet and open the URL it prints in your browser:

```shell
/opt/dsh-superagent/status-dsh-superagent.sh
```

The access token in the URL changes each time the service starts. Choose **Superagent** in the sidebar.

### 4. Try it

From an allowed GitHub account, comment on an Issue in your repository:

```
@your-agent-login please add a unit test for the parser
```

A Ticket appears on the panel's Overview within about a minute. The agent works in its own checkout and replies in the same thread.

## Start, stop, restart and update

| Action | Command |
|--------|---------|
| Status and exit codes | `/opt/dsh-superagent/status-dsh-superagent.sh` |
| Start | `/opt/dsh-superagent/start-dsh-superagent.sh` |
| Stop (graceful, up to 5 minutes) | `/opt/dsh-superagent/stop-dsh-superagent.sh` |
| Restart | `/opt/dsh-superagent/restart-dsh-superagent.sh` |
| Update to another upstream commit or tag | `sudo /opt/dsh-superagent/update-dsh-superagent.sh <commit-or-tag>` |
| Change the repository, allowed users, or model | `sudo /etc/setup_wizard.sh --force` |
| Apply a model access key from the environment | `sudo /opt/dsh-superagent/apply-inference-from-env.sh` |

A stop is intentional: the hourly check does not restart the service until you start it again. The update helper stops the service, backs up the database, checks out the new revision, rebuilds it and starts it again.

The DSH process runs as the dedicated `superagent` user, not `root`. Systemd manages it through `dsh-superagent.service`, and the hourly check runs from `dsh-superagent-check.timer`.
