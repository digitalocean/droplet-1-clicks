# GitHub Actions Runner 1-Click Application

Deploy a self-hosted **GitHub Actions Runner** on Ubuntu 24.04 with Docker pre-installed. Connect the Droplet to your repository, organization, or enterprise and run CI/CD jobs on DigitalOcean infrastructure you control.

## What is Included

| Component | Purpose |
|-----------|---------|
| GitHub Actions Runner 2.336.0 | Official self-hosted runner agent |
| Docker & Docker Compose | Run workflows that use container jobs and services |
| UFW firewall | SSH rate-limited; Docker ports allowed |
| `runner` system user | Non-root account that executes jobs |
| Setup wizard | First-login registration with GitHub |

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
- Registration token (expires in about one hour)
- Optional runner name and labels

5. Confirm the runner shows as **Idle** under your GitHub Runners page.

### Manual registration

```bash
cd /home/runner/actions-runner
sudo -u runner ./config.sh --url https://github.com/ORG/REPO --token YOUR_TOKEN
systemctl start actions-runner
```

## Service Management

```bash
systemctl status actions-runner
systemctl start actions-runner
systemctl stop actions-runner
systemctl restart actions-runner
journalctl -u actions-runner -f
```

| Path | Description |
|------|-------------|
| `/home/runner/actions-runner` | Runner install directory |
| `/etc/setup-github-runner.sh` | Registration wizard |
| `/etc/systemd/system/actions-runner.service` | systemd unit |

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

To update the runner software on a live Droplet, follow [GitHub's upgrade documentation](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/upgrading-self-hosted-runners), or rebuild this 1-Click image with a newer `application_version` and redeploy.

## Security Notes

- Prefer **private** repositories with self-hosted runners.
- Forks of **public** repositories can run untrusted workflow code on this machine.
- Treat registration tokens as secrets; they expire quickly.
- Restrict SSH access with a DigitalOcean Cloud Firewall when possible.

## Support and Resources

- [About self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners)
- [Adding self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/adding-self-hosted-runners)
- [actions/runner releases](https://github.com/actions/runner/releases)
- [DigitalOcean Community](https://www.digitalocean.com/community)
