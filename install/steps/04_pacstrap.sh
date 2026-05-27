#!/usr/bin/env bash
# 04 - pacstrap: install the minimal base into /mnt.
set -euo pipefail

# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/log.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/config.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/live.sh"

vlarch_config_load "$VLARCH_CONFIG_FILE"
vlarch_config_validate

mountpoint -q /mnt || vlarch_die "/mnt is not mounted; run step 03 first"

# Minimum base installed via pacstrap into /mnt.
pkgs=(
  base
  base-devel
  linux
  linux-firmware
  btrfs-progs
  grub
  efibootmgr
  networkmanager
  git
  curl
  sudo
  zsh
  rsync
)

# Enable multilib on the live ISO (so pacstrap can pull 32-bit deps if asked).
sed -i '/^\[multilib\]/,/Include/ s/^#//' /etc/pacman.conf

vlarch_live_refresh_mirrors
vlarch_live_sync_keyring

log="$(vlarch_log_path step)"
mkdir -p "$(dirname "$log")"
attempt=1
max_attempts=3
while ((attempt <= max_attempts)); do
  if declare -F vlarch_ui_tick >/dev/null 2>&1; then
    vlarch_ui_tick "pacstrap (${attempt}/${max_attempts})"
  fi
  rc=0
  {
    printf '\n--- pacstrap attempt %d/%d ---\n' "$attempt" "$max_attempts"
  } >>"$log"
  if ((VLARCH_VERBOSE)); then
    pacstrap -K /mnt "${pkgs[@]}" || rc=$?
  else
    pacstrap -K /mnt "${pkgs[@]}" >>"$log" 2>&1 || rc=$?
  fi
  if ((rc == 0)); then
    break
  fi
  if ((attempt == max_attempts)); then
    VLARCH_LAST_LOG="$log"
    vlarch_die "pacstrap failed after ${max_attempts} attempts (exit ${rc})"
  fi
  vlarch_live_refresh_mirrors
  vlarch_live_sync_keyring
  vlarch_run "pacman -Syy" pacman -Syy --noconfirm
  ((attempt++)) || true
done

missing=()
for pkg in "${pkgs[@]}"; do
  if ! arch-chroot /mnt pacman -Q "$pkg" >/dev/null 2>&1; then
    missing+=("$pkg")
  fi
done
((${#missing[@]} == 0)) || vlarch_die "pacstrap incomplete; missing: ${missing[*]}"

if ((VLARCH_VERBOSE)); then
  genfstab -U /mnt >>/mnt/etc/fstab
else
  if ! genfstab -U /mnt >>/mnt/etc/fstab 2>>"$log"; then
    VLARCH_LAST_LOG="$log"
    vlarch_die "genfstab failed"
  fi
fi

if [[ -f /etc/resolv.conf ]]; then
  cp -L /etc/resolv.conf /mnt/etc/resolv.conf
fi
