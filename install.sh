#!/usr/bin/env bash
set -euo pipefail

VLARCH_GIT_URL=https://github.com/VladiGuive/Vlarch.git
VLARCH_GIT_BRANCH=dev
VLARCH_LIVE_MIN_FREE_K=524288
VLARCH_BOOTSTRAP_LOG=/var/log/vlarch_install.log

_die() {
  printf '[vlarch] CRITICAL ERROR: %s\n' "$*" >&2
  printf '[vlarch] SEE FULL LOG: %s\n' "$VLARCH_BOOTSTRAP_LOG" >&2
  exit 1
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
      mount -o remount,size="${target}" "$cow"
      break
    fi
  done

  avail_k=$(df -k / | awk 'NR==2 {print $4}')
  if ((avail_k < VLARCH_LIVE_MIN_FREE_K)); then
    _die "low disk space on / ($((avail_k / 1024)) MiB free; need >= $((VLARCH_LIVE_MIN_FREE_K / 1024)) MiB). Reboot and add cow_spacesize=${target} at GRUB."
  fi
}

# Entrypoint
reset
cat <<'VLARCH_BOOTSTRAP_LOGO'
 _   ____             __
| | / / /__ _________/ /
| |/ / / _ `/ __/ __/ _ \
|___/_/\_,_/_/  \__/_//_/
VLARCH_BOOTSTRAP_LOGO

printf 'Preparing installation environment...\n'

# Ensuring enough work space
printf 'Checking workspace size...\n'
_ensure_cowspace_early
printf 'Workspace size suficient.\n'

# Needed deps
printf 'Installing needed dependencies...\n'
pacman -Sy --noconfirm --needed git fzf >$VLARCH_BOOTSTRAP_LOG 2>&1 && printf 'Needed dependencies installed.\n' || _die "Could not install needed dependencies."

# Creating workdir
printf 'Creating temporal workdir...\n'
WORKDIR="${VLARCH_WORKDIR:-$(mktemp -d /tmp/vlarch-install.XXXXXX)}"
trap 'rm -rf "${WORKDIR}" 2>/dev/null || true' EXIT
rm -rf "${WORKDIR}"
printf 'Temporal workdir created.\n'

# Cloning repository
printf 'Cloning Vlarch repository...\n'
git clone --depth 1 --branch "${VLARCH_GIT_BRANCH}" "${VLARCH_GIT_URL}" "${WORKDIR}" >$VLARCH_BOOTSTRAP_LOG 2>&1 && printf 'Repository cloned successfully.\n' >/dev/null 2>&1 || _die "Could not clone Vlarch repository."

# Calling main install script from repo
printf 'SUCCESS ON FLOW'
#  local root="$1"
#  export VLARCH_SCRIPT_DIR="${root}"
#  if [[ -f "${root}/version.txt" ]]; then
#    VLARCH_VERSION="$(<"${root}/version.txt")"
#    export VLARCH_VERSION
#  fi
#  exec bash "${root}/install/main.sh" "$@"_run_main "${WORKDIR}"
