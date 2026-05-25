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

manifest="${VLARCH_MANIFEST_DIR}/pacstrap.txt"
[[ -f "$manifest" ]] || vlarch_die "missing manifest: $manifest"

mountpoint -q /mnt || vlarch_die "/mnt is not mounted; run step 03 first"

vlarch_info "Enabling [multilib] on the live ISO"
sed -i '/^\[multilib\]/,/Include/ s/^#//' /etc/pacman.conf

# Strip comments + blanks from the manifest.
mapfile -t pkgs < <(sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$manifest")
((${#pkgs[@]})) || vlarch_die "pacstrap manifest is empty"

vlarch_step "pacstrap (${#pkgs[@]} packages)"
attempt=1
max_attempts=3
while ((attempt <= max_attempts)); do
  if pacstrap -K /mnt "${pkgs[@]}"; then
    break
  fi
  if ((attempt == max_attempts)); then
    vlarch_die "pacstrap failed after ${max_attempts} attempts"
  fi
  vlarch_warn "pacstrap failed; refreshing mirrors and retrying"
  vlarch_live_refresh_mirrors
  pacman -Syy --noconfirm
  ((attempt++)) || true
done

vlarch_info "Verifying every manifest package is present in /mnt"
missing=()
for pkg in "${pkgs[@]}"; do
  if ! arch-chroot /mnt pacman -Q "$pkg" >/dev/null 2>&1; then
    missing+=("$pkg")
  fi
done
((${#missing[@]} == 0)) || vlarch_die "pacstrap incomplete; missing: ${missing[*]}"

vlarch_info "Generating /etc/fstab"
genfstab -U /mnt >>/mnt/etc/fstab

# Carry the live ISO's resolver into the chroot so AUR/yay calls have DNS.
if [[ -f /etc/resolv.conf ]]; then
  cp -L /etc/resolv.conf /mnt/etc/resolv.conf
fi

vlarch_step "pacstrap done"
