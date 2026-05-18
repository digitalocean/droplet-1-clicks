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

  2. If you set a web password: nginx and Let's Encrypt for this Droplet's public IPv4
     (Certbot shortlived IP profile) and renewal cron. If you skipped the web
     console, Certbot/nginx for the browser are not started until you run
     enable-web-console.sh.

  3. Goose CLI is installed when this Marketplace snapshot is built (not on first
     login), so a failed install blocks the image instead of stranding you on
     first SSH. Binary: /usr/local/bin/goose. Run "goose configure" when you want
     interactive provider setup beyond Gradient.

  4. DigitalOcean Gradient AI (optional): the wizard copies a custom Goose
     provider to ~/.config/goose/custom_providers/ and can store your Gradient
     model access key in:
       - ~/.config/goose/secrets.yaml (with GOOSE_DISABLE_KEYRING so headless
         Droplets do not require a desktop secret service),
       - /etc/profile.d/goose-gradient.sh and a small block in ~/.bashrc so
         DO_GRADIENT_API_KEY is set even for non-login SSH shells.
     Default Goose provider id is digitalocean_gradient with default model minimax-m2.5;
     you do not need to run "goose configure" for Gradient alone.
     In the Goose UI, pick DigitalOcean Gradient (provider id digitalocean_gradient).
     To add or change the key later:

       /opt/goose/configure-gradient-key.sh

     Create a model access key in the DO control panel (Gen AI / Gradient).

     If you upgraded from a snapshot that set GOOSE_PROVIDER to kimi (older
     workaround) or your declarative JSON is stale, run as root:

       /opt/goose/migrate-gradient-provider-id.sh

     That refreshes digitalocean_gradient.json from /opt/goose and rewrites
     GOOSE_PROVIDER to digitalocean_gradient when it was kimi. Re-running
     /opt/goose/configure-gradient-key.sh does the same migration before the key prompt.

     If that script is not on your Droplet yet, set GOOSE_PROVIDER to
     digitalocean_gradient in ~/.config/goose/config.yaml and replace
     ~/.config/goose/custom_providers/digitalocean_gradient.json with the
     version from this 1-Click (the "name" field inside the JSON must be
     digitalocean_gradient).

CHANGE GRADIENT MODEL (e.g. minimax-m2.5 to kimi-k2.5)
======================================================

  Edit /root/.config/goose/config.yaml and set GOOSE_MODEL to one of the "name"
  values in /root/.config/goose/custom_providers/digitalocean_gradient.json
  (for example kimi-k2.5, glm-5, anthropic-claude-4.5-sonnet). Keep
  GOOSE_PROVIDER as digitalocean_gradient. Or run "goose configure" and choose
  another model when offered. Rotating the API key with
  /opt/goose/configure-gradient-key.sh does not overwrite GOOSE_MODEL if it is
  already set.

  Note: kimi-k2.5 can be slow with some Goose builds on Gradient (max_tokens vs
  max_completion_tokens). Prefer minimax-m2.5 as default; upstream Goose can add
  digitalocean_gradient to its OpenAI compat remap list for a full fix.

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
