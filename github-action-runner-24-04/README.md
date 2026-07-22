# GitHub Actions Runner 1-Click Droplet Builder

Packer builder for a DigitalOcean Marketplace 1-Click image that runs a self-hosted [GitHub Actions Runner](https://github.com/actions/runner) on Ubuntu 24.04 LTS.

## Overview

This image pre-installs the GitHub Actions runner binary, Docker (for container jobs), and a first-login wizard to register the Droplet with a GitHub repository, organization, or enterprise. Registration cannot be done at image build time because it requires a short-lived token unique to each Droplet.

## Directory Structure

```
github-action-runner-24-04/
├── template.json
├── README.md
├── listing.md
├── scripts/
│   └── 010-github-action-runner.sh
└── files/
    ├── etc/
    │   ├── setup-github-runner.sh
    │   ├── systemd/system/actions-runner.service
    │   └── update-motd.d/99-one-click
    └── var/lib/cloud/scripts/per-instance/001_onboot
```

## Build Requirements

1. [Packer](https://www.packer.io/downloads)
2. DigitalOcean API token with write access

```bash
export DIGITALOCEAN_API_TOKEN="your_api_token_here"
```

Install the DigitalOcean Packer plugin (see the repo root README), then:

```bash
# From droplet-1-clicks repo root
make validate-github-action-runner-24-04
make build-github-action-runner-24-04
```

## What Gets Installed

| Component | Details |
|-----------|---------|
| GitHub Actions Runner | Version from `application_version` in `template.json` (currently **2.336.0**) |
| Docker + Compose | Via `common/scripts/010-docker.sh` and `011-docker-compose.sh` |
| UFW | SSH rate-limited + Docker ports (`014-ufw-docker.sh`) |
| User | Dedicated `runner` user (in `docker` group) |
| Path | `/home/runner/actions-runner` |

## First Boot / First Login

1. `001_onboot` unlocks SSH and hooks `/etc/setup-github-runner.sh` into root's `.bashrc` if the runner is not registered yet.
2. On first interactive SSH login, the wizard prompts for GitHub URL and registration token, runs `config.sh`, and starts `actions-runner.service`.
3. You can re-run the wizard anytime: `/etc/setup-github-runner.sh` (use `--force` to reconfigure).

## Service Management

```bash
systemctl status actions-runner
systemctl start|stop|restart actions-runner
journalctl -u actions-runner -f
```

The unit starts only when `/home/runner/actions-runner/.runner` exists (after registration).

## Updating the Runner Version

Edit `application_version` in `template.json` to a release from [actions/runner releases](https://github.com/actions/runner/releases), then rebuild the image.

## Security

Self-hosted runners can execute arbitrary workflow code. Prefer private repositories. See [GitHub's self-hosted runner security guidance](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners#self-hosted-runner-security).
