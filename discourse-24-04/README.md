# Discourse 1-Click Droplet Builder

Packer builder for a DigitalOcean Marketplace 1-Click that runs [Discourse](https://www.discourse.org/) on Ubuntu 24.04 using the official [discourse_docker](https://github.com/discourse/discourse_docker) installer.

Discourse itself is **not** fully installed at image-build time. The snapshot ships Docker and a clone of the installer; interactive `discourse-setup` runs on first root login.

## Directory Structure

```
discourse-24-04/
├── template.json
├── README.md
├── listing.md
├── scripts/
│   └── 010-discourse.sh
└── files/
    ├── etc/update-motd.d/99-one-click
    ├── opt/digitalocean_discourse/setup_discourse.sh
    └── var/lib/cloud/scripts/per-instance/001_onboot
```

## Build Requirements

1. Packer with the DigitalOcean plugin (see repo root `README.md`)
2. `DIGITALOCEAN_API_TOKEN` with write access

```bash
export DIGITALOCEAN_API_TOKEN="your_api_token_here"
```

## Validate and Build

From the `droplet-1-clicks` repo root:

```bash
make validate-discourse-24-04
make build-discourse-24-04
```

## What Gets Installed (build time)

- Ubuntu 24.04 LTS
- Docker CE (`common/scripts/010-docker.sh`)
- Shallow clone of `discourse/discourse_docker` → `/var/discourse`
- UFW with SSH (rate-limited), HTTP, and HTTPS
- First-login bashrc hook → `/opt/digitalocean_discourse/setup_discourse.sh`
- Application metadata tag (`application_version` from `template.json`, default `latest`)

## First Boot (`001_onboot`)

1. `git pull` in `/var/discourse` to refresh the installer
2. Noninteractive apt update/upgrade
3. Remove the SSH `ForceCommand` lock (always, even if earlier steps fail)

## First Login

1. MOTD points users at setup and docs
2. `setup_discourse.sh` prompts for domain, admin email, and SMTP
3. Runs `./discourse-setup` (downloads Discourse + dependencies; ~10–15 minutes)
4. On success, restores a clean `/root/.bashrc` (hook removed)
5. On failure, loops so the user can retry without re-logging in; Ctrl+C cancels until next login

## Version Pinning

`application_version` in `template.json` is `latest` by design: Discourse is installed by the upstream installer at first login, not pinned in this image. Change the variable only if Marketplace metadata needs a different label.

## License

Builder files follow the droplet-1-clicks repository license. Discourse is GPL-2.0.
