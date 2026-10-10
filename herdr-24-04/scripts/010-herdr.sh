#!/bin/bash

set -euo pipefail

: "${application_version:?application_version must be set}"
: "${herdr_sha256:?herdr_sha256 must be set}"
: "${claude_code_version:?claude_code_version must be set}"
: "${codex_version:?codex_version must be set}"
: "${opencode_version:?opencode_version must be set}"
: "${grok_build_version:?grok_build_version must be set}"
: "${kilocode_version:?kilocode_version must be set}"
: "${cursor_version:?cursor_version must be set}"

export PATH="/usr/local/bin:/opt/grok/bin:/root/.local/bin:/root/.opencode/bin:${PATH}"

ufw limit ssh/tcp
ufw --force enable
echo "Firewall configured successfully."

install_herdr() {
    local url="https://github.com/herdrdev/herdr/releases/download/v${application_version}/herdr-linux-x86_64"
    local tmp
    tmp="$(mktemp)"
    echo "Installing Herdr ${application_version}..."
    curl -fsSL "$url" -o "$tmp"
    echo "${herdr_sha256}  ${tmp}" | sha256sum -c -
    install -m 0755 "$tmp" /usr/local/bin/herdr
    rm -f "$tmp"
    herdr --version
}

install_claude() {
    echo "Installing Claude Code ${claude_code_version}..."
    curl -fsSL https://claude.ai/install.sh | bash -s -- "${claude_code_version}"
    if [ ! -x /root/.local/bin/claude ]; then
        echo "Error: Claude Code binary not found at /root/.local/bin/claude" >&2
        exit 1
    fi
    ln -sfn /root/.local/bin/claude /usr/local/bin/claude
    claude --version
}

install_codex() {
    local release="rust-v${codex_version}"
    local tmpdir
    tmpdir="$(mktemp -d)"
    echo "Installing Codex CLI ${codex_version}..."
    # shellcheck source=/dev/null
    source /opt/codex-cli-download.sh
    install_codex_binaries "$release" "$tmpdir" \
        "${codex_tarball_sha256:-}" "${bwrap_tarball_sha256:-}"
    rm -rf "$tmpdir"
    install -m 0755 /opt/codex-bin-wrapper.sh /usr/local/bin/codex
    codex --version
}

install_opencode() {
    echo "Installing OpenCode ${opencode_version}..."
    curl -fsSL https://opencode.ai/install | bash -s -- --version "${opencode_version}" --no-modify-path
    if [ ! -x /root/.opencode/bin/opencode ]; then
        echo "Error: OpenCode binary not found at /root/.opencode/bin/opencode" >&2
        exit 1
    fi
    ln -sfn /root/.opencode/bin/opencode /usr/local/bin/opencode
    opencode --version
}

install_grok() {
    echo "Installing Grok Build ${grok_build_version}..."
    export GROK_BIN_DIR="/opt/grok/bin"
    mkdir -p "$GROK_BIN_DIR"
    curl -fsSL https://x.ai/cli/install.sh | bash -s -- "${grok_build_version}"
    if [ ! -x "${GROK_BIN_DIR}/grok" ]; then
        echo "Error: Grok Build binary not found at ${GROK_BIN_DIR}/grok" >&2
        exit 1
    fi
    ln -sfn "${GROK_BIN_DIR}/grok" /usr/local/bin/grok
    grok --version
}

install_kilo() {
    echo "Installing Kilo Code CLI ${kilocode_version}..."
    npm install --global "@kilocode/cli@${kilocode_version}"
    if ! command -v kilo >/dev/null 2>&1; then
        echo "Error: Kilo Code CLI installation failed" >&2
        exit 1
    fi
    kilo --version
}

install_cursor() {
    local dest="/root/.local/share/cursor-agent/versions/${cursor_version}"
    local tmp
    tmp="$(mktemp -d)"
    echo "Installing Cursor Agent CLI ${cursor_version}..."
    curl -fSL "https://downloads.cursor.com/lab/${cursor_version}/linux/x64/agent-cli-package.tar.gz" \
        | tar -xzf - -C "$tmp"
    if [ ! -d "${tmp}/dist-package" ]; then
        echo "Error: Cursor CLI package did not contain dist-package/" >&2
        exit 1
    fi
    rm -rf "$dest"
    mkdir -p /root/.local/share/cursor-agent/versions /root/.local/bin
    mv "${tmp}/dist-package" "$dest"
    rm -rf "$tmp"
    if [ ! -x "${dest}/cursor-agent" ]; then
        echo "Error: cursor-agent missing from ${dest}" >&2
        exit 1
    fi
    # Herdr resumes Cursor with cursor-agent. Leave the name "agent" for Grok Build.
    ln -sfn "${dest}/cursor-agent" /root/.local/bin/cursor-agent
    ln -sfn "${dest}/cursor-agent" /usr/local/bin/cursor-agent
    cursor-agent --version
}

require_version() {
    local cmd="$1" expected="$2" actual
    actual="$("$cmd" --version 2>&1 || true)"
    echo "${cmd}: ${actual}"
    case "$actual" in
        *"${expected}"*) ;;
        *)
            echo "Error: ${cmd} version does not contain ${expected}" >&2
            exit 1
            ;;
    esac
}

install_herdr
install_claude
install_codex
install_opencode
install_grok
install_kilo
install_cursor

require_version herdr "${application_version}"
require_version claude "${claude_code_version}"
require_version codex "${codex_version}"
require_version opencode "${opencode_version}"
require_version grok "${grok_build_version}"
require_version kilo "${kilocode_version}"
require_version cursor-agent "${cursor_version}"

chmod +x /opt/codex-cli-download.sh
chmod +x /opt/codex-bin-wrapper.sh
chmod +x /opt/install-herdr-integrations.sh
chmod +x /opt/start-herdr.sh
chmod +x /opt/stop-herdr.sh
chmod +x /opt/restart-herdr.sh
chmod +x /opt/status-herdr.sh
chmod +x /opt/update-herdr.sh
chmod +x /opt/update-agents.sh
chmod +x /etc/update-motd.d/99-one-click
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot

systemctl daemon-reload
systemctl enable herdr.service
if ! systemctl start herdr.service; then
    journalctl -u herdr.service --no-pager -n 80 || true
    exit 1
fi

ready=0
for _ in 1 2 3 4 5 6 7 8 9 10; do
    if systemctl is-active --quiet herdr.service; then
        ready=1
        break
    fi
    sleep 1
done
if [ "$ready" -ne 1 ]; then
    echo "Error: herdr.service did not become active" >&2
    systemctl status herdr.service --no-pager || true
    journalctl -u herdr.service --no-pager -n 80 || true
    exit 1
fi

/opt/install-herdr-integrations.sh

systemctl stop herdr.service
echo "Herdr installation complete."
