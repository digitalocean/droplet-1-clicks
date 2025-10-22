# Ruby on Rails on Ubuntu 24.04

## Overview

Ruby on Rails with Docker on Ubuntu 24.04 provides a modern, containerized development environment for building web applications. This one-click application includes the latest Rails framework, PostgreSQL database, and Nginx reverse proxy, all pre-configured and ready to use.

## Features

- **Ruby on Rails** - Latest stable version with modern features
- **Ruby 3.4.7** - Current stable Ruby version optimized for performance
- **PostgreSQL 15** - Robust relational database with advanced features
- **Docker & Docker Compose** - Containerized environment for consistency and portability
- **Nginx Reverse Proxy** - High-performance web server with SSL support
- **Multi-database Configuration** - Separate databases for cache, queue, and cable operations
- **Automatic SSL/TLS Setup** - Ready for HTTPS with Let's Encrypt integration
- **SystemD Integration** - Auto-start on boot with system service management
- **UFW Firewall** - Pre-configured security with essential ports open
- **Loading Page UX** - Professional loading interface during initial setup

## Getting Started

### Initial Setup

1. **Create your Droplet** with the Ruby on Rails one-click application
2. **Wait 2-3 minutes** for the automatic setup to complete
3. **Visit your droplet's IP address** in a web browser
4. **You'll see a loading page** while the application initializes
5. **Once ready**, you'll be redirected to the Rails welcome page

### Accessing Your Application

- **Web Interface**: `http://your-droplet-ip/`
- **Direct Rails Access**: `http://your-droplet-ip:3000/` (if needed)
- **SSH Access**: `ssh root@your-droplet-ip`

### Management Commands

All management scripts are located in `/opt/rails-app/`:

```bash
# Application management
/opt/rails-app/start.sh      # Start the application
/opt/rails-app/stop.sh       # Stop the application
/opt/rails-app/restart.sh    # Restart the application
/opt/rails-app/update.sh     # Update and rebuild containers
/opt/rails-app/logs.sh       # View application logs
```

### Development Workflow

```bash
# Access the Rails container
cd /opt/rails-app
docker-compose exec web bash

# Generate new Rails components
docker-compose exec web bundle exec rails generate controller Welcome
docker-compose exec web bundle exec rails generate model User name:string

# Run database migrations
docker-compose exec web bundle exec rails db:migrate

# Access Rails console
docker-compose exec web bundle exec rails console
```

## Technical Specifications

### Software Stack

- **Operating System**: Ubuntu 24.04 LTS
- **Ruby Version**: 3.4.7
- **Rails Version**: 8.0.3
- **Database**: PostgreSQL 15
- **Web Server**: Nginx (reverse proxy) + Puma (application server)
- **Containerization**: Docker 24.x + Docker Compose

### Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     Nginx       │───▶│   Rails App     │───▶│   PostgreSQL    │
│  (Port 80/443)  │    │   (Port 3000)   │    │   (Port 5432)   │
│  Reverse Proxy  │    │  Puma Server    │    │    Database     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Service Configuration

- **Web Service**: Rails application running on Puma
- **Database Service**: PostgreSQL with persistent storage
- **Proxy Service**: Nginx handling HTTP/HTTPS traffic
- **System Service**: Automatic startup via systemd

### Security Features

- **UFW Firewall**: Configured with essential ports only
- **SSH Rate Limiting**: Protection against brute force attacks
- **Container Isolation**: Services run in separate Docker containers
- **User Permissions**: Non-root user for Rails application
- **SSL Ready**: Pre-configured for HTTPS with certificate automation

