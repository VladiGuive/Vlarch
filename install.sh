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
_clear() {
  clear
  cat <<'VLARCH_BOOTSTRAP_LOGO'
 _   ____             __
| | / / /__ _________/ /
| |/ / / _ `/ __/ __/ _ \
|___/_/\_,_/_/  \__/_//_/
VLARCH_BOOTSTRAP_LOGO
}

# Entrypoint
echo "Installing Vlarch." >$VLARCH_BOOTSTRAP_LOG
reset
_clear
printf 'Preparing installation environment...\n'

# Needed deps
printf 'Installing needed dependencies...\n'
pacman -Sy --noconfirm --needed git fzf >>$VLARCH_BOOTSTRAP_LOG 2>&1 && printf 'Needed dependencies installed.\n' || _die "Could not install needed dependencies."

# Creating workdir
printf 'Creating temporal workdir...\n'
WORKDIR="${VLARCH_WORKDIR:-$(mktemp -d /tmp/vlarch-install.XXXXXX)}"
trap 'rm -rf "${WORKDIR}" 2>/dev/null || true' EXIT
rm -rf "${WORKDIR}"
printf 'Temporal workdir created.\n'

# Cloning repository
printf 'Cloning Vlarch repository...\n'
git clone --depth 1 --branch "${VLARCH_GIT_BRANCH}" "${VLARCH_GIT_URL}" "${WORKDIR}" >>"$VLARCH_BOOTSTRAP_LOG" 2>&1 && printf 'Repository cloned successfully.\n' || _die "Could not clone Vlarch repository."

# Repo root doubles as VLARCH_SCRIPT_DIR (matches update.sh contract)
VLARCH_SCRIPT_DIR="${WORKDIR}"
export VLARCH_SCRIPT_DIR

# Sourcing install utils from the cloned repo
printf 'Sourcing install utils...\n'
source "${VLARCH_SCRIPT_DIR}/install/lib/live.sh"

# 01 - preflight: prep the live ISO for installs.
printf 'Checking live environment...\n'
vlarch_live_ensure_cowspace
vlarch_live_assert_disk_space
vlarch_live_ensure_keyring
vlarch_live_refresh_mirrors
vlarch_live_sync_keyring
for cmd in pacstrap arch-chroot cryptsetup mkfs.btrfs mkfs.vfat mkfs.ext4 sgdisk efibootmgr lsblk blkid genfstab fzf; do
  command -v "$cmd" >/dev/null 2>&1 || _die "missing required command: $cmd"
done

_clear
