#!/bin/bash
set -euo pipefail

CONTAINER="codex-universal"
ENV_FILE="/opt/codex-universal/.env"
FAILURES=0

pass() { echo "  OK: $*"; }
fail() { echo "  FAIL: $*"; FAILURES=$((FAILURES + 1)); }

echo "=== Codex Universal runtime test ==="
echo ""

echo "[1/5] Host service and container"
if systemctl is-enabled codex-universal >/dev/null 2>&1; then
    pass "codex-universal.service is enabled"
else
    fail "codex-universal.service is not enabled"
fi

if docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
    pass "container $CONTAINER is running"
else
    fail "container $CONTAINER is not running (try: /opt/codex-universal/start-codex-universal.sh)"
fi

if [ -f "$ENV_FILE" ]; then
    pass "env file exists at $ENV_FILE"
else
    fail "missing $ENV_FILE"
fi

if [ -d /root/workspace ]; then
    pass "workspace directory /root/workspace exists"
else
    fail "missing /root/workspace"
fi

echo ""
echo "[2/5] Security checks"
if ufw status 2>/dev/null | grep -q "Status: active"; then
    pass "UFW firewall is active"
else
    fail "UFW firewall is not active"
fi

if ufw status 2>/dev/null | grep -qE '22/tcp.*ALLOW'; then
    pass "SSH is allowed via UFW"
else
    fail "SSH allow rule not found in UFW"
fi

if command -v codex >/dev/null 2>&1; then
    pass "Codex CLI is installed on the host"
else
    fail "Codex CLI is not installed on the host"
fi

if [ -f "$ENV_FILE" ]; then
    ENV_PERMS="$(stat -c '%a' "$ENV_FILE")"
    if [ "$ENV_PERMS" = "600" ]; then
        pass ".env permissions are 600"
    else
        fail ".env permissions are ${ENV_PERMS} (expected 600)"
    fi
fi

if docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
    PRIV="$(docker inspect "$CONTAINER" --format '{{.HostConfig.Privileged}}' 2>/dev/null || echo true)"
    PORTS="$(docker inspect "$CONTAINER" --format '{{json .HostConfig.PortBindings}}' 2>/dev/null || echo null)"
    SECOPT="$(docker inspect "$CONTAINER" --format '{{json .HostConfig.SecurityOpt}}' 2>/dev/null || echo null)"

    if [ "$PRIV" = "false" ]; then
        pass "container is not privileged"
    else
        fail "container is privileged"
    fi

    if [ "$PORTS" = "{}" ] || [ "$PORTS" = "null" ] || [ -z "$PORTS" ]; then
        pass "no host ports published from container"
    else
        fail "container publishes ports: ${PORTS}"
    fi

    if echo "$SECOPT" | grep -q "no-new-privileges"; then
        pass "no-new-privileges security option is set"
    else
        fail "no-new-privileges security option is missing"
    fi

    if docker inspect "$CONTAINER" --format '{{json .HostConfig.Binds}}' 2>/dev/null | grep -q 'docker.sock'; then
        fail "docker socket is mounted into container"
    else
        pass "docker socket is not mounted into container"
    fi
else
    echo "  Skipped container inspect — container is not running."
fi

echo ""
echo "[3/5] Workspace mount"
MARKER="codex-universal-test-$(date +%s)"
echo "$MARKER" > "/root/workspace/${MARKER}.txt"
if docker exec "$CONTAINER" test -f "/workspace/${MARKER}.txt" 2>/dev/null; then
    pass "host /root/workspace is mounted at /workspace in the container"
    rm -f "/root/workspace/${MARKER}.txt"
else
    fail "workspace mount is not visible inside the container"
fi

echo ""
echo "[4/5] Configured language runtimes"
if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
    echo "  Skipped — container is not running."
else
    docker exec "$CONTAINER" bash -lc '
set -euo pipefail

check_version() {
    local label="$1"
    local cmd="$2"
    if eval "$cmd" >/dev/null 2>&1; then
        echo "  OK: ${label} — $(eval "$cmd" 2>&1 | head -1)"
    else
        echo "  FAIL: ${label} — command failed: ${cmd}"
        exit 1
    fi
}

/opt/codex/setup_universal.sh >/dev/null

check_version "Python (${CODEX_ENV_PYTHON_VERSION:-default})" "python3 --version"
check_version "Node.js (${CODEX_ENV_NODE_VERSION:-default})" "node --version"
check_version "Rust (${CODEX_ENV_RUST_VERSION:-default})" "rustc --version"
check_version "Go (${CODEX_ENV_GO_VERSION:-default})" "go version"
check_version "Ruby (${CODEX_ENV_RUBY_VERSION:-default})" "ruby --version"
check_version "PHP (${CODEX_ENV_PHP_VERSION:-default})" "php --version | head -1"
check_version "Java (${CODEX_ENV_JAVA_VERSION:-default})" "java -version 2>&1 | head -1"
check_version "Swift (${CODEX_ENV_SWIFT_VERSION:-default})" "swift --version | head -1"
check_version "Bun (bundled)" "bun --version"
' || FAILURES=$((FAILURES + 1))
fi

echo ""
echo "[5/5] Quick compile/run smoke test"
if docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
    docker exec "$CONTAINER" bash -lc '
set -euo pipefail
cd /workspace
python3 -c "print(\"python smoke ok\")"
node -e "console.log(\"node smoke ok\")"
' && pass "Python and Node smoke tests passed" || fail "Python or Node smoke test failed"
else
    echo "  Skipped — container is not running."
fi

echo ""
if [ "$FAILURES" -eq 0 ]; then
    echo "All runtime and security tests passed."
    exit 0
fi

echo "$FAILURES test group(s) failed. Check:"
echo "  systemctl status codex-universal"
echo "  docker logs codex-universal"
echo "  /opt/codex-universal/status-codex-universal.sh"
exit 1
