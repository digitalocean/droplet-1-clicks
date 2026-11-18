#!/bin/bash
#
# Builds the Private by Default: Tailscale, cloudflared, ufw baseline,
# a non-root agent user, and the helper commands copied in from files/.

set -euo pipefail

################################
## Package repositories
################################
install -d -m 0755 /usr/share/keyrings

curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg \
  -o /usr/share/keyrings/tailscale-archive-keyring.gpg
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list \
  -o /etc/apt/sources.list.d/tailscale.list

curl -fsSL https://pkg.cloudflare.com/cloudflare-public-v2.gpg \
  -o /usr/share/keyrings/cloudflare-public-v2.gpg
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg] https://pkg.cloudflare.com/cloudflared any main' \
  > /etc/apt/sources.list.d/cloudflared.list

apt-get -qq update
apt-get -qqy install "tailscale=${tailscale_version}"
# Cloudflare's repo only serves the latest cloudflared, so the pin can disappear.
apt-get -qqy install "cloudflared=${cloudflared_version}" || apt-get -qqy install cloudflared

systemctl enable tailscaled

################################
## Agent user
################################
if ! id agent >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" agent
fi

install -m 0440 /etc/private-by-default/sudoers-agent /etc/sudoers.d/90-private-by-default-agent
visudo -cf /etc/sudoers.d/90-private-by-default-agent
rm -f /etc/private-by-default/sudoers-agent

################################
## Firewall
################################
# User data can hold secrets (Tailscale auth key, tunnel token), so the agent
# user may not reach the metadata service.
if ! grep -q 'private-by-default: metadata' /etc/ufw/before.rules; then
  sed -i '0,/^-A ufw-before-output/s||# private-by-default: metadata service is root-only (user data may hold secrets)\n-A ufw-before-output -d 169.254.169.254/32 -m owner --uid-owner agent -j REJECT\n&|' \
    /etc/ufw/before.rules
fi
grep -q 'private-by-default: metadata' /etc/ufw/before.rules

ufw default deny incoming
ufw default allow outgoing
ufw limit 22/tcp
ufw --force enable

################################
## Permissions
################################
chmod 0755 /usr/local/bin/private \
           /usr/local/bin/expose \
           /etc/setup_wizard.sh \
           /etc/update-motd.d/99-one-click \
           /var/lib/cloud/scripts/per-instance/001_onboot
chmod 0644 /etc/private-by-default/AGENTS.md /etc/private-by-default/sshd-hardening.conf \
           /etc/ssh/sshd_config.d/05-private-by-default.conf
chmod 0755 /var/www/private-by-default
chmod 0644 /var/www/private-by-default/index.html /etc/systemd/system/private-welcome.service
install -d -m 0755 /etc/ssh/authorized_keys.d
install -d -m 0700 /var/lib/private-by-default
sshd -t

systemctl daemon-reload

################################
## No per-Droplet identity in the image
################################
systemctl stop tailscaled
rm -rf /var/lib/tailscale/*
