#!/usr/bin/env bash
# Official-repo helpers (multilib, pacman manifest). Sourced - no set -e here.

vlarch_ensure_multilib_enabled() {
  local conf=/etc/pacman.conf
  [[ -f "$conf" ]] || return 1

  if grep -qE '^\s*#\[multilib\]' "$conf"; then
    sed -i '/^\[multilib\]/,/Include/ s/^#//' "$conf"
    pacman -Sy --noconfirm
  fi
}

vlarch_pacman_install_pkgs() {
  local -a pkgs=("$@")
  ((${#pkgs[@]})) || return 0

  vlarch_ensure_multilib_enabled
  pacman -S --needed --noconfirm "${pkgs[@]}"
}
