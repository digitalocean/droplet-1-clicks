# CS2 Dedicated Server

Launch a fully configured Counter-Strike 2 dedicated server in seconds. This 1-Click deploys an Ubuntu 24.04 Droplet with the CS2 server pre-installed and ready to accept players on first boot — no manual setup required.

## Software Included

| Component | Version | Description |
| --- | --- | --- |
| Ubuntu | 24.04 LTS | Operating system |
| LinuxGSM | latest | Game server management framework |
| CS2 Dedicated Server | latest (Steam App 730) | Counter-Strike 2 server files |
| UFW | system | Firewall (SSH, CS2 ports only) |

## Getting Started

After creating your Droplet, the CS2 server starts automatically on first boot. You can connect from within CS2 using the in-game developer console:

```
connect <your-droplet-ip>:27015
```

### SSH Access

```bash
ssh root@<your-droplet-ip>
```

### Managing the Server

Switch to the `linuxgsm` user to use LinuxGSM management commands:

```bash
sudo -u linuxgsm -s
./cs2server status
./cs2server start
./cs2server stop
./cs2server restart
./cs2server update
./cs2server console
```

### Making the Server Publicly Listed

CS2 requires a Game Server Login Token (GSLT) for the server to appear in the in-game server browser. Generate one for free at [https://steamcommunity.com/dev/managegameservers](https://steamcommunity.com/dev/managegameservers), then add it to the config:

```
/home/linuxgsm/lgsm/config-lgsm/cs2server/cs2server.cfg
```

Set `gslt="YOUR_TOKEN"` and run `./cs2server restart`.

### Open Ports

| Port | Protocol | Purpose |
| --- | --- | --- |
| 22 | TCP | SSH |
| 27015 | TCP | RCON (remote console) |
| 27015 | UDP | CS2 game traffic |
| 27020 | UDP | SourceTV / GOTV |

## Server Configuration

Customise the server by editing:

```
/home/linuxgsm/lgsm/config-lgsm/cs2server/cs2server.cfg
```

Common options include `defaultmap`, `maxplayers`, `servername`, `sv_password`, and `rcon_password`. Run `./cs2server restart` to apply changes.

To update the CS2 server to the latest Steam build:

```bash
sudo -u linuxgsm -s
./cs2server update
```
