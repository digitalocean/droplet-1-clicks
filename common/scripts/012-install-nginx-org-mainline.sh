#!/bin/bash
# Replace Ubuntu's nginx packages with nginx.org mainline >= 1.31.9 (CVE-2026-123007).
set -euo pipefail

NGINX_MIN_MAJOR=1
NGINX_MIN_MINOR=31
NGINX_MIN_PATCH=9

# Keep certbot when Ubuntu nginx meta-packages are swapped out.
for pkg in certbot python3-certbot python3-certbot-nginx; do
  if dpkg -l "${pkg}" 2>/dev/null | awk '/^ii/ {found=1} END {exit !found}'; then
    apt-mark manual "${pkg}" 2>/dev/null || true
  fi
done

cat >/etc/apt/preferences.d/digitalocean-no-apache2-on-nginx-swap <<'EOF'
Package: apache2 apache2-bin apache2-data apache2-utils libapache2-mod-md
Pin: release *
Pin-Priority: -1
EOF

install -d -m 0755 /usr/share/keyrings /etc/apt/preferences.d

curl -fsSL https://nginx.org/keys/nginx_signing.key |
  gpg --dearmor -o /usr/share/keyrings/nginx-archive-keyring.gpg

codename=$(lsb_release -cs)
cat >/etc/apt/sources.list.d/nginx.list <<EOF
deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/mainline/ubuntu ${codename} nginx
EOF

cat >/etc/apt/preferences.d/nginx-org-pin <<EOF
Package: nginx nginx-common nginx-core nginx-full nginx-light nginx-extras
Pin: origin nginx.org
Pin-Priority: 1001
EOF

apt-get -y update

madison_nginx=$(apt-cache madison nginx 2>/dev/null || true)
if grep '1\.31\.9-1~' <<<"${madison_nginx}" >/dev/null; then
  nginx_pkg="nginx=1.31.9-1~${codename}"
else
  nginx_pkg="nginx"
fi

# Swap Ubuntu nginx for nginx.org without a dependency window where apt picks apache2.
DEBIAN_FRONTEND=noninteractive apt-get -y -o APT::Install-Recommends=false \
  -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' \
  install --no-install-recommends "${nginx_pkg}" || {
  DEBIAN_FRONTEND=noninteractive apt-get -y -o APT::Install-Recommends=false \
    -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' \
    remove nginx nginx-common nginx-core nginx-full nginx-light nginx-extras 2>/dev/null || true
  DEBIAN_FRONTEND=noninteractive apt-get -y -o APT::Install-Recommends=false \
    -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' \
    install --no-install-recommends "${nginx_pkg}"
}

DEBIAN_FRONTEND=noninteractive apt-get -y -o APT::Install-Recommends=false \
  install --no-install-recommends certbot python3-certbot-nginx

if dpkg -l apache2 2>/dev/null | awk '/^ii/ {found=1} END {exit !found}'; then
  echo "ERROR: apache2 installed during nginx.org swap; aborting" >&2
  dpkg -l apache2 >&2 || true
  exit 1
fi

ver=$(nginx -v 2>&1 | sed -n 's/.*nginx\/\([0-9.]*\).*/\1/p')
if [ -z "${ver}" ]; then
  echo "ERROR: unable to read nginx version" >&2
  exit 1
fi

major=$(echo "${ver}" | cut -d. -f1)
minor=$(echo "${ver}" | cut -d. -f2)
patch=$(echo "${ver}" | cut -d. -f3)

version_ok=0
if [ "${major}" -gt "${NGINX_MIN_MAJOR}" ]; then
  version_ok=1
elif [ "${major}" -eq "${NGINX_MIN_MAJOR}" ] && [ "${minor}" -gt "${NGINX_MIN_MINOR}" ]; then
  version_ok=1
elif [ "${major}" -eq "${NGINX_MIN_MAJOR}" ] && [ "${minor}" -eq "${NGINX_MIN_MINOR}" ] && [ "${patch}" -ge "${NGINX_MIN_PATCH}" ]; then
  version_ok=1
fi

if [ "${version_ok}" -ne 1 ]; then
  echo "ERROR: nginx ${ver} is below CVE-2026-123007 fix floor (need >=1.31.9)" >&2
  exit 1
fi

# shellcheck source=/dev/null
source /var/lib/digitalocean/nginx-org-layout.sh
nginx_org_ensure_sites_enabled_layout
nginx_org_install_regression_checks

systemctl enable nginx 2>/dev/null || true
echo "Installed nginx ${ver} from nginx.org mainline"