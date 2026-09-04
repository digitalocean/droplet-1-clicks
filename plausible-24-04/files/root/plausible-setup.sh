#!/bin/bash
set -euo pipefail

INSTALL_DIR="/docker/plausible"
CE_REPO="https://github.com/plausible/community-edition.git"
APP_VERSION="v3.2.1"
if [ -f /var/lib/digitalocean/application.info ]; then
	# shellcheck disable=SC1091
	. /var/lib/digitalocean/application.info
	APP_VERSION="${application_version:-$APP_VERSION}"
fi

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

meta() { curl -fsS --retry 5 --retry-connrefused --max-time 2 "$1"; }
DROPLET_PUBLIC_IP="$(meta http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null || true)"
DROPLET_PRIVATE_IP="$(hostname -I | awk '{print $1}')"
DROPLET_IP="${DROPLET_PUBLIC_IP:-$DROPLET_PRIVATE_IP}"

cleanup_docker() {
	echo "Cleaning up existing Plausible containers..."
	if [ -f compose.yml ] || [ -f docker-compose.yml ]; then
		docker compose down -v --remove-orphans 2>/dev/null || true
	fi
	docker ps -a --filter "name=plausible" --format '{{.ID}}' | xargs -r docker rm -f 2>/dev/null || true
}

if [ -d .git ]; then
	remote_url="$(git remote get-url origin 2>/dev/null || true)"
	if [[ "$remote_url" != *community-edition* ]]; then
		echo "Replacing outdated hosting checkout with community-edition..."
		cleanup_docker
		cd /
		rm -rf "$INSTALL_DIR"
		mkdir -p "$INSTALL_DIR"
		cd "$INSTALL_DIR"
		git clone --depth 1 "$CE_REPO" .
	else
		echo "Repository already exists. Updating..."
		cleanup_docker
		git pull --rebase --autostash || true
	fi
else
	echo "Cloning Plausible Community Edition (image pin ${APP_VERSION})..."
	git clone --depth 1 "$CE_REPO" .
fi

# Keep application_version aligned with the compose image tag when present
if grep -q "ghcr.io/plausible/community-edition:" compose.yml 2>/dev/null; then
	image_pin="$(sed -n 's/.*ghcr.io\/plausible\/community-edition:\([^[:space:]]*\).*/\1/p' compose.yml | head -1)"
	if [ -n "$image_pin" ]; then
		APP_VERSION="$image_pin"
	fi
fi

echo "=== Plausible Analytics Setup ==="
echo ""
echo "Choose your setup method:"
echo "1. Use server IP with HTTPS (shortlived TLS) - https://${DROPLET_IP}"
echo "2. Use your own domain (recommended for production) - https://yourdomain.com"
echo ""
read -r -p "Enter your choice (1 or 2): " setup_choice

use_domain=false
if [ "${setup_choice}" = "2" ]; then
	use_domain=true
	echo ""
	echo "DNS Configuration Required:"
	echo "  Create an A record pointing your domain to: ${DROPLET_IP}"
	echo ""
	read -r -p "Enter your domain name: " user_domain
	if [[ ! "$user_domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]]; then
		echo "Invalid domain format."
		exit 1
	fi
	read -r -p "Have you configured the DNS A record? (y/n): " dns_ready
	if [ "$dns_ready" != "y" ]; then
		echo "Configure DNS first, then run this script again."
		exit 1
	fi
	base_url="https://${user_domain}"
else
	base_url="https://${DROPLET_IP}"
fi

secret_key_base="$(openssl rand -base64 48)"

rm -f .env
cat >.env <<EOF
BASE_URL=${base_url}
SECRET_KEY_BASE=${secret_key_base}
DISABLE_REGISTRATION=invite_only
HTTP_PORT=8000
EOF
chmod 600 .env

cp -f /opt/plausible/compose.override.yml "${INSTALL_DIR}/compose.override.yml"

if [ "$use_domain" = true ]; then
	echo "Configuring Caddy for domain ${user_domain}..."
	read -r -p "Enter an email for Let's Encrypt notifications (optional): " le_email
	cat >/etc/caddy/Caddyfile <<CADDYEOC
${user_domain} {
	tls {
		issuer acme {
			dir https://acme-v02.api.letsencrypt.org/directory
			profile shortlived
		}
	}
	reverse_proxy 127.0.0.1:8000
	header X-DO-MARKETPLACE "plausible"
}
CADDYEOC
	if [ -n "${le_email}" ]; then
		sed -i "1iemail ${le_email}" /etc/caddy/Caddyfile
	fi
else
	echo "Configuring Caddy for IP ${DROPLET_IP} with shortlived TLS..."
	cat >/etc/caddy/Caddyfile <<CADDYEOC
${DROPLET_IP} {
	tls {
		issuer acme {
			dir https://acme-v02.api.letsencrypt.org/directory
			profile shortlived
		}
	}
	reverse_proxy 127.0.0.1:8000
	header X-DO-MARKETPLACE "plausible"
}
CADDYEOC
fi

systemctl enable caddy
systemctl restart caddy

echo "Starting Plausible..."
docker compose down -v --remove-orphans 2>/dev/null || true
docker compose up -d

echo "Waiting for Plausible to become ready..."
app_ok=false
for _ in $(seq 1 60); do
	if curl -fsS --max-time 3 "http://127.0.0.1:8000/" >/dev/null 2>&1; then
		app_ok=true
		break
	fi
	sleep 2
done

if [ "$app_ok" != true ]; then
	echo "ERROR: Plausible did not become ready on 127.0.0.1:8000."
	echo "Check: cd /docker/plausible && docker compose logs"
	exit 1
fi

echo "Waiting for HTTPS at ${base_url}..."
tls_ok=false
for _ in $(seq 1 45); do
	if curl -fsSk --max-time 5 "${base_url}/" >/dev/null 2>&1; then
		tls_ok=true
		break
	fi
	sleep 2
done

if [ "$tls_ok" != true ]; then
	echo "ERROR: HTTPS is not available at ${base_url}."
	echo "Not falling back to HTTP. Check DNS (for domains) and:"
	echo "  journalctl -u caddy -n 50 --no-pager"
	echo "  /opt/status-plausible.sh"
	exit 1
fi

# Restore default .bashrc so this first-login script doesn't run again
cp -f /etc/skel/.bashrc /root/.bashrc

echo ""
echo "Plausible Analytics is ready!"
echo "Access URL: ${base_url}"
echo ""
echo "Create the first account at: ${base_url}/register"
echo "The first registrant becomes admin."
echo "Further signups are invite-only (DISABLE_REGISTRATION=invite_only)."
echo ""
echo "Helpers:"
echo "  /opt/status-plausible.sh"
echo "  /opt/setup-plausible-domain.sh   # switch later to a custom domain"
echo "  /opt/start-plausible.sh | /opt/stop-plausible.sh | /opt/restart-plausible.sh"
echo ""
echo "Visit ${base_url}/register to finish setup."
