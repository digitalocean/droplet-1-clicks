# Strapi 1-Click Application for DigitalOcean

This repository contains the Packer configuration and supporting files to build a DigitalOcean Marketplace 1-Click image for Strapi CMS.

## Overview

Strapi is a leading open-source headless CMS that gives developers the freedom to use their favorite tools and frameworks while allowing editors to manage content using an intuitive admin panel. This 1-Click application deploys Strapi v5.0.0 with PostgreSQL 16 on Ubuntu 24.04 LTS using Docker containers.

## What's Included

- **Strapi v5.0.0** - Latest version of the headless CMS
- **Node.js 22 (Alpine)** - JavaScript runtime for Strapi
- **PostgreSQL 16 (Alpine)** - Production-ready database
- **Docker & Docker Compose** - Container orchestration
- **Ubuntu 24.04 LTS** - Base operating system
- **UFW Firewall** - Pre-configured security
- **Systemd Service** - For service management
- **Helper Scripts** - Easy management commands

## Architecture

This 1-Click uses Docker Compose to orchestrate two containers:

1. **Strapi Container** (`strapi`)
   - Runs Strapi CMS on Node.js 22
   - Exposes port 1337 (mapped to host port 80)
   - Connects to PostgreSQL database
   - Persistent volumes for uploads and application code

2. **PostgreSQL Container** (`strapiDB`)
   - PostgreSQL 16 database
   - Persistent volume for database files
   - Health checks for reliability
   - Isolated to Docker network

## Directory Structure

```
strapi-24-04/
├── template.json                          # Packer build configuration
├── scripts/
│   └── strapi.sh                         # Main installation script
├── files/
│   ├── etc/
│   │   ├── systemd/system/
│   │   │   └── strapi.service           # Systemd service file
│   │   └── update-motd.d/
│   │       └── 99-one-click             # Message of the day
│   ├── opt/
│   │   ├── docker-compose.yml            # Docker Compose configuration
│   │   ├── strapi-env-template           # Environment variable template
│   │   ├── start-strapi.sh              # Start helper script
│   │   ├── stop-strapi.sh               # Stop helper script
│   │   ├── restart-strapi.sh            # Restart helper script
│   │   └── update-strapi.sh             # Update helper script
│   └── var/
│       └── lib/
│           └── cloud/
│               └── scripts/
│                   └── per-instance/
│                       └── 001_onboot    # First-boot configuration
├── listing.md                             # Marketplace listing content
└── README.md                              # This file
```

## Building the Image

### Prerequisites

1. DigitalOcean API token with write access
2. Packer installed (https://www.packer.io/downloads)
3. Git (for cloning the repository)

### Build Steps

1. Clone the repository:
   ```bash
   git clone https://github.com/digitalocean/droplet-1-clicks.git
   cd droplet-1-clicks
   ```

2. Set your DigitalOcean API token:
   ```bash
   export DIGITALOCEAN_API_TOKEN="your_token_here"
   ```

3. Build the image:
   ```bash
   packer build strapi-24-04/template.json
   ```

4. The build process will:
   - Create a temporary Droplet
   - Install Docker and required packages
   - Copy configuration files
   - Set up systemd services
   - Create helper scripts
   - Clean up and create a snapshot
   - Destroy the temporary Droplet

### Build Time

The typical build time is approximately 10-15 minutes.

## First Boot Process

When a Droplet is created from this image:

1. **Cloud-init executes the onboot script** (`001_onboot`)
2. **Security keys are generated**:
   - Database password (32 characters)
   - JWT secret
   - Admin JWT secret
   - API token salt
   - Transfer token salt
   - App keys (4 unique keys)
3. **Environment file is created** at `/opt/strapi/.env`
4. **Docker Compose configuration is copied** to `/opt/strapi/`
5. **Strapi service is enabled and started**
6. **Services initialize** (takes 2-3 minutes)

## Security Considerations

### Secrets Generation

All sensitive credentials are generated randomly on first boot using OpenSSL:
- Database passwords: 32-character random strings
- JWT secrets: 32-character random strings
- App keys: 4 separate 32-character keys

This ensures each Droplet has unique credentials and cannot share security keys.

### Firewall Configuration

UFW is pre-configured with:
- Port 22 (SSH) - rate limited
- Port 80 (HTTP) - open for Strapi
- Port 443 (HTTPS) - open for future SSL setup
- All other ports - blocked by default

### Docker Network Isolation

- PostgreSQL is only accessible within the Docker network
- Not exposed to the host or external networks
- Strapi container communicates with database via internal network

## Management

### Service Management

```bash
# Using systemd
systemctl start strapi
systemctl stop strapi
systemctl restart strapi
systemctl status strapi

# Using helper scripts
/opt/start-strapi.sh
/opt/stop-strapi.sh
/opt/restart-strapi.sh
```

### Logs

```bash
# All services
docker compose -f /opt/strapi/docker-compose.yml logs -f

# Strapi only
docker logs -f strapi

# Database only
docker logs -f strapiDB
```

### Updates

```bash
/opt/update-strapi.sh
```

This pulls the latest Docker images and restarts services.

## Configuration Files

### Environment Variables (`/opt/strapi/.env`)

Contains all Strapi configuration including:
- Database connection details
- Security keys and secrets
- Node environment settings
- Server configuration

### Docker Compose (`/opt/strapi/docker-compose.yml`)

Defines:
- Service configurations
- Volume mappings
- Network settings
- Health checks
- Environment variable bindings

### Systemd Service (`/etc/systemd/system/strapi.service`)

Manages:
- Service lifecycle
- Docker Compose integration
- Automatic restart policies
- Dependencies on Docker

## Troubleshooting Build Issues

### Common Issues

1. **API Token Issues**
   - Ensure `DIGITALOCEAN_API_TOKEN` is set correctly
   - Verify token has write permissions

2. **Packer Not Found**
   - Install Packer from https://www.packer.io/downloads
   - Ensure Packer is in your PATH

3. **Build Timeout**
   - Increase timeout in template.json if needed
   - Check DigitalOcean API status

4. **File Copy Errors**
   - Verify all files exist in the correct directories
   - Check file permissions

### Debug Mode

Run Packer with debug flag:
```bash
packer build -debug strapi-24-04/template.json
```

## Testing the Image

After building:

1. Create a new Droplet from the snapshot
2. Wait 3-5 minutes for first boot completion
3. SSH into the Droplet
4. Check service status: `systemctl status strapi`
5. View logs: `docker compose -f /opt/strapi/docker-compose.yml logs`
6. Access Strapi: `http://your-droplet-ip`
7. Access admin panel: `http://your-droplet-ip/admin`

## Version Information

- **Strapi**: 5.0.0
- **Node.js**: 22 (Alpine Linux)
- **PostgreSQL**: 16 (Alpine Linux)
- **Ubuntu**: 24.04 LTS
- **Docker**: Latest from Ubuntu repositories
- **Docker Compose**: v2 (from Ubuntu repositories)

## Best Practices

1. **Use appropriate Droplet size**: Minimum 2GB RAM, 2 CPUs for production
2. **Set up SSL/TLS**: Use a reverse proxy with Let's Encrypt for production
3. **Regular backups**: Backup database and volumes regularly
4. **Monitor resources**: Watch CPU and memory usage
5. **Update regularly**: Keep Strapi and system packages updated
6. **Use strong passwords**: For admin accounts and API tokens

## Contributing

When making changes to this 1-Click:

1. Test thoroughly with `packer build`
2. Verify first boot process
3. Check all helper scripts work correctly
4. Test service management commands
5. Verify MOTD displays correctly
6. Update version numbers in `template.json`

## Support Resources

- **Strapi Documentation**: https://docs.strapi.io/
- **Strapi Discord**: https://discord.strapi.io/
- **DigitalOcean Marketplace**: https://marketplace.digitalocean.com/
- **Packer Documentation**: https://www.packer.io/docs

## License

This build configuration is provided as-is for creating DigitalOcean Marketplace images. Strapi itself is licensed under the MIT License.
