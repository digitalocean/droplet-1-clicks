Welcome to Goose on DigitalOcean!

Goose is an open source, extensible AI agent for install / execute / edit / test
workflows with the models and providers you choose.

FIRST SSH LOGIN
===============

The first time you log in as root, /opt/goose/first-login-setup.sh runs automatically.

  1. Web console password (HTTPS in the browser, nginx + HTTP Basic Auth -> ttyd).
     Leave the password empty (press Enter twice) if you do not want nginx or a
     public HTTPS terminal. You can enable the web UI later with:

       /opt/goose/enable-web-console.sh

     If you set a password (8+ characters), a copy is saved at
     /root/.goose_web_console_password.txt (mode 600). Remove it when appropriate.

  2. Install the Goose CLI:

       curl -fsSL https://github.com/aaif-goose/goose/releases/download/stable/download_cli.sh | bash

     (The wizard sets GOOSE_BIN_DIR=/usr/local/bin and CONFIGURE=false; run
     "goose configure" when you want interactive provider setup.)

  3. If you chose a web password: Let's Encrypt for this Droplet's public IPv4
     (Certbot shortlived IP profile) and nginx TLS updates. If you skipped the web
     console, Certbot/nginx for the browser are not started until you run
     enable-web-console.sh.

ENABLE WEB CONSOLE LATER
========================

Run as root, from an interactive SSH session:

  /opt/goose/enable-web-console.sh

You will be prompted for the web password (min 8 characters). The script writes
nginx config, starts nginx, obtains a Let's Encrypt IP certificate when possible,
and installs the renewal cron job.

WEB TERMINAL (when nginx is enabled)
====================================

ttyd serves a shell on 127.0.0.1:7681. nginx listens on 80/443, proxies WebSockets
to ttyd, and enforces HTTP Basic authentication (user: goose).

When the web console was skipped, nginx is stopped and disabled; ttyd may still
run for local forwarding.

TLS AND RENEWAL
===============

Certbot is in /opt/certbot-venv. Renewal cron: /etc/cron.d/goose-certbot-renew
(only installed when the web console with TLS has been set up).

FIREWALL
========

UFW allows SSH and HTTP/HTTPS. If you never enable the web console, you may
remove unused HTTP rules with "ufw delete ..." if desired.

DOCUMENTATION
===============

  https://github.com/aaif-goose/goose

For questions, use the upstream project community resources.
