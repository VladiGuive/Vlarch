#!/usr/bin/env bash
# Hypr wallpaper deploy. Sourced - no set -e here.

vlarch_install_wallpapers() {
  local assets_dir="${1:-${VLARCH_SCRIPT_DIR}/install/assets}"
  local dest="${2:-/usr/share/hypr}"
  local src="${assets_dir}/background.png"
  local n

  [[ -f "$src" ]] || return 1
  mkdir -p "$dest"
  for n in 0 1 2; do
    cp -f "$src" "${dest}/wall${n}.png"
  done
}
