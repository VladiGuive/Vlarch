#!/usr/bin/env bash
# Vlarch live-USB entry point. Runs from `curl ... | bash` on a fresh Arch live ISO.
# Three responsibilities: live preflight, bootstrap+clone, hand off to install/main.sh.
set -euo pipefail

: "${VLARCH_GIT_URL:=https://github.com/VladiGuive/Vlarch.git}"
: "${VLARCH_GIT_BRANCH:=}"
VLARCH_LIVE_MIN_FREE_K="${VLARCH_LIVE_MIN_FREE_K:-524288}" # ~512 MiB

_log() { printf '[vlarch] %s\n' "$*"; }
_warn() { printf '[vlarch] warning: %s\n' "$*" >&2; }
_die() {
  printf '[vlarch] error: %s\n' "$*" >&2
  exit 1
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
      _log "Expanding live writable space (${cow}) to ${target}"
      mount -o remount,size="${target}" "$cow" 2>/dev/null \
        || _warn "could not expand ${cow}; reboot and add cow_spacesize=${target} at GRUB"
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
  _log "Installing live-ISO bootstrap packages: git, fzf"
  pacman -Sy --noconfirm --needed git fzf
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

# Allow --repo / --branch overrides without consuming other flags meant for main.sh.
ARGS=()
while (($#)); do
  case "$1" in
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

_log "Cloning ${VLARCH_GIT_URL} into ${WORKDIR}"
if [[ -n "${VLARCH_GIT_BRANCH}" ]]; then
  git clone --depth 1 --branch "${VLARCH_GIT_BRANCH}" "${VLARCH_GIT_URL}" "${WORKDIR}"
else
  git clone --depth 1 "${VLARCH_GIT_URL}" "${WORKDIR}"
fi

_run_main "${WORKDIR}" "${ARGS[@]}"
