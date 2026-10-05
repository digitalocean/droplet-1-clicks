# Herdr 1-Click Droplet Builder

Packer builder for a DigitalOcean Marketplace image that runs Herdr on Ubuntu 24.04, with Claude Code, Codex, OpenCode, Grok Build, and Kilo Code CLI already installed.

## Overview

Herdr is a terminal runtime for coding agents. Users SSH in and run `herdr`. The server is a systemd unit, so panes keep running after the SSH session closes. This builder installs the official Herdr Linux binary and the six agent CLIs Herdr launches by name (`claude`, `codex`, `opencode`, `grok`, `kilo`, `cursor-agent`). It also installs Herdr's integrations for those agents so session restore works on a fresh Droplet.

Herdr ships as a single Linux binary, and each agent CLI is a native or npm-installed executable. This image follows those installers and does not wrap them in Docker.

## Directory Structure

```
herdr-24-04/
├── template.json
├── readme.md
├── listing.md
├── scripts/
│   └── 010-herdr.sh
└── files/
    ├── etc/
    │   ├── profile.d/herdr.sh
    │   ├── systemd/system/herdr.service
    │   └── update-motd.d/99-one-click
    ├── opt/
    │   ├── codex-bin-wrapper.sh
    │   ├── codex-cli-download.sh
    │   ├── install-herdr-integrations.sh
    │   ├── restart-herdr.sh
    │   ├── start-herdr.sh
    │   ├── status-herdr.sh
    │   ├── stop-herdr.sh
    │   ├── update-agents.sh
    │   └── update-herdr.sh
    └── var/lib/cloud/scripts/per-instance/001_onboot
```

## Build Requirements

1. Packer: <https://www.packer.io/downloads>
2. A DigitalOcean API token with write access

```bash
export DIGITALOCEAN_API_TOKEN="your_api_token_here"
```

Build from the repository root so `common/` paths resolve:

```bash
packer init herdr-24-04/plugins.pkr.hcl
packer validate herdr-24-04/template.json
packer build herdr-24-04/template.json
```

The build Droplet size in `template.json` is `s-2vcpu-4gb` so the image build has room for the agent installers. For Droplets created from the snapshot, use at least 4 GB of RAM and prefer 8 GB.

## What Gets Installed

Versions are pinned in `template.json`:

| Component | Variable | Install method |
|-----------|----------|----------------|
| Herdr | `application_version` | GitHub release `herdr-linux-x86_64`, SHA-256 checked |
| Claude Code | `claude_code_version` | Official installer, symlinked to `/usr/local/bin/claude` |
| Codex CLI | `codex_version` | GitHub release tarball plus bundled `bwrap`, SHA-256 checked |
| OpenCode | `opencode_version` | Official installer, symlinked to `/usr/local/bin/opencode` |
| Grok Build | `grok_build_version` | Official installer into `/opt/grok/bin`, symlinked to `/usr/local/bin/grok` |
| Kilo Code CLI | `kilocode_version` | `npm install -g @kilocode/cli` |
| Cursor Agent CLI | `cursor_version` | Pinned package from `downloads.cursor.com`, symlinked to `/usr/local/bin/cursor-agent` |
| Node.js | `node_version` | NodeSource (`22.x`) |

The provisioner then runs `herdr integration install` for `claude`, `codex`, `opencode`, `kilo`, `grok`, and `cursor`. The Cursor command is `cursor-agent`. Herdr resumes that binary by name, and the generic `agent` name stays with Grok Build.

## Service

`herdr.service` runs `herdr server` as root. The build enables the unit, starts it long enough to install integrations, then stops it so the snapshot does not contain a live server. First boot starts it again from the unit and from `001_onboot`.

| Action | Command |
|--------|---------|
| Start | `/opt/start-herdr.sh` |
| Stop | `/opt/stop-herdr.sh` |
| Restart | `/opt/restart-herdr.sh` |
| Status | `/opt/status-herdr.sh` |
| Update Herdr | `/opt/update-herdr.sh` |
| Update agents | `/opt/update-agents.sh` |

## First Boot

1. Removes the build-time SSH force-logout rule
2. Creates `/root/workspace`
3. Enables and starts `herdr.service`
4. Writes `/root/herdr_info.txt`

There is no baked-in API key. Each agent asks the user to sign in on first launch.

## Remote attach from a laptop

The Droplet already has `herdr` on `PATH` for root. From a laptop that also has Herdr installed, an SSH config host is the remote target:

```
Host herdr-droplet
  HostName <droplet-ip>
  User root
  IdentityFile ~/.ssh/id_ed25519
```

Run both commands on the laptop. `ssh` only checks the alias. `herdr --remote` attaches after you have left that shell:

```bash
ssh herdr-droplet
exit
herdr --remote herdr-droplet
```

`herdr --remote ssh://root@<droplet-ip>` is the same attach without a config entry. The local client draws the UI. The Droplet server keeps the panes.

## Version Pins

Bump the matching variable in `template.json` and rebuild. Herdr's Linux x86_64 checksum is `herdr_sha256`. Codex checksums are `codex_tarball_sha256` and `bwrap_tarball_sha256`.

OpenCode must stay on 1.18.29 or newer so Herdr's OpenCode integration can install.

## License

This builder follows the droplet-1-clicks repository license. Herdr and the agent CLIs are covered by their own licenses and terms.
