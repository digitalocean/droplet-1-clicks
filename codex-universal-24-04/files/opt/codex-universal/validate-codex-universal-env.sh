#!/bin/bash
# Validate CODEX_ENV_* values against upstream codex-universal supported versions.
# https://github.com/openai/codex-universal#configuring-language-runtimes

set -euo pipefail

validate_codex_env_value() {
    local var="$1"
    local value="$2"

    # Reject characters that break env files or sed
    if [[ "$value" == *$'\n'* || "$value" == *$'\r'* || "$value" == *"|"* ]]; then
        echo "ERROR: ${var} contains invalid characters." >&2
        return 1
    fi

    case "$var" in
        CODEX_ENV_PYTHON_VERSION)
            case "$value" in
                3.10|3.11.12|3.12|3.13|3.14.0) return 0 ;;
            esac
            ;;
        CODEX_ENV_NODE_VERSION)
            case "$value" in
                18|20|22) return 0 ;;
            esac
            ;;
        CODEX_ENV_RUST_VERSION)
            case "$value" in
                1.83.0|1.84.1|1.85.1|1.86.0|1.87.0|1.88.0|1.89.0|1.90|1.91.1|1.92.0|1.93.0|1.94.0|1.95.0) return 0 ;;
            esac
            ;;
        CODEX_ENV_GO_VERSION)
            case "$value" in
                1.22.12|1.23.8|1.24.3|1.25.1) return 0 ;;
            esac
            ;;
        CODEX_ENV_SWIFT_VERSION)
            case "$value" in
                5.10|6.1|6.2) return 0 ;;
            esac
            ;;
        CODEX_ENV_RUBY_VERSION)
            case "$value" in
                3.2.3|3.3.8|3.4.4) return 0 ;;
            esac
            ;;
        CODEX_ENV_PHP_VERSION)
            case "$value" in
                8.4|8.3|8.2) return 0 ;;
            esac
            ;;
        CODEX_ENV_JAVA_VERSION)
            case "$value" in
                25|24|23|22|21|17|11) return 0 ;;
            esac
            ;;
        *)
            echo "ERROR: Unknown variable ${var}." >&2
            return 1
            ;;
    esac

    echo "ERROR: ${var}=${value} is not a supported version." >&2
    echo "See https://github.com/openai/codex-universal#configuring-language-runtimes" >&2
    return 1
}

update_env_file_var() {
    local file="$1"
    local var="$2"
    local value="$3"

    validate_codex_env_value "$var" "$value"

    local tmp
    tmp="$(mktemp)"
    grep -v "^${var}=" "$file" > "$tmp" || true
    printf '%s=%s\n' "$var" "$value" >> "$tmp"
    mv "$tmp" "$file"
}

apply_droplet_env_overrides() {
    local file="$1"

    for var in \
        CODEX_ENV_PYTHON_VERSION \
        CODEX_ENV_NODE_VERSION \
        CODEX_ENV_RUST_VERSION \
        CODEX_ENV_GO_VERSION \
        CODEX_ENV_SWIFT_VERSION \
        CODEX_ENV_RUBY_VERSION \
        CODEX_ENV_PHP_VERSION \
        CODEX_ENV_JAVA_VERSION
    do
        local value="${!var:-}"
        if [ -n "$value" ]; then
            update_env_file_var "$file" "$var" "$value"
            echo "Applied ${var}=${value} from droplet environment."
        fi
    done
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    if [ "$#" -ne 3 ]; then
        echo "Usage: $0 <env-file> <VAR_NAME> <value>" >&2
        echo "   or: source and call apply_droplet_env_overrides <env-file>" >&2
        exit 1
    fi
    update_env_file_var "$1" "$2" "$3"
fi
