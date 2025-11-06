# Conduktor Console 1-Click for DigitalOcean Marketplace

This repository contains the Packer builder configuration for creating a DigitalOcean Marketplace 1-Click App for Conduktor Console, a powerful web-based UI for Apache Kafka.

## Overview

Conduktor Console is an enterprise-grade platform for managing Apache Kafka clusters. This 1-Click App packages Conduktor Console 1.39.0 with all necessary dependencies, pre-configured and ready to use on DigitalOcean.

## What's Included

- **Conduktor Console 1.39.0** - Main application
- **Conduktor Monitoring (Cortex) 1.39.0** - Metrics and monitoring
- **PostgreSQL 14** - Database backend
- **Docker & Docker Compose** - Container runtime
- **UFW Firewall** - Pre-configured security
- **Helper Scripts** - Management and maintenance scripts

## Architecture

This 1-Click App uses Docker Compose to orchestrate three main services:

1. **PostgreSQL Database** - Stores Conduktor Console configuration and metadata
2. **Conduktor Console** - Main web application (port 8080)
3. **Conduktor Monitoring** - Cortex-based monitoring stack

All services are connected via a Docker bridge network and use persistent volumes for data storage.

## Directory Structure

```
conduktor-console-24-04/
├── template.json                                    # Packer configuration
├── scripts/
│   └── conduktor-console.sh                        # Main installation script
├── files/
│   ├── etc/
│   │   └── update-motd.d/
│   │       └── 99-one-click                        # MOTD banner
│   ├── opt/
│   │   └── conduktor/
│   │       └── docker-compose.yml                  # Docker services configuration
│   └── var/
│       └── lib/
│           └── cloud/
│               └── scripts/
│                   └── per-instance/
│                       └── 001_onboot              # First boot initialization
├── listing.md                                       # Marketplace listing copy
└── README.md                                        # This file
```

## Building the Image

### Prerequisites

- Packer 1.7.0 or later
- DigitalOcean API token with write access
- SSH key configured in your DigitalOcean account

### Build Process

1. **Set your DigitalOcean API token:**
   ```bash
   export DIGITALOCEAN_API_TOKEN="your-api-token"
   ```

2. **Navigate to the repository root:**
   ```bash
   cd /path/to/droplet-1-clicks
   ```

3. **Validate the Packer template:**
   ```bash
   packer validate conduktor-console-24-04/template.json
   ```

4. **Build the image:**
   ```bash
   packer build conduktor-console-24-04/template.json
   ```

The build process will:
- Create a temporary Ubuntu 24.04 droplet
- Install Docker, Docker Compose, PostgreSQL client, and dependencies
- Copy configuration files and scripts
- Set up the Docker Compose environment
- Create helper scripts for management
- Clean up and create a snapshot
- Delete the temporary droplet

### Build Time

The entire build process typically takes 10-15 minutes.

## Installation Process

### What Happens During Build

1. **System Preparation**
   - Update system packages
   - Install Docker, Docker Compose, and dependencies
   - Configure UFW firewall (allow ports 8080, 80, 443, SSH)
   - Create directory structure at `/opt/conduktor`

2. **File Deployment**
   - Copy Docker Compose configuration
   - Install helper scripts (start, stop, restart, update, logs)
   - Create environment template with placeholders
   - Install MOTD banner

3. **Security Setup**
   - Enable UFW firewall with rate limiting on SSH
   - Prepare for unique secret generation on first boot

### What Happens on First Boot

The `001_onboot` script runs automatically when a droplet is created from the snapshot:

1. **Generate Unique Secrets**
   - PostgreSQL password (25 characters, base64)
   - Admin password (meets Conduktor requirements: min 8 chars with uppercase, lowercase, number, and special character)
   - Update `/opt/conduktor/conduktor.env` with real values

2. **Remove SSH Force Logout**
   - Clean up the SSH configuration used during build

3. **Start Services**
   - Load environment variables
   - Start all Docker containers via docker compose
   - Wait for services to become healthy
   - Display access information

## Configuration Files

### template.json

The Packer template defines:
- **Variables**: API token, image name, packages, application version
- **Builder**: DigitalOcean droplet specs (Ubuntu 24.04, 2 CPU, 4GB RAM)
- **Provisioners**: File copying and shell script execution

### docker-compose.yml

Defines three services:
- `postgresql`: Database with health check and volume persistence
- `conduktor-console`: Main app on port 8080
- `conduktor-monitoring`: Cortex monitoring stack

All services use the `unless-stopped` restart policy and connect via a dedicated network.

### conduktor.env

Environment variables for:
- Database connection (with placeholders replaced on first boot)
- Conduktor Console configuration
- Admin credentials
- Monitoring endpoints

## Management Scripts

Located in `/opt/conduktor/`:

- **start-conduktor.sh** - Start all services
- **stop-conduktor.sh** - Stop all services
- **restart-conduktor.sh** - Restart services (use after config changes)
- **update-conduktor.sh** - Pull latest images and restart
- **logs-conduktor.sh** - View real-time logs

All scripts are executable and include user-friendly output.

## Security Considerations

### Firewall Rules

UFW is configured to allow:
- Port 8080 (Conduktor Console HTTP)
- Port 80 (Reserved for future HTTPS setup)
- Port 443 (Reserved for future HTTPS setup)
- SSH with rate limiting (prevents brute force)

### Secret Generation

- Secrets are generated per-droplet using OpenSSL
- PostgreSQL password: 25 characters (base64, stripped of special chars)
- Admin password: Generated to meet Conduktor requirements (minimum 8 characters including 1 uppercase letter, 1 lowercase letter, 1 number, and 1 special symbol)
- Placeholders ensure unique secrets for each deployment

### Best Practices

Users should:
1. Change the admin password immediately after first login (ensure new password meets requirements: min 8 chars with uppercase, lowercase, number, and special character)
2. Configure HTTPS for production use (reverse proxy)
3. Enable SSO if using in an enterprise environment
4. Regularly apply updates using the update script
5. Backup the PostgreSQL volume

## Customization

### Changing Conduktor Version

Edit `template.json`:
```json
"application_version": "1.40.0"
```

And update the image tag in `files/opt/conduktor/docker-compose.yml`:
```yaml
conduktor-console:
  image: conduktor/conduktor-console:1.40.0
conduktor-monitoring:
  image: conduktor/conduktor-console-cortex:1.40.0
```

### Adjusting Resources

For larger deployments, modify `template.json`:
```json
"size": "s-4vcpu-8gb"
```

### Adding Custom Configuration

Add environment variables to the `conduktor.env` template in `scripts/conduktor-console.sh`.

## Testing

### Local Testing

You can test the Docker Compose setup locally:

```bash
cd /tmp/test-conduktor
cp /path/to/files/opt/conduktor/docker-compose.yml .
cp /path/to/files/opt/conduktor/conduktor.env .

# Set real passwords
sed -i 's/PLACEHOLDER_WILL_BE_REPLACED_ON_FIRST_BOOT/testpassword/g' conduktor.env

# Start services
docker compose --env-file conduktor.env up -d

# Check status
docker compose --env-file conduktor.env ps

# View logs
docker compose --env-file conduktor.env logs -f

# Stop services
docker compose --env-file conduktor.env down
```

### Droplet Testing

After building the image:

1. Create a test droplet from the snapshot
2. SSH into the droplet
3. Verify services are running: `docker ps`
4. Access the web UI at `http://droplet-ip:8080`
5. Check the MOTD displays correctly
6. Test all management scripts
7. Verify passwords in `/opt/conduktor/conduktor.env`

## Troubleshooting

### Build Failures

**Issue**: Packer times out waiting for SSH
- **Solution**: Check your DigitalOcean API token and SSH key configuration

**Issue**: Package installation fails
- **Solution**: Ubuntu repositories may be temporarily unavailable, retry the build

### Runtime Issues

**Issue**: Services won't start
- **Solution**: Check logs with `/opt/conduktor/logs-conduktor.sh`
- Verify Docker is running: `systemctl status docker`
- Check disk space: `df -h`

**Issue**: Cannot access web UI
- **Solution**: Verify firewall: `sudo ufw status`
- Check service health: `docker compose --env-file conduktor.env ps`
- Verify port binding: `netstat -tlnp | grep 8080`

## Maintenance

### Updating Conduktor Console

Users can update using:
```bash
/opt/conduktor/update-conduktor.sh
```

This pulls the latest images and restarts services while preserving data.

### Backup and Restore

Backup volumes:
```bash
docker run --rm -v conduktor_pg_data:/data -v $(pwd):/backup ubuntu tar czf /backup/pg-backup.tar.gz /data
docker run --rm -v conduktor_conduktor_data:/data -v $(pwd):/backup ubuntu tar czf /backup/app-backup.tar.gz /data
```

Restore volumes:
```bash
docker run --rm -v conduktor_pg_data:/data -v $(pwd):/backup ubuntu tar xzf /backup/pg-backup.tar.gz -C /data --strip 1
```

## Support

- **Conduktor Documentation**: https://docs.conduktor.io/
- **Community Slack**: https://conduktor.io/slack
- **GitHub Issues**: https://github.com/conduktor/conduktor-platform/issues
- **DigitalOcean Marketplace**: For 1-Click App specific issues

## License

This Packer configuration is part of the DigitalOcean Marketplace. Conduktor Console itself requires a license for production use. Visit [conduktor.io](https://conduktor.io/) for licensing information.

## Contributing

When contributing updates:

1. Test the build locally
2. Verify the droplet works as expected
3. Update version numbers in all relevant files
4. Update this README if process changes
5. Test all management scripts
6. Submit a pull request with detailed changes

## Version History

- **1.39.0** (Initial Release)
  - Conduktor Console 1.39.0
  - PostgreSQL 14
  - Ubuntu 24.04
  - Docker Compose v2
  - Full management script suite

## Additional Resources

- [Conduktor Console Documentation](https://docs.conduktor.io/)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [DigitalOcean 1-Click App Guidelines](https://marketplace.digitalocean.com/vendors/getting-started-as-a-vendor)
- [Packer Documentation](https://www.packer.io/docs)
