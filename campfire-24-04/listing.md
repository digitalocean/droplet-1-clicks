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
- Automated SSL/TLS configuration
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
2. **Access Campfire** - Navigate to your Droplet's IP address in a web browser (e.g., `http://your-droplet-ip`)
3. **Configure your team** - Set up user accounts and start chatting

### Setting Up a Custom Domain (Recommended)
For a professional setup with automatic SSL/TLS certificates:

1. **Point your domain to the Droplet**
   - In your DNS provider, create an A record pointing your domain (e.g., `chat.yourcompany.com`) to your Droplet's IP address
   - Wait for DNS propagation (usually 5-15 minutes)

2. **Configure Campfire for your domain**
   - SSH into your Droplet: `ssh root@your-droplet-ip`
   - Edit the configuration file: `nano /opt/campfire.env`
   - Uncomment and update the TLS_DOMAIN line:
     ```
     TLS_DOMAIN=chat.yourcompany.com
     ```
   - Comment out the DISABLE_SSL line by adding # at the beginning:
     ```
     # DISABLE_SSL=true
     ```

3. **Restart Campfire to apply changes**
   ```bash
   /opt/restart-campfire.sh
   ```

4. **Access your secure Campfire installation**
   - Visit `https://chat.yourcompany.com` in your browser
   - SSL certificates will be automatically generated and configured

**Note**: The initial SSL certificate generation may take a few minutes. If you encounter any SSL errors, wait a moment and refresh the page.


## Post-Deployment

After deployment, Campfire will be accessible via HTTP on port 80. The application includes:

- Automatic firewall configuration
- Docker container with restart policies
- Persistent data storage via Docker volumes
- Generated secure session keys

For production use, consider:
- Configuring a custom domain with SSL/TLS
- Setting up regular backups of the data volume
- Configuring email notifications (if needed)

## Support

Campfire is an open-source project by Basecamp. For technical support:
- [Official Campfire Repository](https://github.com/basecamp/once-campfire)
- [DigitalOcean Community](https://www.digitalocean.com/community)
- [DigitalOcean Documentation](https://docs.digitalocean.com/)

Perfect for small teams, startups, and organizations looking for a simple, self-hosted chat solution without the complexity of larger enterprise platforms.