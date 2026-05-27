#!/usr/bin/env bash
# Vlarch update entry point. Runs from `curl ... | bash` or via `vlarch update`.
# Compares CDN version.txt against /etc/vlarch/install-info, clones the repo,
# and hands off to update/main.sh.
#
# Silent during normal operation; only fatal errors print, and they include the
# captured tail of the failing command. Set VLARCH_VERBOSE=1 (or pass --verbose)
# to stream every command's output.
set -euo pipefail

: "${VLARCH_GIT_URL:=https://github.com/VladiGuive/Vlarch.git}"
: "${VLARCH_GIT_BRANCH:=}"
: "${VLARCH_VERBOSE:=0}"
: "${VLARCH_CDN_BASE:=https://vlarch.vladi.tech}"
: "${VLARCH_INFO_FILE:=/etc/vlarch/install-info}"
: "${VLARCH_FORCE_UPDATE:=0}"
VLARCH_BOOTSTRAP_LOG="${VLARCH_BOOTSTRAP_LOG:-/tmp/vlarch-update-bootstrap.log}"

_log() {
  if ((VLARCH_VERBOSE)); then
    printf '[vlarch] %s\n' "$*"
  fi
}
_die() {
  printf '[vlarch] error: %s\n' "$*" >&2
  if [[ -s "$VLARCH_BOOTSTRAP_LOG" ]]; then
    printf '[vlarch] last 20 lines of %s:\n' "$VLARCH_BOOTSTRAP_LOG" >&2
    tail -n 20 "$VLARCH_BOOTSTRAP_LOG" | sed 's/^/  /' >&2
    printf '[vlarch] full log: %s\n' "$VLARCH_BOOTSTRAP_LOG" >&2
  fi
  exit 1
}

_run() {
  local label="$1"
  shift
  if ((VLARCH_VERBOSE)); then
    "$@" || _die "${label} failed (exit $?)"
    return 0
  fi
  : >>"$VLARCH_BOOTSTRAP_LOG"
  printf '\n--- %s ---\ncmd: %s\n' "$label" "$*" >>"$VLARCH_BOOTSTRAP_LOG"
  "$@" >>"$VLARCH_BOOTSTRAP_LOG" 2>&1 || _die "${label} failed (exit $?)"
}

_local_version() {
  local path="$1"
  [[ -f "$path" ]] || return 0
  grep -E '^version=' "$path" | head -1 | cut -d= -f2- | tr -d '[:space:]'
}

_fetch_remote_version() {
  curl -fsSL "${VLARCH_CDN_BASE}/version.txt" | tr -d '[:space:]'
}

_check_version_gate() {
  if ((VLARCH_FORCE_UPDATE)); then
    _log "Skipping version check (--force)"
    return 0
  fi

  local remote local_ver
  remote="$(_fetch_remote_version)" || _die "could not fetch remote version from ${VLARCH_CDN_BASE}/version.txt"
  [[ -n "$remote" ]] || _die "remote version from ${VLARCH_CDN_BASE}/version.txt is empty"

  local_ver="$(_local_version "$VLARCH_INFO_FILE")"
  if [[ -n "$local_ver" && "$local_ver" == "$remote" ]]; then
    printf '[vlarch] already up to date (%s)\n' "$remote"
    exit 0
  fi

  printf '[vlarch] update available: %s -> %s\n' "${local_ver:-none}" "$remote"
}

_run_main() {
  local root="$1"
  shift
  [[ -f "${root}/update/main.sh" ]] || _die "update/main.sh missing in ${root}"
  export VLARCH_SCRIPT_DIR="${root}"
  if [[ -f "${root}/version.txt" ]]; then
    VLARCH_VERSION="$(tr -d '[:space:]' <"${root}/version.txt")"
    export VLARCH_VERSION
  fi
  exec bash "${root}/update/main.sh" "$@"
}

# Parse bootstrap-level flags first (consumed here; rest pass through to main).
ARGS=()
while (($#)); do
  case "$1" in
    --verbose)
      VLARCH_VERBOSE=1
      ARGS+=("$1")
      shift
      ;;
    --quiet)
      VLARCH_VERBOSE=0
      ARGS+=("$1")
      shift
      ;;
    --force)
      VLARCH_FORCE_UPDATE=1
      ARGS+=("$1")
      shift
      ;;
    --cdn-base)
      [[ $# -ge 2 ]] || _die "--cdn-base requires a URL"
      VLARCH_CDN_BASE="${2%/}"
      shift 2
      ;;
    --repo)
      [[ $# -ge 2 ]] || _die "--repo requires a URL"
      VLARCH_GIT_URL="$2"
      shift 2
      ;;
    --branch)
      [[ $# -ge 2 ]] || _die "--branch requires a ref"
      VLARCH_GIT_BRANCH="$2"
      shift 2
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done
export VLARCH_VERBOSE VLARCH_CDN_BASE VLARCH_FORCE_UPDATE

# When update.sh is run directly from a checked-out repo, reuse it.
if [[ -n "${VLARCH_SCRIPT_DIR:-}" && -f "${VLARCH_SCRIPT_DIR}/update/main.sh" ]]; then
  _check_version_gate
  _run_main "${VLARCH_SCRIPT_DIR}" "${ARGS[@]}"
fi
_self="${BASH_SOURCE[0]:-}"
if [[ -n "${_self}" && -f "${_self}" && "${_self}" != *"/dev/fd/"* && "${_self}" != *"/proc/self/fd/"* ]]; then
  _root="$(cd -- "$(dirname -- "${_self}")" && pwd -P)"
  if [[ -f "${_root}/update/main.sh" ]]; then
    _check_version_gate
    _run_main "${_root}" "${ARGS[@]}"
  fi
fi

[[ "$(id -u)" -eq 0 ]] || _die "update must run as root (try: vlarch update)"

command -v git >/dev/null 2>&1 || _die "git not found"
command -v curl >/dev/null 2>&1 || _die "curl not found"

_check_version_gate

WORKDIR="${VLARCH_WORKDIR:-$(mktemp -d /tmp/vlarch-update.XXXXXX)}"
[[ "$WORKDIR" == /tmp/vlarch-update.* ]] || _die "VLARCH_WORKDIR must be /tmp/vlarch-update.*"
trap 'rm -rf "${WORKDIR}" 2>/dev/null || true' EXIT
rm -rf "${WORKDIR}"

if [[ -n "${VLARCH_GIT_BRANCH}" ]]; then
  _run "git clone ${VLARCH_GIT_URL}#${VLARCH_GIT_BRANCH}" \
    git clone --depth 1 --branch "${VLARCH_GIT_BRANCH}" "${VLARCH_GIT_URL}" "${WORKDIR}"
else
  _run "git clone ${VLARCH_GIT_URL}" \
    git clone --depth 1 "${VLARCH_GIT_URL}" "${WORKDIR}"
fi

_run_main "${WORKDIR}" "${ARGS[@]}"
