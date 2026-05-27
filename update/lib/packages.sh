#!/usr/bin/env bash
# Package install helpers. Sourced - no set -e here.

_VLARCH_UPDATE_LIB="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck disable=SC1091
source "${_VLARCH_UPDATE_LIB}/manifest.sh"

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

vlarch_remove_elephant_source_pkgs() {
  local user="$1" installed pkg to_remove=""

  installed="$(su - "$user" -c 'pacman -Qq' 2>/dev/null || true)"
  while IFS= read -r pkg; do
    [[ -n "$pkg" ]] || continue
    case "$pkg" in
      elephant-bin|elephant-*-bin) continue ;;
      elephant|elephant-*) to_remove+="$pkg " ;;
    esac
  done <<< "$installed"

  [[ -n "${to_remove// /}" ]] || return 0

  if declare -F vlarch_warn >/dev/null 2>&1; then
    vlarch_warn "removing source elephant packages (conflict with elephant-bin): ${to_remove}"
  fi
  su - "$user" -c "yay -Rns --noconfirm ${to_remove}"
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
    if [[ " $aur_pkgs " == *" elephant-bin "* ]]; then
      vlarch_remove_elephant_source_pkgs "$user"
    fi
    vlarch_yay_install_pkgs "$user" $aur_pkgs
  fi
}
