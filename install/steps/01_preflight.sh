#!/usr/bin/env bash
# 01 - preflight: prep the live ISO for installs.
set -euo pipefail

# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/log.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/live.sh"

vlarch_info "Ensuring live overlay has enough writable space"
vlarch_live_ensure_cowspace
vlarch_live_assert_disk_space

vlarch_info "Verifying pacman keyring"
vlarch_live_ensure_keyring

vlarch_info "Refreshing pacman mirrors"
vlarch_live_refresh_mirrors

vlarch_info "Verifying required commands"
for cmd in pacstrap arch-chroot cryptsetup mkfs.btrfs mkfs.vfat mkfs.ext4 sgdisk efibootmgr lsblk blkid genfstab fzf; do
  vlarch_require_cmd "$cmd"
done

vlarch_step "Preflight OK"
