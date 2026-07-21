# CS2 Dedicated Server — DigitalOcean 1-Click

This Packer template builds a DigitalOcean Marketplace 1-Click Droplet image for a Counter-Strike 2 (CS2) dedicated server, powered by [LinuxGSM](https://linuxgsm.com/).

## What's Included

- Ubuntu 24.04 LTS
- [LinuxGSM](https://linuxgsm.com/) `cs2server` management scripts
- CS2 dedicated server files (pre-installed via SteamCMD, App ID 730)
- UFW firewall (SSH, 27015 TCP/UDP, 27020 UDP open; all other ports blocked)
- 32-bit compatibility libraries required by CS2

## Prerequisites

- A DigitalOcean API token with write access set as `DIGITALOCEAN_API_TOKEN`
- [Packer](https://www.packer.io/) ≥ 1.7 installed locally

## Building the Image

From the repository root:

```bash
export DIGITALOCEAN_API_TOKEN=your_token_here
packer build cs2-24-04/template.json
```

The build runs on an `s-4vcpu-8gb` Droplet to accommodate the CS2 server files (~30–40 GB download). The final snapshot can be deployed on any Droplet size with at least 4 GB RAM and 80 GB disk.

## First Boot

On first boot, cloud-init automatically starts the CS2 server via `cs2server start`. SSH is available immediately; the forced-login banner is removed once the boot script completes.

## Managing the Server

SSH into the Droplet as `root`, then switch to the `linuxgsm` user:

```bash
sudo -u linuxgsm -s
cd ~
./cs2server status
./cs2server start
./cs2server stop
./cs2server restart
./cs2server update
./cs2server console      # attach to live tmux session (Ctrl+B, D to detach)
```

## Configuration

The main LinuxGSM config file is:

```
/home/linuxgsm/lgsm/config-lgsm/cs2server/cs2server.cfg
```

Key settings:
- `gslt` — Game Server Login Token (required to appear in the public server browser). Generate one at https://steamcommunity.com/dev/managegameservers
- `defaultmap` — Starting map (default: `de_dust2`)
- `maxplayers` — Maximum player count

Restart the server after making config changes:

```bash
./cs2server restart
```

## Security Notes

This image was built with `apt full-upgrade` applied at build time, ensuring the latest Ubuntu security patches (including CVE-2026-31431) are incorporated into the snapshot.
