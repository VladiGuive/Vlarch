#!/usr/bin/env bash
# Package install helpers. Sourced - no set -e here.
# Requires: commons/lib/manifest.sh
# Public:
#   vlarch_bootstrap_yay <user>
#   vlarch_yay_install_pkgs <user> <pkg...>
#   vlarch_yay_install_manifests <user> <pacman.txt> <aur.txt>

_VLARCH_COMMONS_LIB="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck disable=SC1091
source "${_VLARCH_COMMONS_LIB}/manifest.sh"

vlarch_bootstrap_yay() {
  local user="$1"
  if command -v yay >/dev/null 2>&1; then
    return 0
  fi
  rm -rf /tmp/yay-bin
  install -d -o "$user" -g "$user" /tmp/yay-bin
  su - "$user" -c "
    set -euo pipefail
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
    cd /tmp/yay-bin
    makepkg -si --noconfirm
  "
}

vlarch_yay_install_pkgs() {
  local user="$1"
  shift
  (("$#")) || return 0
  su - "$user" -c "yay -S --noconfirm --needed --norebuild --noredownload $*"
}

vlarch_yay_install_manifests() {
  local user="$1"
  local pac_manifest="$2"
  local aur_manifest="$3"
  local pac_pkgs aur_pkgs

  pac_pkgs="$(vlarch_manifest_to_space_list "$pac_manifest")"
  aur_pkgs="$(vlarch_manifest_to_space_list "$aur_manifest")"

  if [[ -n "$pac_pkgs" ]]; then
    vlarch_yay_install_pkgs "$user" $pac_pkgs
  fi
  if [[ -n "$aur_pkgs" ]]; then
    vlarch_yay_install_pkgs "$user" $aur_pkgs
  fi
}
