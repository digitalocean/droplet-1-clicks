# DigitalOcean Vendor Portal Listing Copy

Paste-ready content for the 1-Click Droplet Appliance listing at https://cloud.digitalocean.com/vendorportal.

---

## Listing: ERPNext, CRM, HRMS & the Frappe App Ecosystem by Vyogo (`vybench`)

**Name**
```
ERPNext, CRM, HRMS & the Frappe App Ecosystem by Vyogo
```

**Developer / Publisher**
```
Vyogo Technologies
```

**Website**
```
https://vyogo.tech
```

**Tagline** (one line)
```
Turnkey open-source ERPNext, CRM, HRMS & the Frappe app ecosystem on Linux — powered by Vyogo and the FPM catalog
```

**Categories**
```
Business Apps, Developer Tools, Databases
```

**Logo**
`docs/assets/icon.png` in vybench-droplet (512x512 PNG).
Direct: `https://raw.githubusercontent.com/vyogotech/frappe-operator/release/docs/assets/icon.png`

**Short description**
```
Built by Vyogo Technologies, this 1-Click Droplet delivers a turnkey ERPNext, CRM, HRMS, and Frappe app ecosystem powered by vybench and the FPM catalog (https://fpm.vyogo.tech). Get an instant, production-ready ERP system with MariaDB, Redis, and Nginx pre-configured in minutes. Scaling to Kubernetes? Check out the "Operator for ERPNext, CRM, HRMS & the Frappe App Ecosystem by Vyogo" on the DigitalOcean Marketplace. Looking for managed cloud? Visit https://console.vyogo.cloud.
```

**Long description**
```
The ERPNext, CRM, HRMS & the Frappe App Ecosystem Droplet by Vyogo Technologies provides an instant, production-ready appliance for Frappe Framework and the full Frappe business application suite. Powered by the high-performance `vybench` snap and the FPM (Frappe Package Manager) catalog at https://fpm.vyogo.tech, you can launch a fully functional ERPNext system in under two minutes with zero manual setup.

Every component required to run production-grade Frappe workloads — MariaDB 10.11+, Redis 7, Nginx reverse proxy, Python 3.14, Node.js 24, Yarn, wkhtmltopdf, and the latest ERPNext suite — is packaged inside a self-contained, monitored snap environment. No complex dependencies, no compiling frontend assets, and no broken Python venvs.

Powered by FPM:
Through the FPM catalog (https://fpm.vyogo.tech), installing ecosystem apps like Frappe CRM, HRMS, Payments, Helpdesk, or LMS is instantaneous. Apps arrive with pre-compiled assets, eliminating CPU-heavy `yarn build` steps and preventing out-of-memory crashes on Droplets.

Key Highlights:
- Turnkey 1-Click Deployment: Boot the Droplet and your primary ERPNext site is immediately initialized, secured, and ready for use.
- Instant App Installation via FPM: Powered by the FPM catalog (https://fpm.vyogo.tech), install HRMS, CRM, and custom apps with single commands (`vybench.fpm install <app>`).
- Completely Self-Contained Stack: MariaDB, Redis, Nginx, Background Workers, Scheduler, and Socket.io run as supervised systemd services managed by snapd.
- Enterprise Security Out of the Box: Pre-configured UFW firewall (ports 22, 80, 443 only), Fail2ban brute-force protection, randomized root credentials, and Certbot for 1-click Let's Encrypt SSL.
- Simple Multi-Tenancy: Easily host multiple domains and sites on a single Droplet with `vybench.bench new-site`.
- Automated Day-2 Operations: Backup, migrate, restart, and update the entire stack seamlessly with native snap and bench tooling.

Enterprise Scaling & Kubernetes Orchestration:
- DigitalOcean Kubernetes (DOKS): Deploying at enterprise scale across multi-node clusters? Deploy the "Operator for ERPNext, CRM, HRMS & the Frappe App Ecosystem by Vyogo" available on the DigitalOcean 1-Click Marketplace (https://github.com/digitalocean/marketplace-kubernetes/pull/594) for automated multi-bench Kubernetes orchestration, worker autoscaling with KEDA, RWX storage, and dual MariaDB/PostgreSQL support.
- Managed Vyogo Cloud: Looking for fully managed enterprise hosting, multi-region clustering, automated offsite backups, and enterprise SLAs without managing infrastructure? Visit https://console.vyogo.cloud to deploy ERPNext and Frappe apps on Vyogo Cloud.

About Vyogo Technologies:
Vyogo Technologies is an independent software vendor specializing in cloud-native infrastructure, Kubernetes orchestration, and appliance automation for enterprise open-source platforms. Visit https://vyogo.tech for enterprise support.

Notice:
Frappe Framework and ERPNext are open-source trademarks of Frappe Technologies Pvt. Ltd. This 1-Click Droplet is an independent product developed and maintained by Vyogo Technologies and is not affiliated with or endorsed by Frappe Technologies.
```

**Requirements**
```
- Minimum Droplet Size: 2 GB RAM / 1 vCPU (s-1vcpu-2gb) for small teams or testing
- Recommended Droplet Size: 4 GB to 8 GB RAM (s-2vcpu-4gb or s-4vcpu-8gb) for production ERPNext deployments
- Standard SSH client for root administration
```

**What gets installed**
```
- vybench snap (stable channel): Bundles MariaDB 10.11+, Redis 7, Nginx, Python 3.14, Node.js 24, Yarn, wkhtmltopdf, ERPNext, Frappe Bench, and FPM CLI
- Automated first-boot site provisioning service (systemd)
- Certbot (Let's Encrypt automated TLS certificate manager)
- UFW Firewall (allowing only SSH:22, HTTP:80, HTTPS:443)
- Fail2ban intrusion prevention system with SSH jail
- Branded login MOTD with quick reference commands
```

**Post-install instructions**
```
1. Access your Droplet via SSH:
   ssh root@<your-droplet-ip>

2. The login banner displays your credentials immediately. They are also permanently stored at:
   cat /root/.vybench_credentials

3. Access ERPNext in your web browser:
   http://<your-droplet-ip>
   Log in as user 'Administrator' with the generated password.

4. Add a Custom Domain:
   vybench.bench setup add-domain yourdomain.com
   snap restart vybench

5. Enable HTTPS / Let's Encrypt SSL:
   certbot --nginx -d yourdomain.com

6. Install additional apps from FPM (e.g., HRMS, CRM):
   vybench.fpm install hrms
   vybench.bench --site <site-name> install-app hrms

7. Manage stack services:
   snap services vybench
   snap restart vybench
```

**Support**
```
Kubernetes Operator: https://vyogotech.github.io/frappe-operator/
Operator Marketplace Listing: https://github.com/digitalocean/marketplace-kubernetes/pull/594
Managed Cloud: https://console.vyogo.cloud
FPM App Catalog: https://fpm.vyogo.tech
Documentation: https://docs.vyogo.cloud
Issues & Discussions: https://github.com/vyogotech/vybench/issues
Email: support@vyogo.tech
```
