# Campfire 1-Click Application

Deploy Basecamp's Once Campfire, a simple group chat application designed for small teams and organizations. Campfire provides real-time messaging with a clean, distraction-free interface perfect for focused team communication.

## What is Campfire?

Campfire is Basecamp's elegant group chat solution that emphasizes simplicity and usability. Built on modern web technologies, it offers:

- **Real-time messaging** - Instant communication with your team
- **Clean interface** - Distraction-free design focused on conversation
- **File sharing** - Easy drag-and-drop file uploads
- **Search functionality** - Find messages and files quickly
- **Mobile responsive** - Works seamlessly across devices
- **Self-hosted** - Complete control over your data and privacy

## Key Features

- Simple, intuitive chat interface
- Real-time messaging with WebSocket support
- File uploads and sharing
- Message search and history
- Mobile-responsive design
- Docker-based deployment for easy management
- HTTPS out of the box via Caddy (short-lived IP certificates)
- Built-in user management

## System Requirements

Campfire is packed as a Docker container image and runs on your own droplet on DigitalOcean.  Use this guide to choose the appropriate size droplet for your needs:

| Users | RAM | CPU |
|-------|-----|-----|
| 250 | 2GB | 1CPU |
| 1,000 | 8GB | 4CPU |
| 5,000 | 32GB | 16CPU |
| 10,000 | 64GB | 32CPU |

## Getting Started

### Quick Start
1. **Deploy the Droplet** - Select this 1-Click App from the DigitalOcean Marketplace
2. **Access Campfire** - Open `https://your-droplet-ip` in a web browser (TLS is provisioned automatically on first boot)
3. **Configure your team** - Set up user accounts and start chatting

Campfire's Docker container listens on `127.0.0.1:8080` only. Caddy terminates HTTPS on ports 80/443 and reverse-proxies to the app (including WebSockets / ActionCable).

### Setting Up a Custom Domain (Recommended)
For a professional hostname with automatic SSL/TLS certificates:

1. **Point your domain to the Droplet**
   - In your DNS provider, create an A record pointing your domain (e.g., `chat.yourcompany.com`) to your Droplet's IP address
   - Wait for DNS propagation (usually 5-15 minutes)

2. **Configure Caddy for your domain**
   - SSH into your Droplet: `ssh root@your-droplet-ip`
   - Run the domain helper:
     ```bash
     /opt/setup-campfire-domain.sh
     ```
   - Enter your domain (and optionally an email for Let's Encrypt notifications)

3. **Access your secure Campfire installation**
   - Visit `https://chat.yourcompany.com` in your browser
   - Keep `DISABLE_SSL=true` in `/opt/campfire.env` — TLS stays on Caddy, not inside the container

**Note**: The initial SSL certificate generation may take a few minutes. If you encounter any SSL errors, wait a moment and refresh the page.

## Updating Campfire

To manually update to the latest version at any time:

1. **SSH into your Droplet**
   ```bash
   ssh root@your-droplet-ip
   ```

2. **Run the update script**
   ```bash
   /opt/update-campfire.sh
   ```

The update script will:
- Pull the latest code from GitHub
- Rebuild the Docker image
- Restart Campfire with the updated code (still bound to loopback)
- Preserve all your configuration and data

**Note**: Updates may take a few minutes to complete. Your chat history and configuration will be preserved during updates.

## Management

| Action | Command |
|--------|---------|
| Restart Campfire | `/opt/restart-campfire.sh` |
| Update Campfire | `/opt/update-campfire.sh` |
| Custom domain | `/opt/setup-campfire-domain.sh` |
| Edit env | `/opt/campfire.env` then restart |
| Caddy status | `systemctl status caddy` |

## Post-Deployment

After deployment, Campfire is reachable at `https://<droplet-ip>`. The application includes:

- Automatic firewall configuration (SSH, HTTP, HTTPS)
- Caddy reverse proxy with short-lived Let's Encrypt IP certificates
- Docker container bound to localhost with restart policies
- Persistent data storage via Docker volumes
- Generated secure session keys

For production use, consider:
- Attaching a custom domain with `/opt/setup-campfire-domain.sh`
- Setting up regular backups of the data volume
- Configuring Web Push (VAPID keys in `/opt/campfire.env`)

## Support

Campfire is an open-source project by Basecamp. For technical support:
- [Official Campfire Repository](https://github.com/basecamp/once-campfire)
- [DigitalOcean Community](https://www.digitalocean.com/community)
- [DigitalOcean Documentation](https://docs.digitalocean.com/)

Perfect for small teams, startups, and organizations looking for a simple, self-hosted chat solution without the complexity of larger enterprise platforms.
