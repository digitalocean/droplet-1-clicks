#!/bin/bash
# Install T3 Code and every native provider CLI.
# template.json uses "latest". This script resolves those at build time from the
# T3 Code release: provider ranges in model-manifest.json, and Antigravity's
# checksums in antigravityRelease.ts. An explicit version still overrides.
set -euo pipefail

: "${application_version:=latest}"
: "${node_version:=latest}"
: "${claude_version:=latest}"
: "${codex_version:=latest}"
: "${cursor_version:=latest}"
: "${grok_version:=latest}"
: "${opencode_version:=latest}"
: "${pi_version:=latest}"
: "${fx_version:=latest}"
: "${antigravity_version:=latest}"
: "${antigravity_sha256_amd64:=}"
: "${antigravity_sha256_arm64:=}"

T3_USER=t3
T3_HOME=/home/t3
T3_PATH="${T3_HOME}/.local/bin:${T3_HOME}/.grok/bin:${T3_HOME}/.opencode/bin:/usr/local/bin:/usr/bin:/bin"

ufw deny 3773/tcp comment 'T3 Code: reach via Caddy on 443' || true

run_as_t3() {
  # cd into T3_HOME first: the caller's cwd is root's shell (often /root), which
  # t3 cannot enter. Some installers (e.g. Codex's) try to restore the starting
  # directory on exit and abort the whole provisioner if that chdir fails.
  runuser -u "$T3_USER" -- env HOME="$T3_HOME" USER="$T3_USER" LOGNAME="$T3_USER" \
    PATH="$T3_PATH" bash -lc "cd '$T3_HOME' && $*"
}

install_script_as_t3() {
  # Fetches a vendor install script to disk and runs it as $T3_USER, instead
  # of piping curl straight into a shell interpreter (curl | bash). This way
  # a truncated or failed download can't partially execute, and the script
  # that actually runs is sitting on disk the whole time, so it can be
  # inspected or hashed if that's ever needed.
  #
  # Usage: install_script_as_t3 <url> <interpreter> [args for the script...]
  # <interpreter> may include a leading env assignment, e.g. "FOO=bar sh".
  local url="$1" interpreter="$2"
  shift 2
  local script
  script="$(mktemp)"
  curl -fsSL "$url" -o "$script"
  chmod 644 "$script"
  run_as_t3 "$interpreter '$script' $*"
  rm -f "$script"
}

link_bin() {
  local name="$1"
  shift
  local candidate found
  for candidate in "$@"; do
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
      if [ "$candidate" = "/usr/local/bin/${name}" ]; then
        echo "Using /usr/local/bin/${name}"
        return 0
      fi
      ln -sfn "$candidate" "/usr/local/bin/${name}"
      echo "Linked ${name} -> ${candidate}"
      return 0
    fi
  done
  found="$(runuser -u "$T3_USER" -- env HOME="$T3_HOME" USER="$T3_USER" LOGNAME="$T3_USER" PATH="$T3_PATH" \
    bash -lc "command -v $(printf '%q' "$name")" 2>/dev/null || true)"
  if [ -n "$found" ] && [ -x "$found" ]; then
    ln -sfn "$found" "/usr/local/bin/${name}"
    echo "Linked ${name} -> ${found}"
    return 0
  fi
  found="$(find "$T3_HOME" /usr/local/bin /usr/bin /opt -type f -name "$name" -perm -111 2>/dev/null | head -n 1 || true)"
  if [ -n "$found" ] && [ -x "$found" ]; then
    ln -sfn "$found" "/usr/local/bin/${name}"
    echo "Linked ${name} -> ${found}"
    return 0
  fi
  echo "Build failed: ${name} binary not found." >&2
  return 1
}

require_version() {
  local bin="$1" expected="$2" got
  got=$("$bin" --version 2>&1 | head -n 1 || true)
  echo "${bin}: ${got}"
  if ! printf '%s' "$got" | grep -F -q "$expected"; then
    echo "Build failed: ${bin} does not report ${expected}" >&2
    exit 1
  fi
}

want_latest() {
  case "$(printf '%s' "${1:-latest}" | tr '[:upper:]' '[:lower:]')" in
    ""|latest) return 0 ;;
    *) return 1 ;;
  esac
}

version_in_range() {
  python3 -c '
import re, sys
raw, range_text = sys.argv[1], sys.argv[2]
if not range_text:
    raise SystemExit(0)
match = re.match(r"v?(\d+)(?:\.(\d+))?(?:\.(\d+))?", raw.strip())
if not match:
    raise SystemExit(1)
version = tuple(int(match.group(i) or 0) for i in (1, 2, 3))
def cmp(left, right):
    return (left > right) - (left < right)
for group in range_text.split("||"):
    ok = True
    for comparator in [part for part in group.split() if part]:
        parsed = re.match(r"^(\^|>=|>|<=|<|=)?\s*v?(\d+(?:\.\d+){0,2})$", comparator)
        if not parsed:
            ok = False
            break
        operator = parsed.group(1) or "="
        target = tuple(int(part) for part in (parsed.group(2).split(".") + ["0", "0"])[:3])
        compared = cmp(version, target)
        if operator == "^":
            ok = compared >= 0 and version[0] == target[0]
        elif operator == ">=":
            ok = compared >= 0
        elif operator == ">":
            ok = compared > 0
        elif operator == "<=":
            ok = compared <= 0
        elif operator == "<":
            ok = compared < 0
        else:
            ok = compared == 0
        if not ok:
            break
    if ok:
        raise SystemExit(0)
raise SystemExit(1)
' "$1" "$2"
}

read_resolved_values() {
  local resolved="$1" line key value

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    if [[ "$line" != *=* ]]; then
      echo "Invalid resolved entry" >&2
      return 1
    fi

    key="${line%%=*}"
    value="${line#*=}"

    case "$key" in
      application_version|claude_version|codex_version|cursor_version|cursor_version_range|grok_version|grok_version_range|opencode_version|pi_version|fx_version|antigravity_version|antigravity_sha256_amd64|antigravity_sha256_arm64|node_version)
        printf -v "$key" '%s' "$value"
        ;;
      *)
        echo "Unexpected resolved key: $key" >&2
        return 1
        ;;
    esac
  done <<< "$resolved"
}

echo "Resolving T3 Code and provider versions..."
if ! command -v python3 >/dev/null 2>&1; then
  DEBIAN_FRONTEND=noninteractive apt-get install -y python3
fi
resolved="$(python3 - \
  "$application_version" "$node_version" "$claude_version" "$codex_version" \
  "$cursor_version" "$grok_version" "$opencode_version" "$pi_version" \
  "$fx_version" "$antigravity_version" <<'PY'
import json, re, sys, urllib.request

pins = {
    "application_version": sys.argv[1],
    "node_version": sys.argv[2],
    "claude_version": sys.argv[3],
    "codex_version": sys.argv[4],
    "cursor_version": sys.argv[5],
    "grok_version": sys.argv[6],
    "opencode_version": sys.argv[7],
    "pi_version": sys.argv[8],
    "fx_version": sys.argv[9],
    "antigravity_version": sys.argv[10],
}

def fetch(url):
    req = urllib.request.Request(url, headers={
        "User-Agent": "droplet-1-clicks",
        "Accept": "application/vnd.github+json, application/json, text/plain, */*",
    })
    with urllib.request.urlopen(req, timeout=60) as response:
        return response.read().decode()

def latest_word(value):
    return value.strip().lower() in ("", "latest")

def parse_version(raw):
    match = re.match(r"v?(\d+)(?:\.(\d+))?(?:\.(\d+))?", str(raw).strip())
    if not match:
        return None
    return tuple(int(match.group(i) or 0) for i in (1, 2, 3))

def satisfies(raw_version, range_text):
    version = parse_version(raw_version)
    if version is None or not range_text:
        return False
    def cmp(left, right):
        return (left > right) - (left < right)
    for group in range_text.split("||"):
        ok = True
        comparators = [part for part in group.split() if part]
        if not comparators:
            continue
        for comparator in comparators:
            match = re.match(r"^(\^|>=|>|<=|<|=)?\s*v?(\d+(?:\.\d+){0,2})$", comparator)
            if not match:
                ok = False
                break
            operator = match.group(1) or "="
            target = parse_version(match.group(2))
            compared = cmp(version, target)
            if operator == "^":
                if compared < 0 or version[0] != target[0]:
                    ok = False
            elif operator == ">=":
                ok = compared >= 0
            elif operator == ">":
                ok = compared > 0
            elif operator == "<=":
                ok = compared <= 0
            elif operator == "<":
                ok = compared < 0
            elif operator == "=":
                ok = compared == 0
            else:
                ok = False
            if not ok:
                break
        if ok:
            return True
    return False

def exact_version(range_text):
    match = re.fullmatch(r"=\s*v?(\d+(?:\.\d+){0,2})", range_text.strip())
    return match.group(1) if match else None

def gh_tag(repo):
    tag = json.loads(fetch(f"https://api.github.com/repos/{repo}/releases/latest"))["tag_name"]
    return re.sub(r"^(?:rust-)?v", "", tag)

def gh_newest_in_range(repo, range_text):
    releases = json.loads(fetch(f"https://api.github.com/repos/{repo}/releases?per_page=40"))
    versions = []
    for release in releases:
        if release.get("prerelease"):
            continue
        tag = re.sub(r"^(?:rust-)?v", "", release.get("tag_name", ""))
        if parse_version(tag) and satisfies(tag, range_text):
            versions.append(tag)
    if not versions:
        raise SystemExit(f"no {repo} release satisfies {range_text}")
    return max(versions, key=parse_version)

def npm_version(package):
    return json.loads(fetch(f"https://registry.npmjs.org/{package}/latest"))["version"]

t3 = pins["application_version"]
if latest_word(t3):
    t3 = gh_tag("pingdotgg/t3code")
t3 = re.sub(r"^v", "", t3)
manifest = json.loads(fetch(
    f"https://raw.githubusercontent.com/pingdotgg/t3code/v{t3}/apps/server/src/provider/model-manifest.json"
))
release_ts = fetch(
    f"https://raw.githubusercontent.com/pingdotgg/t3code/v{t3}/apps/server/src/provider/antigravityRelease.ts"
)

def policy_for(driver):
    for policy in manifest.get("compatibility", []):
        if policy.get("driver") == driver and satisfies(t3, policy.get("t3CodeRange", "")):
            return policy
    raise SystemExit(f"T3 Code {t3} has no compatibility policy for {driver}")

def resolve(driver, pin, latest_fn):
    policy = policy_for(driver)
    recommended = policy.get("recommendedVersion") or exact_version(policy.get("recommendedRange") or "")
    if not latest_word(pin):
        chosen = re.sub(r"^v", "", pin)
    elif recommended:
        chosen = recommended
    else:
        chosen = latest_fn()
    range_text = policy.get("recommendedRange") or ""
    if range_text and not satisfies(chosen, range_text):
        raise SystemExit(
            f"{driver} {chosen} is outside the range T3 Code {t3} supports ({range_text})"
        )
    return chosen

def node_latest():
    page = fetch("https://nodejs.org/dist/latest-v22.x/")
    match = re.search(r"node-v(22\.\d+\.\d+)", page)
    if not match:
        raise SystemExit("could not find the latest Node.js 22 release")
    return match.group(1)

out = {
    "application_version": t3,
    "node_version": node_latest() if latest_word(pins["node_version"]) else re.sub(r"^v", "", pins["node_version"]),
    "claude_version": resolve("claudeAgent", pins["claude_version"], lambda: npm_version("@anthropic-ai/claude-code")),
    "codex_version": resolve(
        "codex",
        pins["codex_version"],
        lambda: gh_newest_in_range("openai/codex", policy_for("codex").get("recommendedRange") or ">=0.0.0"),
    ),
    "opencode_version": resolve(
        "opencode",
        pins["opencode_version"],
        lambda: gh_newest_in_range("anomalyco/opencode", policy_for("opencode").get("recommendedRange") or ">=0.0.0"),
    ),
    "pi_version": resolve("pi", pins["pi_version"], lambda: npm_version("@earendil-works/pi-coding-agent")),
    "fx_version": resolve("fx", pins["fx_version"], lambda: fetch("https://releases.fx.sh/latest.txt").strip()),
}
# CVE-2026-111497 (Brotli RCE) is fixed in Node 22.23.4. That floor also
# covers Pi, which needs >=22.19.0.
if not satisfies(out["node_version"], ">=22.23.4"):
    raise SystemExit(
        f"Node.js {out['node_version']} is below the CVE-2026-111497 minimum 22.23.4"
    )

# Cursor and Grok publish latest through their own installers. Keep an explicit
# pin, otherwise install latest and check the range after the binary is on disk.
for driver, key in (("cursor", "cursor_version"), ("grok", "grok_version")):
    policy = policy_for(driver)
    out[key] = pins[key] if not latest_word(pins[key]) else "latest"
    out[key + "_range"] = policy.get("recommendedRange") or ""

pinned = re.search(r'ANTIGRAVITY_RELEASE_VERSION = "([^"]+)"', release_ts)
if not pinned:
    raise SystemExit("T3 Code did not publish an Antigravity release version")
bundled = pinned.group(1)
chosen_agy = bundled if latest_word(pins["antigravity_version"]) else pins["antigravity_version"]
if chosen_agy != bundled:
    raise SystemExit(
        f"Antigravity {chosen_agy} does not match {bundled}, the build shipped with T3 Code {t3}"
    )
# model-manifest.json can pin an older recommendedRange than the binary T3 Code
# actually downloads. antigravityRelease.ts is the checksummed build, so that
# version is the one this image installs.
out["antigravity_version"] = chosen_agy

def agy_sha(platform):
    match = re.search(
        rf'"{platform}".*?sha256: "([a-f0-9]{{64}})"',
        release_ts,
        re.S,
    )
    if not match:
        raise SystemExit(f"no Antigravity checksum for {platform} in T3 Code {t3}")
    return match.group(1)

out["antigravity_sha256_amd64"] = agy_sha("linux-x64")
out["antigravity_sha256_arm64"] = agy_sha("linux-arm64")

for key, value in out.items():
    if not re.fullmatch(r"[A-Za-z0-9._:>=<^| -]*", value):
        raise SystemExit(f"refusing unusual version value for {key}")
    print(f"{key}={value}")
PY
)"
read_resolved_values "$resolved" || exit 1
install -d /var/lib/digitalocean
printf '%s\n' "$resolved" > /var/lib/digitalocean/t3code-resolved.env
chmod 644 /var/lib/digitalocean/t3code-resolved.env
echo "T3 Code ${application_version}"
echo "Providers: claude ${claude_version}, codex ${codex_version}, cursor ${cursor_version}, grok ${grok_version}, opencode ${opencode_version}, pi ${pi_version}, fx ${fx_version}, antigravity ${antigravity_version}"

echo "Installing Node.js ${node_version}..."
NODE_VERSION="$(printf '%s' "$node_version" | sed -E -n 's/^v?([0-9]+\.[0-9]+\.[0-9]+).*/\1/p')"
NODE_DEB_VERSION="${NODE_VERSION}-1nodesource1"
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
  | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
chmod a+r /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
  > /etc/apt/sources.list.d/nodesource.list
cat > /etc/apt/preferences.d/nodesource-nodejs <<'EOF'
Package: nodejs
Pin: origin deb.nodesource.com
Pin-Priority: 1001
EOF
apt-get update -y
if ! DEBIAN_FRONTEND=noninteractive apt-get install -y "nodejs=${NODE_DEB_VERSION}"; then
  echo "Pinned nodejs=${NODE_DEB_VERSION} unavailable; installing newest NodeSource 22.x..."
  DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
fi
installed_node="$(node -v 2>/dev/null | sed 's/^v//')"
if ! node -e '
  const parse = (s) => {
    const m = String(s).trim().match(/^v?(\d+)\.(\d+)\.(\d+)/);
    if (!m) process.exit(1);
    return [Number(m[1]), Number(m[2]), Number(m[3])];
  };
  const need = parse(process.argv[1]);
  const have = parse(process.argv[2]);
  for (let i = 0; i < 3; i++) {
    if (have[i] > need[i]) process.exit(0);
    if (have[i] < need[i]) process.exit(1);
  }
' "22.23.4" "${installed_node:-0}"; then
  echo "Build failed: Node.js ${installed_node:-missing} is below the CVE-2026-111497 minimum 22.23.4" >&2
  exit 1
fi
echo "Node.js ${installed_node} installed."

echo "Installing Caddy..."
curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/gpg.key" \
  | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" \
  > /etc/apt/sources.list.d/caddy-stable.list
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y caddy
mkdir -p /var/log/caddy
chown -R caddy:caddy /var/log/caddy

if ! id "$T3_USER" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "$T3_USER"
fi
mkdir -p \
  "${T3_HOME}/workspace" \
  "${T3_HOME}/.t3/userdata" \
  "${T3_HOME}/.local/bin" \
  "${T3_HOME}/.claude" \
  "${T3_HOME}/.claude-digitalocean"
chown -R "${T3_USER}:${T3_USER}" "$T3_HOME"

echo "Installing T3 Code v${application_version}..."
# install.sh prepends "v" itself. T3CODE_VERSION=v0.1.3 requests vv0.1.3 and 404s.
t3_version="${application_version#v}"
install_script_as_t3 "https://t3.codes/install.sh" "T3CODE_VERSION=${t3_version} sh"
link_bin t3 "${T3_HOME}/.local/bin/t3"
require_version /usr/local/bin/t3 "$application_version"

echo "Installing Claude Code ${claude_version}..."
install_script_as_t3 "https://claude.ai/install.sh" bash "${claude_version}"
link_bin claude "${T3_HOME}/.local/bin/claude"
require_version /usr/local/bin/claude "$claude_version"

echo "Installing Codex ${codex_version}..."
install_script_as_t3 "https://github.com/openai/codex/raw/main/scripts/install/install.sh" bash --release "${codex_version}"
link_bin codex \
  "${T3_HOME}/.local/bin/codex" \
  "${T3_HOME}/.codex/bin/codex"
require_version /usr/local/bin/codex "$codex_version"

echo "Installing Grok Build ${grok_version}..."
if want_latest "$grok_version"; then
  install_script_as_t3 "https://x.ai/cli/install.sh" bash
else
  install_script_as_t3 "https://x.ai/cli/install.sh" bash "${grok_version}"
fi
link_bin grok "${T3_HOME}/.grok/bin/grok"
if want_latest "$grok_version"; then
  grok_version="$(/usr/local/bin/grok --version 2>&1 | head -n 1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)"
  [ -n "$grok_version" ] || { echo "Build failed: grok did not report a version" >&2; exit 1; }
  if ! version_in_range "$grok_version" "${grok_version_range:-}"; then
    echo "Build failed: grok ${grok_version} is outside the T3 Code range ${grok_version_range}" >&2
    exit 1
  fi
fi
require_version /usr/local/bin/grok "$grok_version"

echo "Installing Cursor Agent ${cursor_version}..."
cursor_arch="$(uname -m)"
case "$cursor_arch" in
  x86_64|amd64) cursor_arch=x64 ;;
  aarch64|arm64) cursor_arch=arm64 ;;
  *) echo "Unsupported architecture for Cursor Agent: $(uname -m)" >&2; exit 1 ;;
esac
if want_latest "$cursor_version"; then
  install_script_as_t3 "https://cursor.com/install" bash
  link_bin cursor-agent \
    "${T3_HOME}/.local/bin/cursor-agent" \
    "${T3_HOME}/.local/bin/agent"
  ln -sfn "$(readlink -f /usr/local/bin/cursor-agent)" /usr/local/bin/agent
  cursor_version="$(/usr/local/bin/cursor-agent --version 2>&1 | head -n 1 | grep -oE '[0-9]{4}\.[0-9]{2}\.[0-9]{2}(-[A-Za-z0-9]+)?' | head -n 1)"
  [ -n "$cursor_version" ] || { echo "Build failed: cursor-agent did not report a version" >&2; exit 1; }
  if ! version_in_range "$cursor_version" "${cursor_version_range:-}"; then
    echo "Build failed: cursor-agent ${cursor_version} is outside the T3 Code range ${cursor_version_range}" >&2
    exit 1
  fi
else
  cursor_dir="/opt/cursor-agent/${cursor_version}"
  mkdir -p "$cursor_dir"
  curl -fL "https://downloads.cursor.com/lab/${cursor_version}/linux/${cursor_arch}/agent-cli-package.tar.gz" \
    | tar -xz -C "$cursor_dir" --strip-components=1
  if [ ! -x "${cursor_dir}/cursor-agent" ]; then
    found="$(find "$cursor_dir" -type f -name cursor-agent | head -n 1)"
    if [ -z "$found" ]; then
      echo "Build failed: cursor-agent not in the archive." >&2
      exit 1
    fi
    ln -sfn "$found" /usr/local/bin/cursor-agent
    ln -sfn "$found" /usr/local/bin/agent
  else
    ln -sfn "${cursor_dir}/cursor-agent" /usr/local/bin/cursor-agent
    ln -sfn "${cursor_dir}/cursor-agent" /usr/local/bin/agent
  fi
fi
require_version /usr/local/bin/cursor-agent "${cursor_version%%-*}"

echo "Installing OpenCode ${opencode_version}..."
# opencode.ai/install only accepts OpenCode 1. OpenCode 2+ uses the v2 installer.
opencode_install_url="https://opencode.ai/install"
opencode_major="${opencode_version#v}"
opencode_major="${opencode_major%%.*}"
if [ "${opencode_major:-0}" -ge 2 ] 2>/dev/null; then
  opencode_install_url="https://opencode.ai/v2/install"
fi
install_script_as_t3 "$opencode_install_url" bash --version "${opencode_version}" --no-modify-path
link_bin opencode \
  "${T3_HOME}/.opencode/bin/opencode" \
  "${T3_HOME}/.local/bin/opencode"
require_version /usr/local/bin/opencode "$opencode_version"

echo "Installing Pi ${pi_version}..."
npm install -g --ignore-scripts "@earendil-works/pi-coding-agent@${pi_version}"
link_bin pi /usr/local/bin/pi /usr/bin/pi "$(npm prefix -g)/bin/pi"
require_version /usr/local/bin/pi "$pi_version"

echo "Installing Muse Code (stable channel; the installer has no version pin)..."
install_script_as_t3 "https://dev.meta.ai/install.sh" bash
link_bin muse \
  "${T3_HOME}/.local/bin/muse" \
  "${T3_HOME}/.muse/bin/muse"
/usr/local/bin/muse --version || true

echo "Installing fx ${fx_version}..."
# releases.fx.sh paths keep the v prefix (v0.0.15). A bare 0.0.15 is a 404.
fx_release="${fx_version}"
case "$fx_release" in
  v*) ;;
  *) fx_release="v${fx_release}" ;;
esac
install_script_as_t3 "https://fx.sh/setup.sh" "FX_INSTALL_DIR=${T3_HOME}/.local/bin bash" "${fx_release}"
link_bin fx "${T3_HOME}/.local/bin/fx"
require_version /usr/local/bin/fx "${fx_version#v}"

echo "Installing Antigravity ACP ${antigravity_version}..."
case "$(uname -m)" in
  x86_64|amd64)
    agy_zip="agy-acp-server-${antigravity_version}-linux-x86_64.zip"
    agy_sha="$antigravity_sha256_amd64"
    ;;
  aarch64|arm64)
    agy_zip="agy-acp-server-${antigravity_version}-linux-arm64.zip"
    agy_sha="$antigravity_sha256_arm64"
    ;;
  *)
    echo "Unsupported architecture for Antigravity: $(uname -m)" >&2
    exit 1
    ;;
esac
agy_tmp="$(mktemp -d)"
curl -fL "https://dl.google.com/agy-extensions/releases/linux/${agy_zip}" -o "${agy_tmp}/agy.zip"
echo "${agy_sha}  ${agy_tmp}/agy.zip" | sha256sum -c -
unzip -q "${agy_tmp}/agy.zip" -d "${agy_tmp}/extract"
agy_bin="$(find "${agy_tmp}/extract" -type f -name agy_acp_server.par | head -n 1)"
if [ -z "$agy_bin" ]; then
  echo "Build failed: agy_acp_server.par not in the Antigravity archive." >&2
  exit 1
fi
agy_src="$(dirname "$agy_bin")"
rm -rf "/opt/antigravity-acp/${antigravity_version}"
mkdir -p /opt/antigravity-acp
mv "$agy_src" "/opt/antigravity-acp/${antigravity_version}"
chmod -R a+rX "/opt/antigravity-acp/${antigravity_version}"
find "/opt/antigravity-acp/${antigravity_version}" -type f \( -name 'agy_acp_server.par' -o -name 'localharness_external' -o -name 'localharness_external.par' \) -exec chmod a+x {} +
chmod a+x "/opt/antigravity-acp/${antigravity_version}/agy_acp_server.par"
ln -sfn "/opt/antigravity-acp/${antigravity_version}" /opt/antigravity-acp/current
rm -rf "$agy_tmp"

echo "Preparing the T3 browser sandbox..."
# stdin is closed and the command is bounded so a prompt cannot hang Packer.
# The server runs as t3, so the browser install has to land in that user's home.
if ! DEBIAN_FRONTEND=noninteractive timeout 600 runuser -u "$T3_USER" -- env \
  HOME="$T3_HOME" USER="$T3_USER" LOGNAME="$T3_USER" T3CODE_HOME="${T3_HOME}/.t3" \
  PATH="$T3_PATH" /usr/local/bin/t3 browser setup </dev/null; then
  echo "Build failed: t3 browser setup did not finish." >&2
  exit 1
fi

if [ -f /opt/t3code-settings.json ]; then
  cp /opt/t3code-settings.json "${T3_HOME}/.t3/userdata/settings.json"
fi
chown -R "${T3_USER}:${T3_USER}" "$T3_HOME"
chmod 700 "${T3_HOME}/.t3" "${T3_HOME}/.claude" "${T3_HOME}/.claude-digitalocean"
chmod 600 "${T3_HOME}/.t3/userdata/settings.json" /opt/t3code.env /opt/t3code-inference.env

chmod +x /opt/start-t3code.sh
chmod +x /opt/stop-t3code.sh
chmod +x /opt/restart-t3code.sh
chmod +x /opt/status-t3code.sh
chmod +x /opt/update-t3code.sh
chmod +x /opt/setup-t3code-domain.sh
chmod +x /opt/ensure-t3code-swap.sh
chmod +x /opt/apply-inference-from-env.sh
chmod +x /opt/retry-apply-inference-after-cloud-init.sh
chmod +x /opt/create-t3code-pairing.sh
chmod +x /etc/setup_wizard.sh
chmod +x /etc/update-motd.d/99-one-click
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot
chmod +x /var/lib/digitalocean/inference-models.sh

systemctl enable fail2ban
systemctl daemon-reload
systemctl enable t3code
systemctl enable caddy
systemctl enable t3code-apply-inference.service

if [ -f /var/lib/digitalocean/t3code-resolved.env ]; then
  sed -i \
    -e "s|^grok_version=.*|grok_version=${grok_version}|" \
    -e "s|^cursor_version=.*|cursor_version=${cursor_version}|" \
    /var/lib/digitalocean/t3code-resolved.env
fi

echo "T3 Code ${application_version} and native providers installed."
echo "Services start on first boot."
