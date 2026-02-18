#!/usr/bin/env bash
set -euo pipefail

# install-gradient-provider.sh
# Configures DigitalOcean Gradient AI as a provider in an existing local
# OpenCode installation. Works on macOS, Linux, and Windows (WSL / Git Bash).
#
# Usage:
#   curl -fsSL <raw-github-url> | bash
#   ./install-gradient-provider.sh

NC='\033[0m'
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'

info()  { printf "${BOLD}%s${NC}\n" "$*"; }
ok()    { printf "${GREEN}%s${NC}\n" "$*"; }
warn()  { printf "${YELLOW}%s${NC}\n" "$*"; }
error() { printf "${RED}%s${NC}\n" "$*" >&2; }

# ── 1. Detect OS ─────────────────────────────────────────────────────────────

detect_platform() {
  local uname_s
  uname_s="$(uname -s)"

  case "$uname_s" in
    Darwin)
      PLATFORM="macos"
      ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        PLATFORM="wsl"
      else
        PLATFORM="linux"
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*)
      PLATFORM="gitbash"
      ;;
    *)
      error "Unsupported platform: $uname_s"
      error "This script supports macOS, Linux, WSL, and Git Bash on Windows."
      exit 1
      ;;
  esac

  info "Detected platform: $PLATFORM"
}

# ── 2. Check OpenCode is installed ───────────────────────────────────────────

check_opencode() {
  if command -v opencode >/dev/null 2>&1; then
    local version
    version="$(opencode --version 2>/dev/null || echo 'unknown')"
    ok "OpenCode found (version: $version)"
    return 0
  fi

  if [ -f "$HOME/.opencode/bin/opencode" ]; then
    ok "OpenCode found at ~/.opencode/bin/opencode"
    return 0
  fi

  error "OpenCode is not installed."
  echo ""
  echo "Install it first:"
  echo "  curl -fsSL https://opencode.ai/install | bash"
  echo ""
  echo "For more options: https://opencode.ai/docs"
  exit 1
}

# ── 3. Resolve config paths ──────────────────────────────────────────────────

resolve_paths() {
  case "$PLATFORM" in
    gitbash)
      if [ -n "${APPDATA:-}" ]; then
        CONFIG_DIR="${APPDATA}/opencode"
      else
        CONFIG_DIR="${HOME}/.config/opencode"
      fi
      if [ -n "${LOCALAPPDATA:-}" ]; then
        DATA_DIR="${LOCALAPPDATA}/opencode"
      else
        DATA_DIR="${HOME}/.local/share/opencode"
      fi
      ;;
    *)
      CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
      DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/opencode"
      ;;
  esac

  # If an existing opencode.json lives somewhere else, prefer that location
  if [ -f "$HOME/.config/opencode/opencode.json" ] && [ "$CONFIG_DIR" != "$HOME/.config/opencode" ]; then
    CONFIG_DIR="$HOME/.config/opencode"
  fi

  CONFIG_FILE="${CONFIG_DIR}/opencode.json"
  AUTH_FILE="${DATA_DIR}/auth.json"

  info "Config: $CONFIG_FILE"
  info "Auth:   $AUTH_FILE"
}

# ── 4. Check for jq ─────────────────────────────────────────────────────────

check_jq() {
  if command -v jq >/dev/null 2>&1; then
    return 0
  fi

  error "'jq' is required but not installed."
  echo ""
  echo "Install it:"
  case "$PLATFORM" in
    macos)       echo "  brew install jq" ;;
    linux|wsl)   echo "  sudo apt install jq   # Debian/Ubuntu"
                 echo "  sudo dnf install jq   # Fedora/RHEL" ;;
    gitbash)     echo "  choco install jq      # Chocolatey"
                 echo "  scoop install jq      # Scoop" ;;
  esac
  echo ""
  exit 1
}

# ── 5. Gradient provider JSON (embedded) ─────────────────────────────────────

GRADIENT_PROVIDER_JSON='{
  "digitalocean": {
    "npm": "@ai-sdk/openai-compatible",
    "name": "DigitalOcean Gradient",
    "options": {
      "baseURL": "https://inference.do-ai.run/v1"
    },
    "models": {
      "anthropic-claude-opus-4.6": { "name": "Claude Opus 4.6" },
      "anthropic-claude-opus-4.5": { "name": "Claude Opus 4.5" },
      "anthropic-claude-4.5-sonnet": { "name": "Claude Sonnet 4.5" },
      "anthropic-claude-sonnet-4": { "name": "Claude Sonnet 4" },
      "anthropic-claude-3.7-sonnet": { "name": "Claude 3.7 Sonnet" },
      "openai-gpt-5.2": { "name": "GPT-5.2" },
      "openai-gpt-5": { "name": "GPT-5" },
      "openai-gpt-5.1-codex-max": { "name": "GPT-5.1 Codex Max" },
      "openai-gpt-4.1": { "name": "GPT-4.1" },
      "openai-o3": { "name": "OpenAI o3" },
      "deepseek-r1-distill-llama-70b": { "name": "DeepSeek R1 Distill Llama 70B" },
      "alibaba-qwen3-32b": { "name": "Qwen3 32B" },
      "llama3.3-70b-instruct": { "name": "Llama 3.3 70B Instruct" }
    }
  }
}'

DEFAULT_MODEL="digitalocean/anthropic-claude-4.5-sonnet"

# ── 6. Merge provider config ────────────────────────────────────────────────

merge_provider_config() {
  mkdir -p "$CONFIG_DIR"

  if [ -f "$CONFIG_FILE" ]; then
    info "Merging DigitalOcean Gradient provider into existing config..."
    local tmp
    tmp="$(mktemp)"
    jq --argjson provider "$GRADIENT_PROVIDER_JSON" \
       '.provider = (.provider // {}) * $provider | .model = "'"$DEFAULT_MODEL"'"' \
       "$CONFIG_FILE" > "$tmp"
    mv "$tmp" "$CONFIG_FILE"
  else
    info "Creating new OpenCode config with DigitalOcean Gradient provider..."
    jq -n --argjson provider "$GRADIENT_PROVIDER_JSON" \
       '{"$schema": "https://opencode.ai/config.json", "provider": $provider, "model": "'"$DEFAULT_MODEL"'"}' \
       > "$CONFIG_FILE"
  fi

  ok "Provider config written to $CONFIG_FILE"
}

# ── 7. Prompt for API key and write auth.json ────────────────────────────────

prompt_and_save_key() {
  echo ""
  echo "========================================================================"
  echo "  DigitalOcean Gradient AI - API Key Setup"
  echo "========================================================================"
  echo ""
  echo "You need a Gradient model access key. To create one:"
  echo "  1. Go to https://cloud.digitalocean.com/gen-ai"
  echo "  2. Navigate to API Keys > Model Access Keys"
  echo "  3. Click 'Create Model Access Key'"
  echo ""

  read -rp "Enter your Gradient model access key (or press Enter to skip): " MODEL_KEY

  if [ -z "$MODEL_KEY" ]; then
    warn "Skipped API key setup."
    echo "You can re-run this script later, or manually create:"
    echo "  $AUTH_FILE"
    return 1
  fi

  mkdir -p "$DATA_DIR"

  if [ -f "$AUTH_FILE" ]; then
    info "Merging Gradient key into existing auth.json..."
    local tmp
    tmp="$(mktemp)"
    jq --arg key "$MODEL_KEY" \
       '.digitalocean = {"type": "api", "key": $key}' \
       "$AUTH_FILE" > "$tmp"
    mv "$tmp" "$AUTH_FILE"
  else
    info "Creating auth.json..."
    jq -n --arg key "$MODEL_KEY" \
       '{"digitalocean": {"type": "api", "key": $key}}' \
       > "$AUTH_FILE"
  fi

  # Set restrictive permissions (no-op on NTFS but harmless)
  chmod 600 "$AUTH_FILE" 2>/dev/null || true

  ok "API key saved to $AUTH_FILE"
  return 0
}

# ── 8. Test the connection ───────────────────────────────────────────────────

test_connection() {
  echo ""
  info "Testing connection to DigitalOcean Gradient..."

  local header_file http_status
  header_file="$(mktemp)"
  chmod 600 "$header_file" 2>/dev/null || true

  # Read the key from auth.json so it never appears on the command line
  local key
  key="$(jq -r '.digitalocean.key' "$AUTH_FILE")"
  printf "Authorization: Bearer %s" "$key" > "$header_file"

  http_status=$(curl -s -o /dev/null -w "%{http_code}" \
    -H @"$header_file" \
    -H "Content-Type: application/json" \
    https://inference.do-ai.run/v1/models 2>/dev/null) || true

  rm -f "$header_file"

  if [ "$http_status" = "200" ]; then
    ok "Connection successful! Your key is valid."
  else
    warn "Received HTTP $http_status from the Gradient API."
    warn "Your key has been saved. If it's incorrect, re-run this script."
  fi
}

# ── 9. Print success ─────────────────────────────────────────────────────────

print_success() {
  echo ""
  echo "========================================================================"
  echo "  DigitalOcean Gradient is now configured for OpenCode!"
  echo ""
  echo "  Default model: Claude Sonnet 4.5"
  echo ""
  echo "  Available models via Gradient:"
  echo "    Anthropic:    Claude Opus 4.6, Opus 4.5, Sonnet 4.5, Sonnet 4, 3.7 Sonnet"
  echo "    OpenAI:       GPT-5.2, GPT-5, GPT-5.1 Codex Max, GPT-4.1, o3"
  echo "    Open Source:  DeepSeek R1 70B, Qwen3 32B, Llama 3.3 70B"
  echo ""
  echo "  To start:         cd /path/to/your/project && opencode"
  echo "  Switch models:    use /models inside OpenCode"
  echo "  Other providers:  use /connect to add Anthropic, OpenAI, Google, etc."
  echo ""
  echo "  Config: $CONFIG_FILE"
  echo "========================================================================"
  echo ""
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
  echo ""
  info "DigitalOcean Gradient AI Provider Installer for OpenCode"
  echo ""

  detect_platform
  check_opencode
  resolve_paths
  check_jq
  merge_provider_config

  if prompt_and_save_key; then
    test_connection
  fi

  print_success
}

main "$@"
