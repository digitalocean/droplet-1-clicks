# AGENTS.md: Private by Default

This Droplet blocks all inbound traffic except SSH, and SSH can be moved to
Tailscale. Web apps are published through outbound Cloudflare tunnels, never by
opening ports. Follow these rules when you work here.

## Rules

1. Do not open inbound ports. Do not run `ufw allow`, `ufw disable`, or edit
   `/etc/ufw/*`. To publish a web app, use `expose <port>` (preview) or ask a
   human to set up `private tunnel` (permanent).
2. Bind servers to `127.0.0.1` or `localhost`, not `0.0.0.0`. With Docker,
   publish as `-p 127.0.0.1:8080:80`; a plain `-p 8080:80` bypasses ufw.
3. Serve the main web app on `localhost:8080`, the front door. Cloudflare
   routes point there, so URLs keep working when the app changes. If the
   welcome page holds the port (`front_door.welcome_page` in status), ask a
   human to run `private welcome off`, or use another port with `expose`.
4. A preview URL from `expose` is public. Anyone with the link can reach that
   port. Do not expose admin panels, databases, or anything without auth.
   Stop previews when you are done: `expose --stop <port>`.
5. Run as the `agent` user. It has no general sudo. It can run `expose` and
   `private status` as root, nothing else. Its SSH keys are in the
   root-owned `/etc/ssh/authorized_keys.d/agent`; only root can add keys.
6. The `agent` user cannot reach the metadata service (169.254.169.254),
   because user data may hold secrets. Use `sudo private status --json`
   for this Droplet's Tailscale address and state.
7. Never print, log, or commit Tailscale auth keys or Cloudflare tunnel tokens.

## Commands

| Command | What it does |
|---------|--------------|
| `expose <port> --json` | Start a preview. Prints `{"port":3000,"url":"https://...trycloudflare.com"}` |
| `expose --list --json` | Running previews |
| `expose --stop <port>` | Stop a preview |
| `sudo private status --json` | `public_ssh_open`, `firewall_active`, `password_login`, `tailscale.{state,ip,dns_name}`, `front_door.{port,listening,welcome_page}`, `tunnel.active`, `previews`, `last_error` |

Root-only (a human or a provisioning agent with root SSH):

| Command | What it does |
|---------|--------------|
| `private connect --auth-key-file F` | Join the tailnet with Tailscale SSH |
| `private close-ssh --yes` | Close public port 22. Refuses unless Tailscale is connected. |
| `private open-ssh` | Re-open port 22 |
| `private tunnel --token-file F` | Run a permanent Cloudflare Tunnel |
| `private tunnel --remove` | Remove it |
| `private welcome on\|off` | Test page on `localhost:8080`; turn it off to free the port for the app |

## Provisioning this Droplet from outside (API, doctl, MCP)

Pass user data. Lines are read as `NAME=value`, so a `#!/bin/bash` header is
fine. Do not use `#cloud-config`, because these lines are not valid YAML.

```bash
#!/bin/bash
TAILSCALE_AUTHKEY=tskey-auth-...
CLOUDFLARE_TUNNEL_TOKEN=eyJ...
# PRIVATE_CLOSE_SSH=no   # join Tailscale but keep port 22 open
```

With `TAILSCALE_AUTHKEY`, first boot joins the tailnet with Tailscale SSH and
closes port 22 after Tailscale reports a running connection. With
`CLOUDFLARE_TUNNEL_TOKEN`, it runs the tunnel and starts the welcome page on
`localhost:8080`; point the tunnel's public hostname at `http://localhost:8080`.
Then:

- Use a one-off, pre-approved auth key. User data stays readable from the
  metadata service for the life of the Droplet.
- A tagged auth key needs an SSH rule for that tag in your tailnet policy,
  or Tailscale SSH will refuse connections. Untagged keys work with the
  default policy.
- Check the result over Tailscale: `ssh root@<hostname> private status --json`.
  The first-boot log is `/var/log/private-by-default.log`.

For a Cloud Firewall with no inbound rules, create it once with a tag and
create Droplets with that tag. The Droplet create API does not take a firewall ID.

```bash
doctl compute firewall create --name private-by-default --tag-names private-by-default \
  --outbound-rules "protocol:tcp,ports:all,address:0.0.0.0/0,address:::/0 protocol:udp,ports:all,address:0.0.0.0/0,address:::/0 protocol:icmp,address:0.0.0.0/0,address:::/0"
doctl compute droplet create my-droplet --image <this-1-click-slug> --size s-1vcpu-1gb \
  --region nyc3 --ssh-keys <key-id> --tag-names private-by-default --user-data-file ./user-data.sh
```

Only use the Cloud Firewall together with `TAILSCALE_AUTHKEY`. It also blocks
port 22, so without Tailscale the Droplet is reachable only from the Recovery Console.

## Recovery

If SSH is unreachable: control panel > Droplet > Settings > Recovery console >
Launch Console. That needs a root password, so first use Settings > Reset root
password. Log in as root and run `private open-ssh`. The Droplet Console does not work on
this image.
