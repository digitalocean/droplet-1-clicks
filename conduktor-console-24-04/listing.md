# Conduktor Console 1-Click Application

Deploy Conduktor Console, a powerful web-based UI for Apache Kafka that simplifies monitoring, troubleshooting, and managing your Kafka ecosystem. Conduktor Console provides comprehensive visibility into your Kafka infrastructure with an intuitive interface that consolidates all Kafka APIs into one place.

## What is Conduktor Console?

Conduktor Console is an enterprise-grade platform for managing Apache Kafka clusters, designed to make Kafka accessible to developers and platform engineers. It provides:

- **Kafka Cluster Management** - Monitor and manage multiple Kafka clusters from a single interface
- **Topic Management** - Browse, create, configure, and monitor Kafka topics with ease
- **Consumer Group Monitoring** - Track consumer lag, offset management, and consumer group health
- **Schema Registry Integration** - Manage Avro, Protobuf, and JSON schemas with full versioning
- **Data Browsing and Production** - View and produce messages with automatic schema detection
- **Kafka Connect Management** - Deploy and monitor connectors with an intuitive UI
- **ksqlDB Integration** - Execute SQL queries on your streaming data
- **Security and Access Control** - Built-in RBAC, SSO, and audit logging
- **Monitoring and Alerts** - Real-time metrics, dashboards, and alerting capabilities

## Key Features

### Kafka Management
- Multi-cluster support with easy cluster switching
- Real-time metrics and health monitoring
- Topic creation, configuration, and partition management
- Consumer group lag monitoring and offset reset
- ACL management for security

### Data Operations
- Browse and search Kafka messages with filters
- Produce messages with schema validation
- Support for Avro, Protobuf, JSON, and custom deserializers
- Data masking and encryption support

### Developer Experience
- Intuitive web-based interface
- REST API for automation
- CLI for infrastructure-as-code workflows
- Custom deserializer support
- Shareable message links

### Enterprise Features
- Role-based access control (RBAC)
- Single Sign-On (SSO) integration
- Audit logging for compliance
- Self-service topic catalog
- Application-level access management

## System Requirements

Conduktor Console is packaged as Docker containers and runs on your DigitalOcean Droplet. Choose the appropriate droplet size based on your needs:

| Use Case | RAM | CPU | Recommended For |
|----------|-----|-----|----------------|
| Development/Testing | 4GB | 2 CPU | Small clusters, learning |
| Small Production | 8GB | 4 CPU | 1-5 Kafka clusters |
| Medium Production | 16GB | 8 CPU | 5-20 Kafka clusters |
| Large Production | 32GB | 16 CPU | 20+ Kafka clusters, heavy workloads |

## Getting Started

### Quick Start

1. **Deploy the Droplet**
   - Select this 1-Click App from the DigitalOcean Marketplace
   - Choose your droplet size (minimum 2 CPU / 4GB RAM recommended)
   - Wait for the droplet to be created and initialized

2. **Access Conduktor Console**
   - Navigate to `http://your-droplet-ip:8080` in your web browser
   - Login with the default credentials shown in the MOTD (visible when you SSH into the droplet)
   - **Important:** Change the default admin password immediately after first login

3. **Connect Your First Kafka Cluster**
   - Click "Add Cluster" in the Conduktor Console UI
   - Enter your Kafka broker addresses and authentication details
   - Test the connection and save

### Initial Configuration

After deployment, SSH into your droplet to retrieve the admin credentials:

```bash
ssh root@your-droplet-ip
```

The welcome message will display:
- The URL to access Conduktor Console
- The default admin email
- The location of the configuration file containing the admin password

The admin password is stored in `/opt/conduktor/conduktor.env`

### Changing the Organization Name

To customize your organization name:

1. Edit the configuration file:
   ```bash
   nano /opt/conduktor/conduktor.env
   ```

2. Update the `CDK_ORGANIZATION_NAME` variable:
   ```
   CDK_ORGANIZATION_NAME=your-company-name
   ```

3. Restart Conduktor Console:
   ```bash
   /opt/conduktor/restart-conduktor.sh
   ```

### Configuring Email Notifications

To enable email alerts, edit `/opt/conduktor/conduktor.env` and add:

```bash
CDK_SMTP_HOST=smtp.your-provider.com
CDK_SMTP_PORT=587
CDK_SMTP_USERNAME=your-username
CDK_SMTP_PASSWORD=your-password
CDK_SMTP_FROM=conduktor@your-domain.com
```

Then restart the service.

## Managing Conduktor Console

### Starting, Stopping, and Restarting

Conduktor Console provides convenient management scripts:

```bash
# Start Conduktor Console
/opt/conduktor/start-conduktor.sh

# Stop Conduktor Console
/opt/conduktor/stop-conduktor.sh

# Restart Conduktor Console (use this after configuration changes)
/opt/conduktor/restart-conduktor.sh

# View logs
/opt/conduktor/logs-conduktor.sh
```

### Updating Conduktor Console

To update to the latest version:

```bash
/opt/conduktor/update-conduktor.sh
```

This script will:
- Pull the latest Docker images
- Restart all services with the new versions
- Preserve all your data and configuration

### Viewing Logs

To troubleshoot or monitor Conduktor Console:

```bash
/opt/conduktor/logs-conduktor.sh
```

Press `Ctrl+C` to exit the log view.

## Configuration

All configuration is stored in `/opt/conduktor/conduktor.env`. After making changes, always restart the service:

```bash
/opt/conduktor/restart-conduktor.sh
```

### Key Configuration Options

- `CDK_ORGANIZATION_NAME` - Your organization name (displayed in the UI)
- `CDK_ADMIN_EMAIL` - Admin user email
- `CDK_ADMIN_PASSWORD` - Admin user password (auto-generated; must contain at least 8 characters including 1 uppercase letter, 1 lowercase letter, 1 number and 1 special symbol)
- `POSTGRES_PASSWORD` - PostgreSQL database password (auto-generated)
- `CDK_DATABASE_URL` - PostgreSQL connection string

**Note:** When changing the admin password manually, ensure it meets the security requirements: minimum 8 characters with at least one uppercase letter, one lowercase letter, one number, and one special character (!@#$%^&*).

### Advanced Configuration

For advanced configurations including:
- SSO integration (LDAP, SAML, OAuth)
- Custom deserializers
- High availability setup
- Performance tuning

Please refer to the official [Conduktor documentation](https://docs.conduktor.io/).

## Connecting to Kafka Clusters

Conduktor Console supports connecting to:

- **Apache Kafka** - Self-hosted or managed
- **Amazon MSK** - AWS Managed Streaming for Kafka
- **Confluent Cloud** - Confluent's managed Kafka service
- **Azure Event Hubs** - Azure's Kafka-compatible service
- **Aiven for Apache Kafka** - Aiven's managed Kafka
- **Redpanda** - Kafka-compatible streaming platform
- **Strimzi** - Kubernetes-native Kafka

Each cluster type has specific connection requirements. Refer to the Conduktor Console documentation for detailed connection guides.

## Security Best Practices

1. **Change Default Password** - Immediately change the admin password after first login
2. **Use Strong Passwords** - Generate strong, unique passwords for all accounts
3. **Enable HTTPS** - Set up a reverse proxy (nginx/traefik) with SSL certificates for production use
4. **Firewall Configuration** - The droplet is configured with UFW firewall allowing only necessary ports
5. **Regular Updates** - Keep Conduktor Console updated using the update script
6. **Backup Database** - Regularly backup the PostgreSQL data volume
7. **Access Control** - Use RBAC features to limit user access appropriately

## Data Persistence

Conduktor Console uses Docker volumes for data persistence:

- `pg_data` - PostgreSQL database
- `conduktor_data` - Conduktor Console application data
- `cortex_data` - Monitoring data

These volumes persist across container restarts and updates. To backup your data:

```bash
docker run --rm -v conduktor_pg_data:/data -v $(pwd):/backup ubuntu tar czf /backup/conduktor-backup.tar.gz /data
```

## Troubleshooting

### Services Not Starting

Check service status:
```bash
cd /opt/conduktor
docker compose --env-file conduktor.env ps
```

View detailed logs:
```bash
/opt/conduktor/logs-conduktor.sh
```

### Cannot Access Web UI

1. Verify services are running:
   ```bash
   docker compose --env-file /opt/conduktor/conduktor.env ps
   ```

2. Check firewall rules:
   ```bash
   sudo ufw status
   ```

3. Ensure port 8080 is accessible

### Database Connection Issues

If Conduktor Console cannot connect to PostgreSQL:

1. Check if PostgreSQL is healthy:
   ```bash
   docker compose --env-file /opt/conduktor/conduktor.env ps postgresql
   ```

2. Verify database credentials in `/opt/conduktor/conduktor.env`

3. Restart all services:
   ```bash
   /opt/conduktor/restart-conduktor.sh
   ```

### Console Container Keeps Restarting

If the console container is restarting with password validation errors:

1. Check the logs:
   ```bash
   /opt/conduktor/logs-conduktor.sh
   ```

2. If you see "Password must contain at least 8 characters including 1 uppercase letter, 1 lowercase letter, 1 number and 1 special symbol", the admin password doesn't meet requirements.

3. Generate a new compliant password and update the config:
   ```bash
   # Generate a compliant password (example: use a password manager or this command)
   NEW_PASS=$(pwgen -s -1 16)
   
   # Update the environment file
   sudo sed -i "s/CDK_ADMIN_PASSWORD=.*/CDK_ADMIN_PASSWORD=$NEW_PASS/" /opt/conduktor/conduktor.env
   
   # Restart services
   /opt/conduktor/restart-conduktor.sh
   ```

## Support and Resources

- **Official Documentation:** https://docs.conduktor.io/
- **Community Slack:** https://conduktor.io/slack
- **GitHub Repository:** https://github.com/conduktor/conduktor-platform
- **Changelog:** https://www.conduktor.io/changelog
- **DigitalOcean Support:** For droplet-specific issues, contact DigitalOcean support

## System Components

This 1-Click App includes:

- **Conduktor Console 1.39.0** - Main application
- **Conduktor Monitoring (Cortex) 1.39.0** - Metrics and monitoring
- **PostgreSQL 14** - Database backend
- **Docker & Docker Compose** - Container runtime
- **UFW Firewall** - Pre-configured security rules

## License

Conduktor Console requires a license for production use. The application includes:
- **Free tier** - Limited features for small deployments
- **Enterprise license** - Full features for production environments

Visit [conduktor.io](https://conduktor.io/) to learn more about licensing options.

## Additional Notes

- Default port: 8080 (HTTP)
- Minimum supported Kafka version: 0.10.0+
- Supports all major Kafka providers
- Web-based interface requires modern browser (Chrome, Firefox, Safari, Edge)
- CLI and API available for automation

For production deployments, consider:
- Setting up HTTPS with a reverse proxy
- Configuring SSO for team access
- Enabling backup automation
- Monitoring resource usage and scaling as needed
