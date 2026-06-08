#!/usr/bin/env bash
# Installed-system runtime helpers. Sourced - no set -e here.

vlarch_update_lock_path() {
  local state_dir="${VLARCH_STATE_DIR:-/var/lib/vlarch}"
  printf '%s/update.lock' "$state_dir"
}

vlarch_with_update_lock() {
  local lock_path="${1:-$(vlarch_update_lock_path)}"
  local state_dir rc=0
  shift
  ((${#@})) || return 1
  state_dir="$(dirname -- "$lock_path")"
  install -d -m 0755 "$state_dir" || return 1
  (
    flock -n 9 || exit 111
    "$@"
  ) 9>>"$lock_path" || rc=$?
  if ((rc == 111)); then
    return 111
  fi
  return "$rc"
}

vlarch_cdn_base_for_branch() {
  local branch="${1:-main}"
  branch="${branch//\//-}"
  if [[ "$branch" == main ]]; then
    printf 'https://vlarch.vladi.tech'
  else
    printf 'https://vlarch-%s.vladi.tech' "$branch"
  fi
}

vlarch_install_info_branch() {
  local path="${1:-${VLARCH_INFO_FILE:-/etc/vlarch/install-info}}"
  local branch=""
  [[ -f "$path" ]] || { printf '%s' main; return 0; }
  branch="$(grep -E '^branch=' "$path" | head -1 | cut -d= -f2- | tr -d '[:space:]')"
  printf '%s' "${branch:-main}"
}

vlarch_load_install_info() {
  local path="${1:-${VLARCH_INFO_FILE:-/etc/vlarch/install-info}}"
  VLARCH_USER=""
  VLARCH_INSTALLED_VERSION=""
  VLARCH_INSTALL_BRANCH=""
  [[ -f "$path" ]] || return 1

  local line key value
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == *=* ]] || continue
    key="${line%%=*}"
    value="${line#*=}"
    case "$key" in
      user) VLARCH_USER="$value" ;;
      version) VLARCH_INSTALLED_VERSION="$value" ;;
      branch) VLARCH_INSTALL_BRANCH="$value" ;;
    esac
  done <"$path"
  [[ -n "$VLARCH_INSTALL_BRANCH" ]] || VLARCH_INSTALL_BRANCH="main"
  export VLARCH_USER VLARCH_INSTALLED_VERSION VLARCH_INSTALL_BRANCH
  [[ -n "$VLARCH_USER" ]]
}

vlarch_write_install_info_version() {
  local version="$1"
  local path="${VLARCH_INFO_FILE:-/etc/vlarch/install-info}"
  local tmp updated_at
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

vlarch_write_install_info_branch() {
  local branch="$1"
  local path="${VLARCH_INFO_FILE:-/etc/vlarch/install-info}"
  local tmp
  [[ -f "$path" ]] || return 1
  [[ -n "$branch" ]] || return 1

  tmp="$(mktemp)"
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == branch=* ]]; then
      printf 'branch=%s\n' "$branch"
    else
      printf '%s\n' "$line"
    fi
  done <"$path" >"$tmp"

  if ! grep -q '^branch=' "$tmp"; then
    printf 'branch=%s\n' "$branch" >>"$tmp"
  fi

  install -m 0644 "$tmp" "$path"
  rm -f "$tmp"
  VLARCH_INSTALL_BRANCH="$branch"
  export VLARCH_INSTALL_BRANCH
}
