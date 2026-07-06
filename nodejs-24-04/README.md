# Node.js 1-Click

Deploy Node.js on Ubuntu 24.04 with Nginx and PM2. A sample application runs at `/var/www/html/hello.js` and is served via Nginx on port 80. You can optionally attach a DigitalOcean Managed MongoDB database during deployment.

## Getting Started

1. Select the Node.js 1-Click from the DigitalOcean Marketplace
2. Choose a Droplet size and region
3. Optionally select **Add a Database** to provision a Managed MongoDB database (see below)
4. Create the Droplet

After you create a Droplet, navigate to its public IPv4 address in a browser to see the sample application live.

To SSH into the Droplet, you will be prompted for a password. If you created your Droplet with a root user password, enter that password. If you created your Droplet with an SSH key, enter the passphrase associated with your key.

```bash
ssh root@your-droplet-ip
```

**SFTP access** (for uploading files):

- **User:** `nodejs`
- **Password:** stored in `/root/.digitalocean_passwords` (`NODE_USER_PASSWORD`)

## Using MongoDB Database-as-a-Service

When creating your Node.js Droplet, you can select **Add a Database** to provision a DigitalOcean Managed MongoDB cluster at the same time. A managed database can replace a self-hosted one to better secure your data and gives you easy backups, connection pools, and metrics.

### What happens when you add a database

When you choose this option during Droplet creation, DigitalOcean:

1. Provisions a Managed MongoDB cluster in the same region as your Droplet
2. Passes connection credentials to your Droplet at first boot in `/root/.digitalocean_dbaas_credentials`
3. Exposes a `DATABASE_URL` environment variable containing the full MongoDB connection string

The Managed MongoDB cluster may take up to five minutes after creation before it is ready for connections. The sample Node.js application is not automatically configured to use the managed database — update your application code to connect using `DATABASE_URL` or the credentials in `/root/.digitalocean_dbaas_credentials`.

### Sample MongoDB connection

Here is a sample Node.js app showing a connection to the MongoDB database:

```js
const { MongoClient } = require('mongodb');

async function main() {
    /**
     * Connection URI. Use the DATABASE_URL environment variable, or build the
     * connection string from /root/.digitalocean_dbaas_credentials.
     * See https://docs.mongodb.com/ecosystem/drivers/node/ for more details
     */
    const uri = process.env.DATABASE_URL || '<your-mongo-connection-string>';

    const client = new MongoClient(uri);

    try {
        await client.connect();
        await listDatabases(client);
    } catch (e) {
        console.error(e);
    } finally {
        await client.close();
    }
}

async function listDatabases(client) {
    const databasesList = await client.db().admin().listDatabases();

    console.log('Connected successfully. Databases:');
    databasesList.databases.forEach(db => console.log(` - ${db.name}`));
}

main().catch(console.error);
```

### Security: Trusted Sources

Your Droplet is not automatically added to the Managed Database's trusted sources. For better security, add your Droplet's public IP address to the database cluster's **Trusted Sources** in the [DigitalOcean control panel](https://cloud.digitalocean.com/databases):

1. Open your database cluster in the control panel
2. Go to **Settings** → **Trusted Sources**
3. Add your Droplet's public IP address

### Modifying database settings later

- **Connection string:** `DATABASE_URL` environment variable or `/root/.digitalocean_dbaas_credentials`
- **Password rotation:** If you change credentials in the control panel, update your application's MongoDB connection string to match

## Deploying Your Own Application

### Step 1: Access your Droplet

```bash
ssh root@your-droplet-ip
```

### Step 2: Modify the sample application

Edit the sample script at `/var/www/html/hello.js`. The application runs as the `nodejs` user via PM2, so run PM2 commands as that user:

```bash
sudo -u nodejs pm2 restart hello
```

### Step 3: Get your code onto the Droplet

Clone your Node.js code onto the Droplet anywhere you like. If you're not using source control, you can [upload files directly using SFTP](https://www.digitalocean.com/community/tutorials/how-to-use-sftp-to-securely-transfer-files-with-a-remote-server).

```bash
cd /path/to/your/app
npm install
sudo -u nodejs pm2 start <your-file>
```

Map the port your app runs on to an HTTP URL by editing the Nginx config:

```bash
nano /etc/nginx/sites-available/default
```

Edit the existing entry that exposes the `hello` app at port 3000 so that it points to your app's port instead. Then enable the new config:

```bash
systemctl restart nginx
sudo -u nodejs pm2 save
```

Repeat these steps for any other Node.js apps that need to run concurrently — schedule them to run at boot time on whatever internal port you like using PM2, then map that port to an HTTP/HTTPS URL in the Nginx config. Build out the URL directory structure you need by mapping applications to URL paths; that's the reverse proxy method in a nutshell.

To remove the sample app:

```bash
sudo -u nodejs pm2 delete hello
sudo -u nodejs pm2 save
```

### Step 4: Get production-ready

Popular steps before going to production:

- **Non-root user:** [Set up a non-root user for day-to-day use](https://www.digitalocean.com/community/tutorials/initial-server-setup-with-ubuntu-18-04)
- **Firewall:** Review settings with `sudo ufw status`. By default, only SSH/SFTP (port 22), HTTP (port 80), and HTTPS (port 443) are open. You can disable the local firewall with `sudo ufw disable` and [use a DigitalOcean Cloud Firewall](https://docs.digitalocean.com/products/networking/firewalls/) instead
- **Domain:** [Register a custom domain](https://docs.digitalocean.com/products/networking/dns/)
- **Storage:** Mount a [Volume](https://docs.digitalocean.com/products/volumes/) (up to 16 TB) to expand the filesystem, provision a [Managed Database](https://docs.digitalocean.com/products/databases/) cluster, or use a [Space](https://docs.digitalocean.com/products/spaces/) (S3-compatible object storage)

## Droplet Summary

- UFW firewall allows SSH (port 22, rate limited), HTTP (port 80), and HTTPS (port 443)
- Sample app: `/var/www/html/hello.js` on port 3000, proxied by Nginx on port 80
- Application user: `nodejs` (password in `/root/.digitalocean_passwords`)
- Managed MongoDB credentials: `/root/.digitalocean_dbaas_credentials` and `DATABASE_URL` (when **Add a Database** was selected)
- Nginx config: `/etc/nginx/sites-available/default`
- Setup log: `/var/log/one_click_setup.log`

## Additional Resources

- [Node.js 1-Click Quickstart](https://do.co/313ycRT)
