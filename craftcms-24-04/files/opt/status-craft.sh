#!/bin/bash
echo "=== Craft CMS stack status ==="
for s in mysql php8.3-fpm caddy fail2ban; do
  printf '%-12s %s\n' "$s" "$(systemctl is-active "$s" 2>/dev/null || echo unknown)"
done

echo ""
echo "=== Listening (80/443) ==="
ss -tlnp 2>/dev/null | grep -E ':80 |:443 ' || true

echo ""
if [ -f /var/www/craft/.env ]; then
  echo "PRIMARY_SITE_URL=$(grep -E '^PRIMARY_SITE_URL=' /var/www/craft/.env | cut -d= -f2- | tr -d '"')"
fi

if [ -f /root/.craft_setup_complete ]; then
  echo "Setup: complete"
else
  echo "Setup: pending (SSH as root to run /root/craft_setup.sh)"
fi
