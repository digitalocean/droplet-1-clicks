#!/bin/bash
# Reinstall Java runtimes with CVE-2026-114938 (Java4Shell) fixes via Eclipse Temurin.
# Upstream codex-universal still ships vulnerable OpenJDK builds installed with mise;
# Java 22, 23, and 24 are EOL with no vendor fix.

set -euo pipefail

JAVA_PATCH_VERSIONS=(
    25.0.5.1+2
    21.0.13.1+2
    17.0.21.1+2
    11.0.33.1+1
)
JAVA_PATCH_MAJORS=(25 21 17 11)
JAVA_EOL_MAJORS=(24 23 22)
JAVA_DEFAULT_VERSION="temurin-21.0.13.1+2"
IMAGE_MISE_CONFIG="/mise.toml"
GLOBAL_MISE_CONFIG="${HOME}/.config/mise/config.toml"

is_patched_temurin() {
    local ver="$1"
    case "$ver" in
        temurin-25.0.5.1+2* | temurin-21.0.13.1+2* | temurin-17.0.21.1+2* | temurin-11.0.33.1+1*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

is_patched_java_request() {
    local req="$1"
    case "$req" in
        temurin-25.0.5.1+2* | temurin-21.0.13.1+2* | temurin-17.0.21.1+2* | temurin-11.0.33.1+1*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

java_pin_in_config() {
    local cfg="$1"
    [ -f "${cfg}" ] || return 1
    grep -qE '^[[:space:]]*java[[:space:]]*=' "${cfg}"
}

read_java_pin() {
    local cfg="$1"
    grep -E '^[[:space:]]*java[[:space:]]*=' "${cfg}" | head -1 \
        | sed -E 's/^[[:space:]]*java[[:space:]]*=[[:space:]]*//' \
        | tr -d "\"'"
}

set_image_default_java() {
    echo "Setting image default Java to ${JAVA_DEFAULT_VERSION} in ${IMAGE_MISE_CONFIG}..."
    mise use --path "${IMAGE_MISE_CONFIG}" "java@${JAVA_DEFAULT_VERSION}"
    mise use --global "java@${JAVA_DEFAULT_VERSION}"
}

scrub_java_config_pins() {
    local cfg pinned

    for cfg in "${IMAGE_MISE_CONFIG}" "${GLOBAL_MISE_CONFIG}"; do
        java_pin_in_config "${cfg}" || continue
        pinned="$(read_java_pin "${cfg}")"
        if is_patched_java_request "${pinned}"; then
            continue
        fi
        echo "Replacing pinned OpenJDK Java ${pinned} in ${cfg}..."
        mise use --path "${cfg}" "java@${JAVA_DEFAULT_VERSION}"
    done

    set_image_default_java
}

install_patched_java() {
    local patch_ver="$1"
    local major="${patch_ver%%.*}"

    echo "Installing patched Temurin Java ${patch_ver}..."
    mise install "java@temurin-${patch_ver}"
    mise alias set java "${major}" "temurin-${patch_ver}"
}

for patch_ver in "${JAVA_PATCH_VERSIONS[@]}"; do
    install_patched_java "${patch_ver}"
done

mapfile -t installed_versions < <(mise ls --installed --json java | jq -r '.[].version')
for ver in "${installed_versions[@]}"; do
  if is_patched_temurin "${ver}"; then
    continue
  fi
  echo "Removing vulnerable/non-Temurin Java ${ver}..."
  mise uninstall "java@${ver}"
done

for major in "${JAVA_EOL_MAJORS[@]}"; do
  mise alias unset java "${major}" 2>/dev/null || true
  mise uninstall "java@${major}" 2>/dev/null || true
done

# Drop major-version install shortcuts that still point at non-Temurin builds.
java_install_root="${HOME}/.local/share/mise/installs/java"
if [ -d "${java_install_root}" ]; then
  for entry in "${java_install_root}"/*; do
    [ -e "${entry}" ] || continue
    name="$(basename "${entry}")"
    case "${name}" in
      temurin-*)
        is_patched_temurin "${name}" || rm -rf "${entry}"
        ;;
      [0-9]*)
        echo "Removing Java major shortcut ${name}..."
        rm -rf "${entry}"
        ;;
      *)
        if ! is_patched_temurin "${name}"; then
          echo "Removing non-Temurin Java install ${name}..."
          mise uninstall "java@${name}" 2>/dev/null || rm -rf "${entry}"
        fi
        ;;
    esac
  done
fi

leftovers=()
mapfile -t remaining < <(mise ls --installed --json java | jq -r '.[].version')
for ver in "${remaining[@]}"; do
  if ! is_patched_temurin "${ver}"; then
    leftovers+=("${ver}")
  fi
done

if [ "${#leftovers[@]}" -gt 0 ]; then
  echo "ERROR: vulnerable/non-Temurin Java versions still present after patch: ${leftovers[*]}" >&2
  exit 1
fi

for major in "${JAVA_PATCH_MAJORS[@]}"; do
  actual="$(mise exec "java@${major}" -- java -version 2>&1 | head -1)"
  if ! echo "${actual}" | grep -qE "openjdk version \"${major}\."; then
    echo "ERROR: java@${major} did not select expected major (${actual})" >&2
    exit 1
  fi
  echo "  OK: Java ${major} → ${actual}"
done

scrub_java_config_pins
mise cache clear || true

default_line="$(java -version 2>&1 | head -1)"
if ! echo "${default_line}" | grep -q '21.0.13.1'; then
  echo "ERROR: default Java is not 21.0.13.1: ${default_line}" >&2
  exit 1
fi
echo "  OK: default Java ${default_line}"