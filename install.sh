#!/usr/bin/env bash
set -euo pipefail
# Vars
VLARCH_GIT_URL=https://github.com/VladiGuive/Vlarch.git
VLARCH_GIT_BRANCH=dev
VLARCH_LIVE_MIN_FREE_K=524288
VLARCH_BOOTSTRAP_LOG=/tmp/vlarch-bootstrap.log
# Functions
_log() {
  printf '[vlarch] %s\n' "$*"
}
_die() {
  printf '[vlarch] CRITICAL ERROR: %s\n' "$*" >&2
  printf '[vlarch] SEE FULL LOG: %s\n' "$VLARCH_BOOTSTRAP_LOG" >&2
  exit 1
}
_print_bootstrap_logo() {
  cat <<'VLARCH_BOOTSTRAP_LOGO'
 _   ____             __
| | / / /__ _________/ /
| |/ / / _ `/ __/ __/ _ \
|___/_/\_,_/_/  \__/_//_/
VLARCH_BOOTSTRAP_LOGO
  printf '\n'
}
_print_bootstrap_preparing() {
  printf 'Preparing installation environment...'
}
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
  export VLARCH_SCRIPT_DIR="${root}"
  if [[ -f "${root}/version.txt" ]]; then
    VLARCH_VERSION="$(<"${root}/version.txt")"
    export VLARCH_VERSION
  fi
  exec bash "${root}/install/main.sh" "$@"
}

# Entrypoint
_print_bootstrap_logo
_print_bootstrap_preparing
_ensure_cowspace_early
_ensure_bootstrap_pkgs

WORKDIR="${VLARCH_WORKDIR:-$(mktemp -d /tmp/vlarch-install.XXXXXX)}"
trap 'rm -rf "${WORKDIR}" 2>/dev/null || true' EXIT
rm -rf "${WORKDIR}"

if [[ -n "${VLARCH_GIT_BRANCH}" ]]; then
  git clone --depth 1 --branch "${VLARCH_GIT_BRANCH}" "${VLARCH_GIT_URL}" "${WORKDIR}"
else
  git clone --depth 1 --branch main "${VLARCH_GIT_URL}" "${WORKDIR}"
fi

printf 'SUCCESS ON FLOW'
#_run_main "${WORKDIR}"
