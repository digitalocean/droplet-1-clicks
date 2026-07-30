# GitHub Actions Runner 1-Click Application

Deploy a self-hosted **GitHub Actions Runner** on Ubuntu 24.04 with Docker pre-installed. Connect the Droplet to your repository, organization, or enterprise and run CI/CD jobs on DigitalOcean infrastructure you control.

## What is Included

| Component | Purpose |
|-----------|---------|
| GitHub Actions Runner | Official self-hosted runner agent (version pinned in the image build / `application.info`) |
| Docker & Docker Compose | Run workflows that use container jobs and services |
| UFW firewall | SSH rate-limited only; Docker uses the local unix socket |
| `runner` system user | Non-root account that executes jobs |
| Setup wizard | First-login registration with GitHub |
| `/opt/*-github-runner.sh` | Start, stop, restart, status, and update helpers |

## System Requirements

| Use case | Recommended size |
|----------|------------------|
| Light CI (lint, unit tests) | 2 GB RAM / 1–2 vCPU |
| Container builds / moderate CI | 4 GB RAM / 2 vCPU |
| Heavy builds / parallel jobs | 8 GB+ RAM / 4+ vCPU |

Choose a Droplet size that matches your workflow resource needs when creating the Droplet from the Marketplace.

## Getting Started

1. **Create a registration token** on GitHub:  
   Repository or Organization → **Settings** → **Actions** → **Runners** → **New self-hosted runner**.
2. **Deploy** this 1-Click from the DigitalOcean Marketplace.
3. **SSH** into the Droplet: `ssh root@your-droplet-ip`
4. **Complete the setup wizard** (runs on first login), or run:

```bash
/etc/setup-github-runner.sh
```

Enter:

- GitHub URL (for example `https://github.com/ORG/REPO` or `https://github.com/ORG`)
- Registration token (expires in about one hour; input is hidden)
- Optional runner name and labels

5. Confirm the runner shows as **Idle** under your GitHub Runners page.

### Manual registration

```bash
cd /home/runner/actions-runner
sudo -u runner ./config.sh --url https://github.com/ORG/REPO --token YOUR_TOKEN
/opt/start-github-runner.sh
```

## Service Management

```bash
/opt/status-github-runner.sh
/opt/start-github-runner.sh
/opt/stop-github-runner.sh
/opt/restart-github-runner.sh
journalctl -u actions-runner -f
```

| Path | Description |
|------|-------------|
| `/home/runner/actions-runner` | Runner install directory |
| `/etc/setup-github-runner.sh` | Registration wizard |
| `/etc/systemd/system/actions-runner.service` | systemd unit |
| `/opt/start-github-runner.sh` | Start the runner |
| `/opt/stop-github-runner.sh` | Stop the runner |
| `/opt/restart-github-runner.sh` | Restart the runner |
| `/opt/status-github-runner.sh` | Show status |
| `/opt/update-github-runner.sh` | Update runner binaries |

## Using the Runner in Workflows

Target the self-hosted runner with:

```yaml
jobs:
  build:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
      - run: echo "Running on DigitalOcean"
```

Add custom labels during setup to select specific Droplets:

```yaml
runs-on: [self-hosted, linux, production]
```

Docker is available for jobs that use the `container:` key or build images.

## Updating

On a live Droplet:

```bash
/opt/update-github-runner.sh           # latest release
/opt/update-github-runner.sh <VERSION> # specific version (e.g. from actions/runner releases)
```

Or follow [GitHub's upgrade documentation](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/upgrading-self-hosted-runners). To change the version baked into new Marketplace images, rebuild with an updated `application_version` in `template.json`.

## Security Notes

- Prefer **private** repositories with self-hosted runners.
- Forks of **public** repositories can run untrusted workflow code on this machine.
- Treat registration tokens as secrets; they expire quickly.
- Restrict SSH access with a DigitalOcean Cloud Firewall when possible.
- Docker API ports are not exposed; only SSH is allowed through UFW.

## Support and Resources

- [About self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners)
- [Adding self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/adding-self-hosted-runners)
- [actions/runner releases](https://github.com/actions/runner/releases)
- [DigitalOcean Community](https://www.digitalocean.com/community)
