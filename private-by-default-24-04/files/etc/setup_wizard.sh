#!/bin/bash
#
# One-time setup wizard for the Private by Default.
# Runs on the first interactive root login; re-run with: private setup

set -uo pipefail

DONE=/var/lib/private-by-default/wizard-done

[ -t 0 ] && [ -t 1 ] || exit 0
[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo private setup"; exit 1; }
[ "${1:-}" = "--force" ] || [ ! -e "$DONE" ] || exit 0

WARN=$'\e[1;31m'; N=$'\e[0m'

trap 'echo; echo "Setup paused. Run it again anytime with: private setup"; exit 130' INT

banner() {
  cat <<'EOF'

========================================================================
  Private by Default first-login setup
========================================================================
EOF
}
section() {
  printf '\n------------------------------------------------------------------------\n'
  printf '  %s\n' "$1"
  printf -- '------------------------------------------------------------------------\n\n'
}
mark_done() { install -d -m 0700 "${DONE%/*}"; touch "$DONE"; }
status_json() { private status --json 2>/dev/null; }
ts_running() { [ "$(status_json | jq -r '.tailscale.state')" = "Running" ]; }
ssh_open() { [ "$(status_json | jq -r '.public_ssh_open')" = "true" ]; }

step_tailscale_intro() {
  cat <<EOF

To keep this Droplet secure, all inbound ports are BLOCKED except 22 (SSH).

${WARN}⚠️  WARNING: Anyone on the internet can try to log in over SSH.${N}
    Connect Tailscale so SSH only works from your own devices, then close
    port 22. You need a free Tailscale account and the Tailscale app on
    this computer: https://tailscale.com/download

How do you want to continue?

  1) Connect Tailscale now (about 2 minutes)
  2) Not now, remind me at next login
  3) Keep port 22 open and stop asking

EOF
  local c
  read -r -p "Enter 1, 2 or 3 [default: 1]: " c
  case "${c:-1}" in
    1) return 0 ;;
    3) mark_done; echo; echo "OK. Port 22 stays open. Run 'private setup' if you change your mind."; return 1 ;;
    *) echo; echo "OK. You'll see this again at your next login."; return 1 ;;
  esac
}

step_tailscale_connect() {
  section "Step 2 of 4: Connect Tailscale"
  if ts_running; then
    echo "✓ Tailscale is already connected."
    return 0
  fi
  local key
  read -r -s -p "Paste a Tailscale auth key (input hidden), or press Enter for a sign-in link: " key
  echo
  echo
  if [ -n "$key" ]; then
    TAILSCALE_AUTHKEY="$key" private connect --timeout 2m
  else
    private connect --timeout 15m
  fi
  local rc=$?
  unset key
  if [ "$rc" -ne 0 ]; then
    echo
    echo "${WARN}Tailscale did not connect.${N} Port 22 is still open; nothing else changed."
    echo "Try again with: private setup"
    return 1
  fi
}

step_close_ssh() {
  section "Step 3 of 4: Test SSH over Tailscale"
  local name ip
  name=$(status_json | jq -r '.tailscale.dns_name' | cut -d. -f1)
  ip=$(status_json | jq -r '.tailscale.ip')
  cat <<EOF
Keep this window open. On your computer, open a NEW terminal and run:

    ssh root@${name}
    (or: ssh root@${ip})

Your computer needs Tailscale running and signed in to the same account.

EOF
  local ans
  read -r -p "Did it work? Enter y or n [default: n]: " ans
  case "$ans" in
    y|Y|yes|YES)
      if private close-ssh --yes >/dev/null; then
        mark_done
        cat <<EOF

✓ Port 22 is closed. SSH now works only over Tailscale.

Locked out later? Control panel > Droplet > Settings > Recovery console,
log in as root, then run: private open-ssh
(Set a root password first under Settings > Reset root password.)

Tip: in the Tailscale admin console, turn off key expiry for this machine.
EOF
      fi
      ;;
    *)
      cat <<EOF

No problem. Port 22 stays open. Common fixes:
  * Make sure Tailscale is running on your computer and signed in to the same account.
  * Try the IP address instead of the name: ssh root@${ip}
When it works, run: private close-ssh
EOF
      ;;
  esac
}

front_door_free() { ! ss -ltnH "sport = :8080" 2>/dev/null | grep -q .; }

step_web() {
  section "Optional: Public web address (step 4 of 4)"
  cat <<EOF
Ports 80 and 443 stay closed. Visitors reach your app through an outbound
Cloudflare tunnel. Your app's front door is localhost:8080.

  1) Skip for now
  2) Show me a test page (temporary URL, no account needed)
  3) Use my own domain (paste a Cloudflare Tunnel token)

EOF
  local c
  read -r -p "Enter 1, 2 or 3 [default: 1]: " c
  case "${c:-1}" in
    2)
      front_door_free && private welcome on >/dev/null
      echo
      expose 8080 || true
      echo
      echo "To put your app here: run 'private welcome off', then start your app"
      echo "on port 8080. The URL stays the same."
      ;;
    3)
      echo
      echo "Create a tunnel in the Cloudflare dashboard (Zero Trust > Networks > Tunnels),"
      echo "choose Debian, and copy the token from the install command."
      echo
      if private tunnel; then
        front_door_free && private welcome on >/dev/null
        echo
        echo "Your hostname shows a welcome page until you run 'private welcome off'"
        echo "and start your app on port 8080."
      fi
      ;;
    *) echo; echo "Skipped. Run 'private welcome on' and 'expose 8080' anytime." ;;
  esac
}

if ! ssh_open; then
  mark_done
  [ "${1:-}" = "--force" ] || exit 0
  banner
else
  banner
  if step_tailscale_intro && step_tailscale_connect; then
    step_close_ssh
  fi
fi
step_web

echo
if ssh_open; then
  echo "Setup finished. Port 22 is still open; run 'private setup' anytime."
else
  echo "Setup complete!"
fi
echo
private status
echo
