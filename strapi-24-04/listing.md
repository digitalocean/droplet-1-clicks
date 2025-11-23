# Strapi 1-Click Application

Deploy Strapi, the leading open-source headless CMS, on DigitalOcean with this 1-Click application. Strapi gives developers the freedom to use their favorite tools and frameworks while allowing editors to manage and distribute their content using an intuitive admin interface.

## What is Strapi?

Strapi is a flexible, open-source headless CMS that gives developers the freedom to choose their favorite tools and frameworks and allows editors to manage and distribute their content using their application's admin panel. Built with modern JavaScript technologies, Strapi offers:

- **Headless CMS** - RESTful and GraphQL APIs for seamless integration with any frontend
- **Customizable Admin Panel** - User-friendly interface for content management
- **Content Types Builder** - Create and manage data structures without coding
- **Role-Based Access Control** - Fine-grained permissions for users and teams
- **Plugins & Extensions** - Extend functionality with official and community plugins
- **Self-hosted** - Complete control over your data and infrastructure

## Key Features

- Modern, intuitive admin panel
- RESTful and GraphQL API support
- Flexible content modeling with visual builder
- Media library with image optimization
- Role-based access control (RBAC)
- Internationalization (i18n) support
- Draft & publish system
- API documentation generation
- Webhooks for third-party integrations
- Docker-based deployment for easy management
- PostgreSQL database for reliability and performance

## System Components

This 1-Click includes:

- **Strapi v5.0.0** - Latest version of the headless CMS
- **Node.js 22** - JavaScript runtime (Alpine Linux-based)
- **PostgreSQL 16** - Production-ready relational database
- **Docker & Docker Compose** - Container orchestration
- **Ubuntu 24.04 LTS** - Long-term support base system
- **UFW Firewall** - Pre-configured for security

## System Requirements

Strapi is packaged as Docker containers and runs on your DigitalOcean Droplet. Use this guide to choose the appropriate size:

| Use Case | RAM | CPU | Recommended Droplet |
|----------|-----|-----|---------------------|
| Development/Small | 2GB | 1CPU | s-1vcpu-2gb |
| Small Production | 4GB | 2CPU | s-2vcpu-4gb |
| Medium Production | 8GB | 4CPU | s-4vcpu-8gb |
| Large Production | 16GB | 8CPU | s-8vcpu-16gb |

**Note:** The minimum recommended configuration is 2GB RAM and 2 CPUs for production use.

## Getting Started

### Initial Setup

1. **Deploy the Droplet** - Select this 1-Click App from the DigitalOcean Marketplace
2. **Wait for initialization** - The first boot takes 2-3 minutes to generate security keys and start services
3. **Access Strapi** - Navigate to your Droplet's IP address in a web browser:
   ```
   http://your-droplet-ip
   ```

### Create Your Admin Account

On first access to the admin panel, you'll need to create your administrator account:

1. Navigate to `http://your-droplet-ip/admin`
2. Fill in the registration form:
   - First name and last name
   - Email address
   - Password (minimum 8 characters)
3. Click "Let's start" to complete setup

### Building Your First Content Type

1. Log into the admin panel at `/admin`
2. Navigate to **Content-Type Builder** in the sidebar
3. Click **Create new collection type**
4. Define your content structure (e.g., Article, Product, Blog Post)
5. Add fields to your content type (text, media, relations, etc.)
6. Click **Save** and restart Strapi when prompted
7. Navigate to **Content Manager** to create your first entry

### Accessing Your API

Once you've created content types and entries:

- **REST API**: `http://your-droplet-ip/api/[content-type-plural]`
- **API Documentation**: `http://your-droplet-ip/documentation` (if enabled)
- **GraphQL Playground**: `http://your-droplet-ip/graphql` (if GraphQL plugin is installed)

**Important:** By default, API endpoints are protected. Configure permissions in **Settings > Users & Permissions > Roles > Public** to allow public access.

## Configuration

### Environment Configuration

Modify the Strapi configuration by editing the environment file:

```bash
nano /opt/strapi/.env
```

After making changes, restart Strapi:

```bash
systemctl restart strapi
# or use the convenience script:
/opt/restart-strapi.sh
```

### Database Access

The PostgreSQL database is accessible within the Docker network. To connect directly:

```bash
docker exec -it strapiDB psql -U strapi -d strapi
```

Database credentials are stored in `/opt/strapi/.env`

### Domain and SSL Configuration

For production use with a custom domain:

1. **Point your domain to the Droplet**
   - Create an A record pointing to your Droplet's IP address
   - Wait for DNS propagation (5-15 minutes)

2. **Set up a reverse proxy** (recommended for SSL/TLS)
   - Install Nginx or Caddy as a reverse proxy
   - Configure automatic SSL certificates with Let's Encrypt
   - Proxy traffic to port 80 where Strapi is running

3. **Update Strapi configuration**
   - Edit `/opt/strapi/.env`
   - Set `PUBLIC_URL=https://your-domain.com`
   - Restart Strapi: `systemctl restart strapi`

## Management Commands

### Service Control

```bash
# Start Strapi
systemctl start strapi
# or
/opt/start-strapi.sh

# Stop Strapi
systemctl stop strapi
# or
/opt/stop-strapi.sh

# Restart Strapi
systemctl restart strapi
# or
/opt/restart-strapi.sh

# Check status
systemctl status strapi
```

### Viewing Logs

```bash
# View all Strapi logs
docker compose -f /opt/strapi/docker-compose.yml logs -f

# View Strapi application logs only
docker logs -f strapi

# View database logs
docker logs -f strapiDB
```

### Updating Strapi

To update Strapi to the latest version:

```bash
/opt/update-strapi.sh
```

This script will:
1. Stop the current Strapi service
2. Pull the latest Docker images
3. Restart the service with updated containers

**Note:** Always backup your data before updating.

## Backup and Data Management

### Database Backup

Create a backup of your PostgreSQL database:

```bash
docker exec strapiDB pg_dump -U strapi -d strapi > strapi_backup_$(date +%Y%m%d).sql
```

### Restore Database

Restore from a backup:

```bash
cat strapi_backup_YYYYMMDD.sql | docker exec -i strapiDB psql -U strapi -d strapi
```

### Volume Management

Strapi data is stored in Docker volumes:

- `strapi-data` - PostgreSQL database files
- `strapi-app` - Strapi application code
- `strapi-uploads` - Media library uploads

View volumes:
```bash
docker volume ls
```

## Plugins and Extensions

### Installing Plugins

1. Access the admin panel at `/admin`
2. Navigate to **Settings > Marketplace**
3. Browse available plugins
4. Click **Download** on desired plugins
5. Follow installation instructions for each plugin

Popular plugins include:
- **GraphQL** - Add GraphQL support
- **Documentation** - Auto-generate API documentation
- **Email** - Email functionality (SendGrid, Amazon SES, etc.)
- **Upload** - Enhanced media management

### Custom Plugins

To develop custom plugins:
1. Access the Strapi application in the container
2. Use Strapi's plugin development tools
3. Refer to [Strapi Plugin Development Guide](https://docs.strapi.io/dev-docs/plugins-development)

## Security Best Practices

1. **Change Default Port (Optional)**
   - Edit `/opt/strapi/.env` and modify `PORT` variable
   - Update docker-compose port mappings if needed
   - Restart Strapi

2. **Use SSL/TLS in Production**
   - Always use HTTPS for production deployments
   - Configure a reverse proxy with Let's Encrypt

3. **Strong Passwords**
   - Use strong, unique passwords for admin accounts
   - Enable two-factor authentication if available

4. **Regular Updates**
   - Keep Strapi and system packages updated
   - Monitor security advisories

5. **Firewall Configuration**
   - UFW is pre-configured to allow only necessary ports
   - Modify with: `ufw allow [port]/tcp`

6. **Database Security**
   - Database is only accessible within Docker network
   - Credentials are randomly generated on first boot

## Troubleshooting

### Strapi Won't Start

Check service status:
```bash
systemctl status strapi
```

View detailed logs:
```bash
docker compose -f /opt/strapi/docker-compose.yml logs -f
```

### Cannot Access Admin Panel

1. Verify Strapi is running: `systemctl status strapi`
2. Check firewall rules: `ufw status`
3. Ensure port 80 is accessible from your location
4. Wait 2-3 minutes after first boot for full initialization

### Database Connection Issues

1. Check if database container is running: `docker ps`
2. Verify database credentials in `/opt/strapi/.env`
3. Check database logs: `docker logs strapiDB`

### Out of Memory Errors

Strapi requires at least 2GB RAM. If experiencing memory issues:
1. Resize your Droplet to a larger size
2. Check running processes: `htop`
3. Review Docker logs for memory-related errors

## Resources

- **Strapi Documentation**: https://docs.strapi.io/
- **Strapi Community**: https://discord.strapi.io/
- **GitHub Repository**: https://github.com/strapi/strapi
- **API Reference**: https://docs.strapi.io/dev-docs/api/rest
- **Tutorials**: https://strapi.io/tutorials

## Support

For issues specific to this 1-Click application, please contact DigitalOcean support.

For Strapi-specific questions:
- Visit the [Strapi Documentation](https://docs.strapi.io/)
- Join the [Strapi Discord Community](https://discord.strapi.io/)
- Browse [Stack Overflow](https://stackoverflow.com/questions/tagged/strapi)

## License

Strapi is open-source software licensed under the MIT License.
