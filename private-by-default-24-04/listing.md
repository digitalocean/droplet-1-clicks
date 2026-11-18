# Private by Default 1-Click Application

## What is Private by Default?

Try Private by Default on DigitalOcean: an Ubuntu 24.04 Droplet where every inbound port is blocked except SSH, with a 2-minute setup that moves SSH to Tailscale and closes port 22 too.

Most servers start open. Any service that listens on a public port can be reached by anyone, and bots start probing SSH within minutes of a server going online. Private by Default blocks everything but SSH by default and walks you through closing that last port:

- **Inbound traffic denied by default** – The host firewall (UFW) allows only SSH, and you can close that too
- **SSH over Tailscale** – Reach the Droplet from your own devices on your private tailnet, then close port 22
- **Web traffic through Cloudflare Tunnel** – Publish apps through an outbound tunnel. Ports 80 and 443 stay closed.
- **Built for AI agents** – A non-root `agent` user, commands with JSON output, setup from user data, and an `AGENTS.md` with rules

> **⚠ Warning:** Until you complete Tailscale setup, this Droplet accepts SSH from the internet on port 22 (SSH keys only, rate limited). The setup wizard moves SSH to Tailscale and closes port 22 at your first login, in about 2 minutes.

## Key Features

- One-time setup wizard at first login. Pressing Enter always picks the recommended option.
- Port 22 closes only after you confirm SSH over Tailscale works
- `expose 8080` – an instant public HTTPS preview URL, no account needed
- `private tunnel` – a permanent address on your own domain through Cloudflare Tunnel
- `private welcome on` – a test page that shows the Cloudflare path works, then makes way for your app
- `private status --json` – shows what the Droplet exposes, for scripts and agents
- Hands-off setup: put `TAILSCALE_AUTHKEY` in user data and the Droplet joins your tailnet and closes port 22 at first boot
- Automatic security updates for Ubuntu, Tailscale, and cloudflared

## System Requirements

Private by Default adds very little overhead; size the Droplet for the app you plan to run.

| Use Case    | RAM  | CPU    | Storage |
| ----------- | ---- | ------ | ------- |
| Minimum     | 512 MB | 1 vCPU | 10 GB |
| Recommended | 2 GB | 2 vCPU | 50 GB   |

## Included System Components

- **Ubuntu 24.04 LTS** – Base operating system
- **Tailscale** (1.104.7) – Private network and Tailscale SSH
- **cloudflared** (2026.11.1) – Cloudflare Tunnel connector
- **UFW Firewall** – Inbound denied; SSH rate limited until you close it
- **unattended-upgrades** – Automatic security updates
- **Git**, **curl**, **jq** – Common tools for agents and scripts

## Getting Started

### 1. Deploy the Droplet

Before you start, create a free [Tailscale account](https://login.tailscale.com/start) and [install Tailscale](https://tailscale.com/download) on the computer you will connect from.

1. Select this 1-Click App from the DigitalOcean Marketplace
2. Choose a Droplet size (512 MB RAM minimum, so any Basic plan works)
3. Add your SSH key. Password login stays on if you don't.
4. Create the Droplet

Optional: add `TAILSCALE_AUTHKEY` as user data to skip the wizard. See [Hands-off Setup with User Data](#hands-off-setup-with-user-data).

### 2. SSH In

```bash
ssh root@your-droplet-ip
```

### 3. Complete the Setup Wizard

The wizard starts automatically at first login:

1. **Connect Tailscale.** Press Enter to get a sign-in link and approve the Droplet in your browser, or paste a Tailscale auth key.
2. **Test the new path.** In a new terminal on your computer, run `ssh root@<droplet-name>`.
3. **Close port 22.** Confirm the test worked, and the wizard closes public SSH.
4. **Optional: web address.** See a test page at a quick preview URL, or paste a Cloudflare Tunnel token for a permanent address.

Skipped it? Run `private setup` anytime.

### 4. Connect over Tailscale

From now on, connect with:

```bash
ssh root@<droplet-name>
```

In the Tailscale admin console, turn off **key expiry** for this machine so access doesn't stop after the expiry period.

## Hands-off Setup with User Data

For the API, `doctl`, and AI agents. Add this as user data when you create the Droplet:

```bash
#!/bin/bash
TAILSCALE_AUTHKEY=tskey-auth-...
CLOUDFLARE_TUNNEL_TOKEN=eyJ...
```

First boot joins your tailnet with Tailscale SSH and closes port 22 once Tailscale is running. With a tunnel token, it also runs the tunnel and starts the welcome page on `localhost:8080`. If Tailscale fails, port 22 stays open and the login message says so.

Use a one-off, pre-approved auth key: user data stays readable from the metadata service for the life of the Droplet. If the key is tagged, add an SSH rule for that tag in your Tailscale policy.

For defense in depth, also attach a Cloud Firewall with no inbound rules by giving the Droplet a tag that is already on that firewall. Only do this together with `TAILSCALE_AUTHKEY`, because the Cloud Firewall also blocks port 22.

## Publishing Web Apps

Your app's front door is `localhost:8080`. Cloudflare sends visitors there, so the public URL stays the same when you swap what runs behind it.

| Need | Command | Account |
| ---- | ------- | ------- |
| Test page | `private welcome on` | None. Serves a welcome page on `localhost:8080`. It is not public until you run `expose 8080` or point a tunnel at it. |
| Quick preview | `expose 8080` | None. Random `trycloudflare.com` URL that changes on restart. For testing only. |
| Permanent address | `private tunnel` | Free Cloudflare account and a domain on Cloudflare. Create the tunnel under **Zero Trust > Networks > Tunnels**, paste its token, then add a public hostname such as `app.example.com` with service `http://localhost:8080`. |

To replace the welcome page with your app:

```bash
private welcome off      # frees port 8080
PORT=8080 npm start       # or any server on localhost:8080
```

Reload your URL and it shows your app. Nothing changes in Cloudflare. Bind your app to `127.0.0.1`; with Docker, publish as `-p 127.0.0.1:8080:80`, because a plain `-p 8080:80` bypasses the firewall.

Prefer another port? Run `expose 3000`, or set the hostname's service to `http://localhost:3000` in the Cloudflare dashboard. Stop a preview with `expose --stop <port>`. Remove the permanent tunnel with `private tunnel --remove`.

## Managing Private by Default

| Action | Command |
| ------ | ------- |
| Re-run the setup wizard | `private setup` |
| Show what is exposed | `private status` (or `--json`) |
| Close public SSH | `private close-ssh` |
| Re-open public SSH | `private open-ssh` |
| Start / stop / list previews | `expose <port>`, `expose --stop <port>`, `expose --list` |
| Welcome page on / off | `private welcome on`, `private welcome off` |
| Restart the permanent tunnel | `systemctl restart cloudflared-tunnel` |
| Tailscale status | `tailscale status` |
| Logs | `/var/log/private-by-default.log`, `journalctl -u tailscaled`, `journalctl -u cloudflared-tunnel` |

## Updating

Security updates for Ubuntu, Tailscale, and cloudflared install automatically. To update everything now:

```bash
apt update && apt upgrade
```

## Running AI Agents

Run agents as the `agent` user (`ssh agent@<droplet-name>`). It has no general sudo, it can't reach the metadata service where user data secrets live, and it can start previews with `expose`. Rules and commands for agents are in `~/AGENTS.md`.

## Troubleshooting

### Locked out after closing port 22

Use the **Recovery Console**: control panel > your Droplet > **Settings** > **Recovery console** > **Launch Console**. It needs a root password, so first use **Settings** > **Reset root password**. Log in as root and run:

```bash
private open-ssh
```

The Droplet Console does not work on this image.

### `ssh root@<droplet-name>` doesn't connect over Tailscale

- Make sure Tailscale is running on your computer and signed in to the same account.
- Try the Tailscale IP from `tailscale ip -4` instead of the name.
- If you used a tagged auth key, add an SSH rule for that tag in your Tailscale policy.

## Additional Resources

- **Tailscale SSH**: [https://tailscale.com/kb/1193/tailscale-ssh](https://tailscale.com/kb/1193/tailscale-ssh)
- **Tailscale auth keys**: [https://tailscale.com/kb/1085/auth-keys](https://tailscale.com/kb/1085/auth-keys)
- **Cloudflare Tunnel**: [https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- **Recovery Console**: [https://docs.digitalocean.com/products/droplets/how-to/recovery/recovery-console/](https://docs.digitalocean.com/products/droplets/how-to/recovery/recovery-console/)
- **Cloud Firewalls**: [https://docs.digitalocean.com/products/networking/firewalls/](https://docs.digitalocean.com/products/networking/firewalls/)

## Support

For Tailscale or Cloudflare account issues:

- Tailscale support: [https://tailscale.com/contact/support](https://tailscale.com/contact/support)
- Cloudflare community: [https://community.cloudflare.com](https://community.cloudflare.com)

For DigitalOcean Droplet issues:

- DigitalOcean Support: [https://www.digitalocean.com/support](https://www.digitalocean.com/support)
- Community Tutorials: [https://www.digitalocean.com/community](https://www.digitalocean.com/community)

---

**Note**: This 1-Click installs Tailscale and cloudflared from their official package repositories. Until port 22 is closed, SSH is the only open public inbound port; once it is closed, none are.
