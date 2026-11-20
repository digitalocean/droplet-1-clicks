#!/bin/bash
# Shared helpers for root-run Paperclip maintenance scripts.
# Refuse symlinks / hardlinks on paperclip-writable paths, write via a same-dir
# temp that is chown/chmod'd before mv, and never chown/chmod the final path
# after replace (avoids TOCTOU chown races onto system files).
#
# shellcheck shell=bash

paperclip_is_user_path() {
  case "$1" in
    /home/paperclip/*) return 0 ;;
    *) return 1 ;;
  esac
}

# Fail if path exists as a symlink, non-regular file, or hardlink (nlink != 1).
paperclip_assert_safe_target() {
  local path="$1"
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

# Finalize a same-dir temp into $path (chown/chmod temp, then mv). Never chown $path after.
paperclip_finalize_temp() {
  local path="$1" tmp="$2" mode="${3:-600}"
  if paperclip_is_user_path "$path"; then
    chown paperclip:paperclip "$tmp" || { rm -f "$tmp"; return 1; }
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
  tmp="$(mktemp "${dir}/.paperclip-write.XXXXXX")"
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "${key}="*) ;;
      *) printf '%s\n' "$line" ;;
    esac
  done <"$file" >"$tmp"
  paperclip_finalize_temp "$file" "$tmp" 600
}
