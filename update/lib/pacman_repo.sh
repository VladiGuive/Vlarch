#!/usr/bin/env bash
# Official-repo helpers (multilib, pacman manifest). Sourced - no set -e here.

vlarch_ensure_multilib_enabled() {
  local conf=/etc/pacman.conf
  [[ -f "$conf" ]] || return 1

  if ! grep -q 'multilib' "$conf"; then
    return 1
  fi

  # Uncomment the whole [multilib] section (idempotent if already enabled).
  sed -i '/\[multilib\]/,/Include/ s/^#//' "$conf"
  pacman -Sy --noconfirm
}

vlarch_pacman_install_pkgs() {
  local -a pkgs=("$@")
  ((${#pkgs[@]})) || return 0

  vlarch_ensure_multilib_enabled
  pacman -S --needed --noconfirm "${pkgs[@]}"
}

vlarch_pacman_install_steam() {
  vlarch_ensure_multilib_enabled || return 1
  pacman -Si steam >/dev/null 2>&1 \
    || { echo "steam: multilib repo unavailable (check /etc/pacman.conf)" >&2; return 1; }
  pacman -S --needed --noconfirm steam
}
