# PMM3 DigitalOcean Marketplace 1-Click App

Packer templates and scripts to build a DigitalOcean Marketplace 1-Click App for:

**[PMM3](https://github.com/percona/pmm)** - Percona Monitoring and Management 3, an open source database monitoring solution

## For End Users

Once the PMM3 image is approved and available in the Marketplace, users can deploy it by:

1. Selecting "Percona Monitoring and Management 3" from the DigitalOcean Marketplace.
2. Creating a Droplet based on the image (minimum 2GB RAM recommended).
3. SSH'ing into the Droplet, where they'll see the welcome screen with access information.
4. Accessing the PMM3 web interface at `https://YOUR_DROPLET_IP:443`
5. Logging in with default credentials (admin/admin) and changing the password immediately.
6. Adding their databases for monitoring.

### DigitalOcean Database Integration

For users with DigitalOcean Managed Databases, the Droplet includes a convenient integration script:

```bash
python3 /root/pmm-do.py
```

This script will:
- Automatically discover MySQL databases in your DigitalOcean account
- Guide you through adding them to PMM3 monitoring
- Configure optimal monitoring settings including Query Analytics
- Set up proper authentication and security settings

## Troubleshooting

If you encounter issues during the build:

1. Add the `-debug` flag to prompt for confirmation at each build step:
   ```bash
   packer build -debug pmm3-24-04/template.json
   ```

2. Use the `-on-error=ask` flag to debug failed builds:
   ```bash
   packer build -on-error=ask pmm3-24-04/template.json
   ```

3. Enable verbose logging:
   ```bash
   PACKER_LOG=1 packer build pmm3-24-04/template.json
   ```

## License

PMM3 (Percona Monitoring and Management) is licensed under the Apache License 2.0.
