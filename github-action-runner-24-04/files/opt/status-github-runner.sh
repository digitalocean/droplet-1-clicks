#!/bin/bash
echo "=== GitHub Actions Runner Status ==="
systemctl status actions-runner --no-pager || true

echo ""
echo "=== Registration ==="
if [ -f /home/runner/actions-runner/.runner ]; then
  echo "Registered: yes (/home/runner/actions-runner/.runner present)"
else
  echo "Registered: no — run /etc/setup-github-runner.sh"
fi

echo ""
echo "=== Version ==="
if [ -f /var/lib/digitalocean/application.info ]; then
  grep -E '^application_(name|version)=' /var/lib/digitalocean/application.info || true
fi
