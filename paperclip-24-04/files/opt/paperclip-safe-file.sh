#!/bin/bash
# Shared helpers for root-run Paperclip maintenance scripts.
#
# Paths under /home/paperclip are written *as* the paperclip user (runuser), never
# with root path-based chown/chmod/install -d -o inside that tree. That closes
# symlink races where paperclip replaces a root temp with a link to a system file
# (or plants a dir symlink so install -d -o chowns a PATH directory).
#
# Non-user paths (e.g. /opt/paperclip.env) still use a same-dir temp finalized
# before mv; those dirs are not paperclip-writable.
#
# shellcheck shell=bash

paperclip_is_user_path() {
  case "$1" in
    /home/paperclip|/home/paperclip/*) return 0 ;;
    *) return 1 ;;
  esac
}

# Refuse if any path component is a symlink (walk from leaf toward /).
paperclip_assert_no_symlink_components() {
  local path="$1" cur
  cur="$path"
  while [ -n "$cur" ] && [ "$cur" != "/" ]; do
    if [ -L "$cur" ]; then
      echo "ERROR: refusing symlink in path: $cur (from $path)" >&2
      return 1
    fi
    cur="$(dirname "$cur")"
  done
  return 0
}

# Fail if path exists as a symlink, non-regular file, or hardlink (nlink != 1).
# Also refuse symlink parents under the paperclip home.
paperclip_assert_safe_target() {
  local path="$1"
  if paperclip_is_user_path "$path"; then
    paperclip_assert_no_symlink_components "$(dirname "$path")" || return 1
  fi
  if [ -L "$path" ]; then
    echo "ERROR: refusing symlink path: $path" >&2
    return 1
  fi
  if [ -e "$path" ]; then
    if [ ! -f "$path" ]; then
      echo "ERROR: refusing non-regular file: $path" >&2
      return 1
    fi
    local nlink
    nlink="$(stat -c '%h' "$path" 2>/dev/null || stat -f '%l' "$path")"
    if [ "$nlink" != "1" ]; then
      echo "ERROR: refusing hardlinked file (nlink=${nlink}): $path" >&2
      return 1
    fi
  fi
  return 0
}

# Create a directory under the paperclip home as paperclip (never install -d -o).
# mode is octal like 700 or 755.
paperclip_ensure_user_dir() {
  local dir="$1" mode="${2:-700}"
  if ! paperclip_is_user_path "$dir"; then
    echo "ERROR: paperclip_ensure_user_dir only for /home/paperclip paths: $dir" >&2
    return 1
  fi
  if [ -L "$dir" ]; then
    echo "ERROR: refusing symlink directory: $dir" >&2
    return 1
  fi
  if [ -e "$dir" ]; then
    paperclip_assert_no_symlink_components "$dir" || return 1
    if [ ! -d "$dir" ]; then
      echo "ERROR: not a directory: $dir" >&2
      return 1
    fi
    # Already exists as a real dir — do not chown/chmod as root.
    return 0
  fi
  paperclip_assert_no_symlink_components "$(dirname "$dir")" || return 1
  # mkdir -p as paperclip: no root ownership change on a planted symlink target.
  runuser -u paperclip -- mkdir -p -m "$mode" "$dir" || return 1
  if [ -L "$dir" ] || [ ! -d "$dir" ]; then
    echo "ERROR: directory missing or became a symlink after mkdir: $dir" >&2
    return 1
  fi
  paperclip_assert_no_symlink_components "$dir" || return 1
  return 0
}

# Finalize a same-dir temp into $path for non-user (root-owned) paths only.
# Never chown/chmod the final path after replace.
paperclip_finalize_temp() {
  local path="$1" tmp="$2" mode="${3:-600}"
  if paperclip_is_user_path "$path"; then
    echo "ERROR: paperclip_finalize_temp must not run as root on user paths: $path" >&2
    rm -f "$tmp" 2>/dev/null || true
    return 1
  fi
  if [ -L "$tmp" ]; then
    echo "ERROR: refusing symlinked temp: $tmp" >&2
    rm -f "$tmp" 2>/dev/null || true
    return 1
  fi
  chmod "$mode" "$tmp" || { rm -f "$tmp"; return 1; }
  mv -f "$tmp" "$path"
}

# Replace $path with stdin contents.
paperclip_atomic_write() {
  local path="$1" mode="${2:-600}"
  local dir tmp
  paperclip_assert_safe_target "$path" || return 1
  dir="$(dirname "$path")"
  if paperclip_is_user_path "$path"; then
    paperclip_ensure_user_dir "$dir" 700 || return 1
    # stdin is the payload; keep the script single-quoted so the parent does not expand it.
    runuser -u paperclip -- bash -c '
      set -euo pipefail
      path="$1"
      mode="$2"
      dir="$(dirname "$path")"
      if [ -L "$path" ]; then
        echo "ERROR: refusing symlink path: $path" >&2
        exit 1
      fi
      if [ -e "$path" ] && [ ! -f "$path" ]; then
        echo "ERROR: refusing non-regular file: $path" >&2
        exit 1
      fi
      tmp="$(mktemp "${dir}/.paperclip-write.XXXXXX")"
      trap "rm -f \"$tmp\"" EXIT
      cat >"$tmp"
      if [ -L "$tmp" ]; then
        echo "ERROR: temp became a symlink: $tmp" >&2
        exit 1
      fi
      chmod "$mode" "$tmp"
      mv -f "$tmp" "$path"
      trap - EXIT
    ' bash "$path" "$mode"
    return
  fi
  mkdir -p "$dir"
  tmp="$(mktemp "${dir}/.paperclip-write.XXXXXX")"
  cat >"$tmp" || { rm -f "$tmp"; return 1; }
  paperclip_finalize_temp "$path" "$tmp" "$mode"
}

# Set KEY=VAL in an env file without sed (values may contain & \ |).
paperclip_write_env_kv() {
  local file="$1" key="$2" val="$3"
  local dir tmp
  paperclip_assert_safe_target "$file" || return 1
  dir="$(dirname "$file")"
  if paperclip_is_user_path "$file"; then
    paperclip_ensure_user_dir "$dir" 700 || return 1
    # Quote into the child script (runuser may scrub env; argv breaks on quotes).
    local qfile qkey qval
    qfile="$(printf '%q' "$file")"
    qkey="$(printf '%q' "$key")"
    qval="$(printf '%q' "$val")"
    runuser -u paperclip -- bash -c "
      set -euo pipefail
      file=$qfile
      key=$qkey
      val=$qval
      dir=\"\$(dirname \"\$file\")\"
      if [ -L \"\$file\" ]; then
        echo \"ERROR: refusing symlink path: \$file\" >&2
        exit 1
      fi
      if [ -e \"\$file\" ] && [ ! -f \"\$file\" ]; then
        echo \"ERROR: refusing non-regular file: \$file\" >&2
        exit 1
      fi
      tmp=\"\$(mktemp \"\${dir}/.paperclip-write.XXXXXX\")\"
      trap 'rm -f \"\$tmp\"' EXIT
      if [ -f \"\$file\" ]; then
        while IFS= read -r line || [ -n \"\$line\" ]; do
          case \"\$line\" in
            \"\${key}=\"*) ;;
            *) printf '%s\\n' \"\$line\" ;;
          esac
        done <\"\$file\" >\"\$tmp\"
      else
        : >\"\$tmp\"
      fi
      printf '%s=%s\\n' \"\$key\" \"\$val\" >>\"\$tmp\"
      if [ -L \"\$tmp\" ]; then
        echo \"ERROR: temp became a symlink: \$tmp\" >&2
        exit 1
      fi
      chmod 600 \"\$tmp\"
      mv -f \"\$tmp\" \"\$file\"
      trap - EXIT
    "
    return
  fi
  mkdir -p "$dir"
  tmp="$(mktemp "${dir}/.paperclip-write.XXXXXX")"
  if [ -f "$file" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in
        "${key}="*) ;;
        *) printf '%s\n' "$line" ;;
      esac
    done <"$file" >"$tmp"
  else
    : >"$tmp"
  fi
  printf '%s=%s\n' "$key" "$val" >>"$tmp"
  paperclip_finalize_temp "$file" "$tmp" 600
}

# Remove KEY= lines from an env file.
paperclip_remove_env_kv() {
  local file="$1" key="$2"
  local dir tmp
  [ -e "$file" ] || [ -L "$file" ] || return 0
  paperclip_assert_safe_target "$file" || return 1
  [ -f "$file" ] || return 0
  dir="$(dirname "$file")"
  if paperclip_is_user_path "$file"; then
    local qfile qkey
    qfile="$(printf '%q' "$file")"
    qkey="$(printf '%q' "$key")"
    runuser -u paperclip -- bash -c "
      set -euo pipefail
      file=$qfile
      key=$qkey
      dir=\"\$(dirname \"\$file\")\"
      if [ -L \"\$file\" ]; then
        echo \"ERROR: refusing symlink path: \$file\" >&2
        exit 1
      fi
      if [ ! -f \"\$file\" ]; then
        exit 0
      fi
      tmp=\"\$(mktemp \"\${dir}/.paperclip-write.XXXXXX\")\"
      trap 'rm -f \"\$tmp\"' EXIT
      while IFS= read -r line || [ -n \"\$line\" ]; do
        case \"\$line\" in
          \"\${key}=\"*) ;;
          *) printf '%s\\n' \"\$line\" ;;
        esac
      done <\"\$file\" >\"\$tmp\"
      if [ -L \"\$tmp\" ]; then
        echo \"ERROR: temp became a symlink: \$tmp\" >&2
        exit 1
      fi
      chmod 600 \"\$tmp\"
      mv -f \"\$tmp\" \"\$file\"
      trap - EXIT
    "
    return
  fi
  tmp="$(mktemp "${dir}/.paperclip-write.XXXXXX")"
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "${key}="*) ;;
      *) printf '%s\n' "$line" ;;
    esac
  done <"$file" >"$tmp"
  paperclip_finalize_temp "$file" "$tmp" 600
}
