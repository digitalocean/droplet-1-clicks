# DSH Superagent 1-Click

Packer builder for a DigitalOcean 1-Click image of
[dsh-superagent-prototype](https://github.com/deepseek-ai/dsh-superagent-prototype),
a proactive coding agent for one GitHub repository that runs on DeepSeek Harness.

## Validate and build

```sh
make validate-dsh-superagent-24-04
make build-dsh-superagent-24-04   # needs DIGITALOCEAN_API_TOKEN
```

## Pinned versions

All pins live in `template.json` variables:

| Variable | Value | Notes |
|----------|-------|-------|
| `dsh_superagent_commit` | `8c32a9dc5d72c033816c6a8110b37f40cf94fba4` | Upstream has no release tags; pin by commit (`main` at build time) |
| `application_version` | `0.1.0` | Upstream `package.json` version, shown on the image |
| `dsh_version` | `0.2.1-rc.3` | `@deepseek-ai/dsh`; within the upstream `engines.dsh` range |
| `pnpm_version` | `11.7.0` | Matches upstream `packageManager` |
| `node_version` | `24.x` | Upstream needs Node 22.19+ or 24 |
| `gh_version`, `gh_sha256` | `2.103.3` | GitHub CLI 2.48+ is required; checksum verified at build |

The build was checked locally against these pins (`pnpm install --frozen-lockfile`, `pnpm build`, profile creation and plugin link) on Node 24.14.1.

## Layout

```
dsh-superagent-24-04/
├── template.json
├── README.md
├── listing.md
├── scripts/
│   └── dsh-superagent.sh                 build: gh CLI, user, checkout, build, profile
└── files/
    ├── etc/
    │   ├── setup_wizard.sh               first-login setup (key, agent login, repo, settings)
    │   ├── profile.d/dsh-superagent-setup.sh   offers the wizard until it has run
    │   ├── systemd/system/dsh-superagent.service
    │   ├── systemd/system/dsh-superagent-check.{service,timer}
    │   ├── systemd/system/dsh-superagent-apply-inference.service
    │   └── update-motd.d/99-one-click
    ├── opt/dsh-superagent/
    │   ├── superagent-ctl.sh             runs the upstream control script as `superagent`
    │   ├── gh-agent                      GitHub CLI wrapper for the agent account only
    │   ├── profile.cordis.patch.yml      machine configuration
    │   ├── apply-inference-from-env.sh   DigitalOcean Serverless Inference
    │   ├── push-inference-model.sh       sets the eval and executor model
    │   ├── dsh-superagent-inference.env
    │   ├── start|stop|restart|status|update-dsh-superagent.sh
    │   └── check-dsh-superagent.sh       hourly recovery (restarts only on exit 1)
    └── var/lib/cloud/scripts/per-instance/001_onboot
```

## Design decisions

* **Dedicated user.** DSH runs as `superagent`, not `root`. The upstream notes that executors run with full access as the OS user, so the agent gets its own account and only its own credentials.
* **Panel on loopback, no Caddy.** The 1-Click guide asks for Caddy on HTTP UIs. This one deliberately does not: the upstream panel is designed for `127.0.0.1`, and its management API can change execution settings such as the executor's prepare command. Exposing it publicly would hand that control to anyone who can reach the URL. Operators reach it through an SSH tunnel instead, and UFW opens only SSH. Revisit this only with an authenticated proxy and a reviewed threat model.
* **No secrets at build time.** A DigitalOcean model access key or a DeepSeek API key, and the agent's GitHub login, are entered at first login or passed in the Droplet environment. Keys are stored under `/home/superagent/.config/dsh-superagent`. A key found in `/etc/environment` is moved out of that world-readable file.
* **DigitalOcean Inference.** `@deepseek-ai/dsh-llm-pi-ai` (same version as `dsh`) declares an OpenAI-compatible route, `digitalocean`, at `https://inference.do-ai.run/v1`. The model access key is `MODEL_ACCESS_KEY`. Eval and executor sessions use the chosen model. The built-in DeepSeek route is unchanged and remains the panel chat default.
* **Service wrapper.** The upstream control script starts DSH in tmux. A oneshot systemd unit wraps it. Exit codes 2 (part error) and 3 (waiting for setup) count as started, because a restart cannot fix them and the first boot always waits for setup.
* **Hourly check.** Restarts DSH only when `status` returns 1 and never after an intentional `stop`, following the upstream's own check.

## Operating notes

* The DSH log, which holds the panel's access token, is under `/home/superagent/dsh-superagent/.artifacts/`.
* Feishu is not configured. It needs a `lark-cli` bot setup described in the upstream docs.
* DSH is a research prototype (see the upstream README). Treat it that way.
