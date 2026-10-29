# T3 Code 1-Click Droplet Builder

Packer builder for a DigitalOcean Marketplace image that runs [T3 Code](https://t3.codes/) on Ubuntu 24.04.

## Overview

T3 Code is an open-source control plane for coding agents. This image installs the official `t3` CLI (not a third-party container), binds `t3 serve` to `127.0.0.1:3773`, and publishes it with Caddy. The native provider CLIs are installed for the `t3` user. DigitalOcean Serverless Inference is optional. When a model access key is set, it is configured as the DigitalOcean Inference provider.

There is no official T3 Code Docker image. The install follows `https://t3.codes/install.sh`. `template.json` sets `application_version` to `latest`, and the build resolves that to the current stable T3 Code release.

## Directory structure

```
t3code-24-04/
├── template.json
├── README.md
├── listing.md
├── scripts/
│   └── 010-t3code.sh
└── files/
    ├── etc/
    │   ├── caddy/Caddyfile.tmp
    │   ├── setup_wizard.sh
    │   ├── systemd/system/t3code.service
    │   ├── systemd/system/t3code-apply-inference.service
    │   └── update-motd.d/99-one-click
    ├── opt/
    │   ├── t3code.env
    │   ├── t3code-inference.env
    │   ├── t3code-settings.json
    │   ├── apply-inference-from-env.sh
    │   ├── create-t3code-pairing.sh
    │   ├── ensure-t3code-swap.sh
    │   ├── retry-apply-inference-after-cloud-init.sh
    │   ├── setup-t3code-domain.sh
    │   ├── start-t3code.sh
    │   ├── stop-t3code.sh
    │   ├── restart-t3code.sh
    │   ├── status-t3code.sh
    │   └── update-t3code.sh
    └── var/lib/cloud/scripts/per-instance/001_onboot
```

## Versions

`template.json` sets the version variables to `latest`. During the image build, `scripts/010-t3code.sh` resolves them from the T3 Code release being installed:

- T3 Code itself is the current stable GitHub release, unless `application_version` is set to a specific release.
- Claude, Codex, OpenCode, Pi, and fx are the newest release inside that T3 Code version's compatibility range (`model-manifest.json`).
- Cursor and Grok use their current installers, then the build rejects them if they fall outside that range.
- Antigravity's version and checksums come from that T3 Code release's `antigravityRelease.ts`. That file is the binary T3 Code installs. A `recommendedRange` in `model-manifest.json` can name an older build; this image follows the release file and rejects any other version.
- Node.js is the current Node 22 release. The build rejects anything older than 22.23.4 (CVE-2026-111497). Pi needs 22.19.0, so that floor covers it.

Set a variable to an exact version to override that resolution. An override outside the T3 Code range fails the build.

Muse Code is installed from `https://dev.meta.ai/install.sh`. That installer does not take a version.

## Build requirements

1. Packer: https://www.packer.io/downloads
2. A DigitalOcean API token with write access

```bash
export DIGITALOCEAN_API_TOKEN="your_api_token_here"
```

From the repository root, after the DigitalOcean Packer plugin is installed:

```bash
make validate-t3code-24-04
make build-t3code-24-04
```

The builder size is `s-2vcpu-4gb`.

## First boot

1. Removes the SSH force-logout rule
2. Points Caddy at the droplet IP and starts Caddy
3. If `MODEL_ACCESS_KEY` is set, configures the DigitalOcean Inference provider and skips the wizard
4. Otherwise hooks `/etc/setup_wizard.sh` into root's `.bashrc`
5. Starts `t3code` and writes a 24-hour pairing link to `/root/.t3code-pairing.txt`

## Smoke test

Packer validation and the snapshot build were not run for this change. After a build, check:

- Packer finishes without a TTY hang
- `systemctl status t3code` and `systemctl status caddy` are active
- `https://<droplet-ip>` reaches the pairing screen
- `/root/.t3code-pairing.txt` is mode `600` and differs per droplet
- A droplet created with `MODEL_ACCESS_KEY` skips the wizard and writes `/home/t3/.t3/inference-configured`
- `claude`, `codex`, `cursor-agent`, `grok`, `opencode`, `pi`, `muse`, `fx`, and `/opt/antigravity-acp/current/agy_acp_server.par` exist
