#!/usr/bin/env bash
# Installed-system runtime helpers. Sourced - no set -e here.
# Public:
#   vlarch_load_install_info
#   vlarch_write_install_info_version <version>

vlarch_load_install_info() {
  local path="${1:-${VLARCH_INFO_FILE:-/etc/vlarch/install-info}}"
  VLARCH_USER=""
  VLARCH_INSTALLED_VERSION=""
  [[ -f "$path" ]] || return 1

  local line key value
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == *=* ]] || continue
    key="${line%%=*}"
    value="${line#*=}"
    case "$key" in
      user) VLARCH_USER="$value" ;;
      version) VLARCH_INSTALLED_VERSION="$value" ;;
    esac
  done <"$path"
  export VLARCH_USER VLARCH_INSTALLED_VERSION
  [[ -n "$VLARCH_USER" ]]
}

vlarch_write_install_info_version() {
  local version="$1"
  local path="${VLARCH_INFO_FILE:-/etc/vlarch/install-info}"
  local tmp updated_at line key
  [[ -f "$path" ]] || return 1

  updated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  tmp="$(mktemp)"
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == version=* ]]; then
      printf 'version=%s\n' "$version"
    elif [[ "$line" == updated_at=* ]]; then
      printf 'updated_at=%s\n' "$updated_at"
    else
      printf '%s\n' "$line"
    fi
  done <"$path" >"$tmp"

  if ! grep -q '^version=' "$tmp"; then
    printf 'version=%s\n' "$version" >>"$tmp"
  fi
  if ! grep -q '^updated_at=' "$tmp"; then
    printf 'updated_at=%s\n' "$updated_at" >>"$tmp"
  fi

  install -m 0644 "$tmp" "$path"
  rm -f "$tmp"
  VLARCH_INSTALLED_VERSION="$version"
  export VLARCH_INSTALLED_VERSION
}
