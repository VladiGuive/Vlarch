#!/usr/bin/env bash
# Wallpaper deploy from install/assets/background.png. Sourced - no set -e here.

vlarch_install_wallpaper() {
  local assets_dir="${1:-${VLARCH_SCRIPT_DIR}/install/assets}"
  local root="${2:-}"
  local src="${assets_dir}/background.png"
  local dest="${root}/usr/share/vlarch/background.png"

  [[ -f "$src" ]] || return 1
  install -Dm0644 "$src" "$dest"
}
