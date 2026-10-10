# Twenty CRM 1-Click Application

Deploy [Twenty](https://twenty.com), the open-source CRM designed for technical teams, on DigitalOcean with this 1-Click application. Twenty gives you objects, views, workflows, and AI agents with the flexibility to extend everything as code.

## What is Twenty?

Twenty is the open alternative to Salesforce — a modern CRM you can build, ship, and version like the rest of your stack. Built with TypeScript, NestJS, React, PostgreSQL, and Redis, Twenty offers:

- **Custom objects and fields** — Model your business data without rigid schemas
- **Views and pipelines** — Kanban, table, and filter views for every workflow
- **Workflows and automation** — Automate repetitive CRM tasks
- **AI agents** — Built-in AI capabilities for modern sales teams
- **Self-hosted** — Full control over your data and infrastructure
- **Open source** — MIT-licensed with an active community

## Key Features

- Modern, intuitive CRM interface
- Flexible data model with custom objects
- REST and GraphQL APIs
- Workflow automation
- Email and calendar integrations (configurable)
- Role-based access control
- Docker-based deployment for reliable operations
- HTTPS via Caddy with Let's Encrypt short-lived IP certificates

## System Components

This 1-Click includes:

- **Twenty CRM v2.8.3** — Latest stable release (`twentycrm/twenty` Docker image)
- **PostgreSQL 16** — Primary database
- **Redis** — Job queue and caching
- **Caddy** — Reverse proxy with automatic HTTPS
- **Docker & Docker Compose** — Container orchestration
- **Ubuntu 24.04 LTS** — Long-term support base system
- **UFW Firewall** — Pre-configured for security

## System Requirements

Twenty requires at least **2GB RAM**. Use these Droplet sizes as a guide:

| Use Case | RAM | CPU | Recommended Droplet |
|----------|-----|-----|---------------------|
| Evaluation | 2GB | 2 CPU | s-2vcpu-2gb |
| Small team | 4GB | 2 CPU | s-2vcpu-4gb |
| Production | 8GB | 4 CPU | s-4vcpu-8gb |

## Getting Started

### Initial Setup

1. **Deploy the Droplet** — Select this 1-Click App from the DigitalOcean Marketplace
2. **Wait for initialization** — First boot takes 3–5 minutes while the database initializes
3. **Access Twenty** — Open your Droplet's IP in a browser:
   ```
   https://your-droplet-ip
   ```

### Create Your Workspace

On first visit, Twenty walks you through workspace setup:

1. Navigate to `https://your-droplet-ip`
2. Create your workspace name
3. Sign up with your email and password
4. Invite team members from Settings

### Custom Domain (Optional)

To use your own domain with HTTPS:

1. Point an A record at your Droplet's IP address
2. SSH into the Droplet and run:
   ```bash
   /opt/twenty/setup-twenty-domain.sh
   ```
3. Enter your domain when prompted
4. Twenty restarts with the updated `SERVER_URL`

## Configuration

### Environment Variables

Edit the configuration file:

```bash
nano /opt/twenty/.env
```

Key variables:

- `SERVER_URL` — Public URL users access in their browser (must match how they connect)
- `ENCRYPTION_KEY` — Protects stored secrets; do not change after setup without following the key rotation guide
- `PG_DATABASE_PASSWORD` — PostgreSQL password
- `TAG` — Docker image version (e.g. `v2.8.3`)

After changes, restart:

```bash
systemctl restart twenty
```

## Management Commands

### Service Control

```bash
# Start
systemctl start twenty
/opt/twenty/start-twenty.sh

# Stop
systemctl stop twenty
/opt/twenty/stop-twenty.sh

# Restart
systemctl restart twenty
/opt/twenty/restart-twenty.sh

# Status
/opt/twenty/status-twenty.sh
systemctl status twenty
```

### Viewing Logs

```bash
docker compose -f /opt/twenty/docker-compose.yml logs -f
docker compose -f /opt/twenty/docker-compose.yml logs -f server
```

### Updating Twenty

```bash
/opt/twenty/update-twenty.sh
```

This pulls the latest Docker images for the configured `TAG` and restarts services. To pin a specific version, set `TAG` in `/opt/twenty/.env` before updating.

## Backup and Restore

### Database Backup

```bash
docker exec twenty-db-1 pg_dump -U postgres default > backup_$(date +%Y%m%d).sql
```

### Restore

```bash
docker compose -f /opt/twenty/docker-compose.yml stop server worker
docker exec -i twenty-db-1 psql -U postgres default < backup_20240115.sql
docker compose -f /opt/twenty/docker-compose.yml up -d
```

## Security Best Practices

1. **Protect `/opt/twenty/.env`** — Contains encryption keys and database credentials
2. **Use a custom domain** — Run `/opt/twenty/setup-twenty-domain.sh` for production
3. **Regular backups** — Back up the PostgreSQL database and Docker volumes
4. **Keep updated** — Run `/opt/twenty/update-twenty.sh` periodically
5. **Strong passwords** — Use strong credentials for workspace admin accounts

## Troubleshooting

### Twenty won't start

```bash
/opt/twenty/status-twenty.sh
docker compose -f /opt/twenty/docker-compose.yml logs -f
```

### Cannot access the web interface

1. Verify services: `systemctl status twenty caddy`
2. Check firewall: `ufw status`
3. Wait 3–5 minutes after first boot for database migrations

### Out of memory

Twenty needs at least 2GB RAM. Resize your Droplet if containers crash or restart frequently.

## Resources

- **Documentation**: https://docs.twenty.com/
- **GitHub**: https://github.com/twentyhq/twenty
- **Docker Compose guide**: https://docs.twenty.com/developers/self-host/capabilities/docker-compose
- **Discord**: https://discord.gg/twenty

## Support

For issues with this 1-Click application, contact DigitalOcean support.

For Twenty-specific questions, see the [Twenty documentation](https://docs.twenty.com/) and [GitHub issues](https://github.com/twentyhq/twenty/issues).

## License

Twenty is open-source software. See the [Twenty repository](https://github.com/twentyhq/twenty) for license details.
