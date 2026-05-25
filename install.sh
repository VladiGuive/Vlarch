#!/usr/bin/env bash
# Vlarch live-USB entry point. Runs from `curl ... | bash` on a fresh Arch live ISO.
# Three responsibilities: live preflight, bootstrap+clone, hand off to install/main.sh.
#
# Silent during normal operation; only fatal errors print, and they include the
# captured tail of the failing command. Set VLARCH_VERBOSE=1 (or pass --verbose
# through to main.sh) to stream every command's output.
set -euo pipefail

: "${VLARCH_GIT_URL:=https://github.com/VladiGuive/Vlarch.git}"
: "${VLARCH_GIT_BRANCH:=}"
: "${VLARCH_VERBOSE:=0}"
VLARCH_LIVE_MIN_FREE_K="${VLARCH_LIVE_MIN_FREE_K:-524288}" # ~512 MiB
VLARCH_BOOTSTRAP_LOG="${VLARCH_BOOTSTRAP_LOG:-/tmp/vlarch-bootstrap.log}"

_log() {
  ((VLARCH_VERBOSE)) && printf '[vlarch] %s\n' "$*"
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

# Run a command silently in quiet mode (output appended to bootstrap log) and
# stream it directly in verbose mode. Dies with the tail on failure.
_run() {
  local label="$1"; shift
  if ((VLARCH_VERBOSE)); then
    "$@" || _die "${label} failed (exit $?)"
    return 0
  fi
  : >>"$VLARCH_BOOTSTRAP_LOG"
  printf '\n--- %s ---\ncmd: %s\n' "$label" "$*" >>"$VLARCH_BOOTSTRAP_LOG"
  "$@" >>"$VLARCH_BOOTSTRAP_LOG" 2>&1 || _die "${label} failed (exit $?)"
}

# Live overlay is a RAM-backed tmpfs (~25% RAM by default). Expand to 75% when low.
_ensure_cowspace_early() {
  local cow="/run/archiso/cowspace"
  local target="${VLARCH_COW_SPACE_SIZE:-75%}"
  local path avail_k

  [[ "$(id -u)" -eq 0 ]] || return 0
  [[ -d "$cow" ]] || return 0
  mountpoint -q "$cow" 2>/dev/null || return 0

  for path in / "$cow"; do
    avail_k=$(df -k "$path" | awk 'NR==2 {print $4}')
    if ((avail_k < VLARCH_LIVE_MIN_FREE_K)); then
      _run "remount cowspace ${target}" mount -o remount,size="${target}" "$cow"
      break
    fi
  done

  avail_k=$(df -k / | awk 'NR==2 {print $4}')
  if ((avail_k < VLARCH_LIVE_MIN_FREE_K)); then
    _die "low disk space on / ($((avail_k / 1024)) MiB free; need >= $((VLARCH_LIVE_MIN_FREE_K / 1024)) MiB). Reboot and add cow_spacesize=${target} at GRUB."
  fi
}

_ensure_bootstrap_pkgs() {
  if command -v git >/dev/null 2>&1 && command -v fzf >/dev/null 2>&1; then
    return 0
  fi
  if [[ "$(id -u)" -ne 0 ]]; then
    _die "git/fzf missing; run as root on the live ISO so pacman can install them"
  fi
  command -v pacman >/dev/null 2>&1 || _die "pacman not found; this script expects an Arch live ISO"
  _run "pacman -Sy git fzf" pacman -Sy --noconfirm --needed git fzf
}

_run_main() {
  local root="$1"
  shift
  [[ -f "${root}/install/main.sh" ]] || _die "install/main.sh missing in ${root}"
  export VLARCH_SCRIPT_DIR="${root}"
  if [[ -f "${root}/version.txt" ]]; then
    VLARCH_VERSION="$(<"${root}/version.txt")"
    export VLARCH_VERSION
  fi
  exec bash "${root}/install/main.sh" "$@"
}

# When `install.sh` is run directly from a checked-out repo (not via curl), reuse it.
if [[ -n "${VLARCH_SCRIPT_DIR:-}" && -f "${VLARCH_SCRIPT_DIR}/install/main.sh" ]]; then
  _run_main "${VLARCH_SCRIPT_DIR}" "$@"
fi
_self="${BASH_SOURCE[0]:-}"
if [[ -n "${_self}" && -f "${_self}" && "${_self}" != *"/dev/fd/"* && "${_self}" != *"/proc/self/fd/"* ]]; then
  _root="$(cd -- "$(dirname -- "${_self}")" && pwd -P)"
  if [[ -f "${_root}/install/main.sh" ]]; then
    _run_main "${_root}" "$@"
  fi
fi

# Otherwise we are piped from curl: prep the live ISO, clone, and hand off.
_ensure_cowspace_early
_ensure_bootstrap_pkgs

WORKDIR="${VLARCH_WORKDIR:-$(mktemp -d /tmp/vlarch-install.XXXXXX)}"
[[ "$WORKDIR" == /tmp/vlarch-install.* ]] || _die "VLARCH_WORKDIR must be /tmp/vlarch-install.*"
trap 'rm -rf "${WORKDIR}" 2>/dev/null || true' EXIT
rm -rf "${WORKDIR}"

# Pre-scan args so --verbose flips bootstrap output back on (it's also passed
# through to main.sh below). --repo / --branch are consumed here; everything
# else passes through unchanged.
ARGS=()
while (($#)); do
  case "$1" in
    --verbose)
      VLARCH_VERBOSE=1
      ARGS+=("$1")
      shift
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

if [[ -n "${VLARCH_GIT_BRANCH}" ]]; then
  _run "git clone ${VLARCH_GIT_URL}#${VLARCH_GIT_BRANCH}" \
    git clone --depth 1 --branch "${VLARCH_GIT_BRANCH}" "${VLARCH_GIT_URL}" "${WORKDIR}"
else
  _run "git clone ${VLARCH_GIT_URL}" \
    git clone --depth 1 "${VLARCH_GIT_URL}" "${WORKDIR}"
fi

_run_main "${WORKDIR}" "${ARGS[@]}"
