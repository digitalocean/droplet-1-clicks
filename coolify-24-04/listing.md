# Coolify 1-Click Application

Deploy Coolify, an open-source and self-hostable alternative to Heroku, Netlify, and Vercel. Coolify simplifies deploying and managing your applications, databases, and services on your own infrastructure with complete control over your data and costs.

## What is Coolify?

Coolify is a powerful platform that makes it easy to deploy and manage applications on your own server without needing to be a DevOps expert. It provides a user-friendly interface for deploying static sites, Node.js applications, Docker containers, databases, and more.

Built with modern technologies and focused on developer experience, Coolify offers:

- **Application Deployment** - Deploy from Git repositories (GitHub, GitLab, Bitbucket), Docker images, or Dockerfiles
- **Database Management** - PostgreSQL, MySQL, MongoDB, Redis, and more with automated backups
- **Automatic SSL/TLS** - Free SSL certificates via Let's Encrypt with automatic renewal
- **Built-in CI/CD** - Automatic deployments on git push
- **Domain Management** - Easy custom domain configuration
- **Environment Variables** - Secure management of secrets and configurations
- **Docker-based** - Runs everything in isolated containers for security and reliability
- **Self-hosted** - Complete control over your data, no vendor lock-in

## Key Features

- Deploy multiple applications and services on a single server
- Support for static sites, Node.js, PHP, Python, Ruby, Go, and more
- One-click deployment of popular services (WordPress, Ghost, Plausible, etc.)
- Real-time deployment logs and monitoring
- Team collaboration features
- Webhook support for custom integrations
- Resource monitoring and management
- Built-in reverse proxy with Traefik
- Automated backup and restore capabilities
- Multi-server support (manage multiple servers from one interface)

## System Requirements

Coolify is packaged as Docker containers and runs on your DigitalOcean Droplet. Choose the appropriate Droplet size based on your needs:

### Minimum Requirements (Coolify Only)
- **CPU**: 2 cores
- **RAM**: 2 GB
- **Storage**: 30 GB

### Recommended for Production Workloads

| Applications/Services | RAM | CPU | Storage |
|----------------------|-----|-----|---------|
| 1-3 small apps | 4GB | 2 CPU | 50GB |
| 5-10 apps + databases | 8GB | 4 CPU | 100GB |
| 10+ apps + services | 16GB+ | 8 CPU | 150GB+ |

**Note**: The droplet size needed depends on what you'll deploy. Monitor resource usage and scale up as needed.

## Included System Components

This 1-Click installs and configures the following components:

- **Ubuntu 24.04 LTS** - Long-term support base operating system
- **Docker Engine 24+** - Container runtime for running applications
- **Docker Compose Plugin** - Multi-container application management
- **Coolify Latest** - The Coolify platform and web interface
- **UFW Firewall** - Pre-configured with secure defaults
- **Required utilities** - curl, wget, git, jq, openssl for operations

## Getting Started

### Initial Setup

1. **Deploy the Droplet**
   - Select this 1-Click App from the DigitalOcean Marketplace
   - Choose a Droplet size (minimum 2 CPU / 2GB RAM recommended)
   - Select your preferred datacenter region
   - Add your SSH key for secure access
   - Create the Droplet

2. **Access Coolify**
   - Wait 2-3 minutes for the installation to complete
   - Navigate to `http://your-droplet-ip:8000` in your web browser
   - You'll be redirected to the registration page

3. **Create Admin Account**
   - **CRITICAL**: Create your admin account immediately
   - The first user to register gets full administrative access
   - Use a strong password and save your credentials securely

4. **Initial Configuration**
   - Complete the onboarding wizard in Coolify
   - Configure your localhost server settings
   - Set up your first project

### Setting Up a Custom Domain (Recommended)

For production use with automatic HTTPS:

1. **Configure DNS**
   - In your DNS provider, create an A record pointing to your Droplet's IP
   - Example: `coolify.yourdomain.com` → `your-droplet-ip`
   - Wait for DNS propagation (5-15 minutes)

2. **Update Coolify Settings**
   - Log in to Coolify web interface
   - Go to Settings → Configuration
   - Update the instance URL to your domain
   - Coolify will automatically configure SSL/TLS

3. **Deploy Your First Application**
   - Create a new project in Coolify
   - Add a resource (application, database, or service)
   - Connect your Git repository or use a Docker image
   - Configure your domain and environment variables
   - Deploy!

## Managing Coolify

### Using Helper Scripts

Convenient management scripts are installed in `/opt/`:

**Start Coolify:**
```bash
/opt/start-coolify.sh
```

**Stop Coolify:**
```bash
/opt/stop-coolify.sh
```

**Restart Coolify:**
```bash
/opt/restart-coolify.sh
```

**Update to Latest Version:**
```bash
/opt/update-coolify.sh
```

**View Real-time Logs:**
```bash
/opt/coolify-logs.sh
```

**Check Service Status:**
```bash
/opt/coolify-status.sh
```

### Using systemctl

Coolify is also available as a systemd service:

**Start the service:**
```bash
systemctl start coolify
```

**Stop the service:**
```bash
systemctl stop coolify
```

**Restart the service:**
```bash
systemctl restart coolify
```

**Check service status:**
```bash
systemctl status coolify
```

**Enable on boot (already enabled):**
```bash
systemctl enable coolify
```

## Configuration and Locations

### Important Directories

- **Main Directory**: `/data/coolify/`
- **Configuration**: `/data/coolify/source/.env`
- **Docker Compose**: `/data/coolify/source/docker-compose.yml`
- **Applications**: `/data/coolify/applications/`
- **Databases**: `/data/coolify/databases/`
- **Backups**: `/data/coolify/backups/`
- **SSH Keys**: `/data/coolify/ssh/keys/`

### Firewall Configuration

UFW firewall is pre-configured with the following ports:

- **22** (SSH) - Limited rate to prevent brute force
- **80** (HTTP) - For web traffic and Let's Encrypt validation
- **443** (HTTPS) - For secure web traffic
- **8000** (Coolify UI) - Coolify web interface
- **6001** (Coolify Realtime) - Real-time updates
- **6002** (Coolify Soketi) - WebSocket server

**Add custom ports** (if needed for your applications):
```bash
ufw allow 3000/tcp comment 'Custom App'
```

## Deploying Applications

### From Git Repository

1. In Coolify, create a new Application resource
2. Select "Public Repository" or connect your Git provider
3. Enter your repository URL
4. Configure build settings (Coolify auto-detects most frameworks)
5. Set environment variables if needed
6. Configure your domain
7. Click Deploy

### From Docker Image

1. Create a new Application resource
2. Select "Docker Image"
3. Enter the image name (e.g., `nginx:latest`)
4. Configure ports and volumes
5. Set environment variables
6. Click Deploy

### One-Click Services

Coolify includes one-click deployments for popular services:

- WordPress, Ghost, Plausible Analytics
- PostgreSQL, MySQL, MongoDB, Redis
- MinIO, Uptime Kuma, n8n
- And many more...

## Backup and Maintenance

### Automated Backups

Configure automated backups in Coolify:

1. Go to your database or application settings
2. Navigate to the "Backups" tab
3. Configure backup frequency and retention
4. Set up S3-compatible storage (optional)

### Manual Backup

**Backup configuration and data:**
```bash
cd /data/coolify
tar -czf coolify-backup-$(date +%Y%m%d).tar.gz source/ databases/ applications/
```

### Updates

Keep Coolify up to date with:
```bash
/opt/update-coolify.sh
```

Or manually:
```bash
cd /data/coolify/source
bash upgrade.sh
```

## Troubleshooting

### Coolify won't start

Check Docker status:
```bash
systemctl status docker
docker ps
```

View Coolify logs:
```bash
/opt/coolify-logs.sh
```

### Can't access web interface

Check if Coolify is running:
```bash
/opt/coolify-status.sh
```

Verify firewall:
```bash
ufw status
```

### Out of resources

Check resource usage:
```bash
docker stats
df -h
free -h
```

Consider upgrading your Droplet if consistently at high usage.

### Reset admin password

Access the database container and reset:
```bash
cd /data/coolify/source
docker compose exec postgres psql -U coolify
# Follow password reset procedure in Coolify docs
```

## Security Best Practices

1. **Change default port**: Consider moving Coolify to a non-standard port
2. **Use SSH keys**: Disable password authentication for SSH
3. **Enable 2FA**: Enable two-factor authentication in Coolify settings
4. **Regular updates**: Keep Coolify and the system updated
5. **Backup regularly**: Configure automated backups
6. **Use HTTPS**: Always use SSL/TLS for production applications
7. **Monitor logs**: Regularly review application and system logs
8. **Limit access**: Use Coolify's team features to control access

## Additional Resources

- **Official Documentation**: https://coolify.io/docs
- **Community Support**: https://coolify.io/discord
- **GitHub Repository**: https://github.com/coollabsio/coolify
- **Video Tutorials**: https://www.youtube.com/@coolify-io

## Support

For Coolify-specific issues:
- Documentation: https://coolify.io/docs
- Discord Community: https://coolify.io/discord
- GitHub Issues: https://github.com/coollabsio/coolify/issues

For DigitalOcean Droplet issues:
- DigitalOcean Support: https://www.digitalocean.com/support
- Community Tutorials: https://www.digitalocean.com/community

---

**Note**: This 1-Click uses the official Coolify installation method and follows the recommended configuration for Ubuntu 24.04 LTS. All components are open-source and maintained by the Coolify community.
