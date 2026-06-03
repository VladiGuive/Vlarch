#!/usr/bin/env bash
# Package install helpers. Sourced - no set -e here.

_VLARCH_UPDATE_LIB="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck disable=SC1091
source "${_VLARCH_UPDATE_LIB}/manifest.sh"
# shellcheck disable=SC1091
source "${_VLARCH_UPDATE_LIB}/pacman_repo.sh"

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

vlarch_remove_elephant_bin_pkgs() {
  local user="$1"
  local -a to_remove=()
  local pkg

  while IFS= read -r pkg; do
    [[ -n "$pkg" ]] || continue
    case "$pkg" in
      elephant-bin|elephant-*-bin) to_remove+=("$pkg") ;;
    esac
  done < <(pacman -Qq 2>/dev/null || true)

  ((${#to_remove[@]})) || return 0

  if declare -F vlarch_warn >/dev/null 2>&1; then
    vlarch_warn "removing elephant-bin packages (switching to source elephant): ${to_remove[*]}"
  fi

  pacman -Rdd --noconfirm "${to_remove[@]}" \
    || pacman -Rns --noconfirm "${to_remove[@]}" \
    || runuser -u "$user" -- yay -Rdd --noconfirm "${to_remove[@]}" \
    || true
}

vlarch_remove_walker_bin_pkg() {
  local user="$1"

  pacman -Q walker-bin >/dev/null 2>&1 || return 0

  if declare -F vlarch_warn >/dev/null 2>&1; then
    vlarch_warn "removing walker-bin (switching to source walker)"
  fi

  pacman -Rdd --noconfirm walker-bin \
    || pacman -Rns --noconfirm walker-bin \
    || runuser -u "$user" -- yay -Rdd --noconfirm walker-bin \
    || true
}

vlarch_yay_install_pkgs() {
  local user="$1"
  shift
  (("$#")) || return 0
  runuser -u "$user" -- yay -S --noconfirm --needed --norebuild --noredownload "$@"
}

vlarch_yay_install_manifests() {
  local user="$1"
  local pac_manifest="$2"
  local aur_manifest="$3"
  local pac_pkgs aur_pkgs
  local -a all_aur_pkgs walker_stack_pkgs other_pkgs=()
  local pkg

  pac_pkgs="$(vlarch_manifest_to_space_list "$pac_manifest")"
  aur_pkgs="$(vlarch_manifest_to_space_list "$aur_manifest")"

  if [[ -n "$pac_pkgs" ]]; then
    read -r -a pac_arr <<<"$pac_pkgs"
    vlarch_pacman_install_pkgs "${pac_arr[@]}"
  fi
  if [[ -n "$aur_pkgs" ]]; then
    read -r -a all_aur_pkgs <<< "$aur_pkgs"
    for pkg in "${all_aur_pkgs[@]}"; do
      case "$pkg" in
        walker|elephant|elephant-*) walker_stack_pkgs+=("$pkg") ;;
        *) other_pkgs+=("$pkg") ;;
      esac
    done

    if ((${#walker_stack_pkgs[@]})); then
      vlarch_remove_elephant_bin_pkgs "$user"
      vlarch_remove_walker_bin_pkg "$user"
      # One yay transaction keeps walker, elephant, and plugins on the same version.
      vlarch_yay_install_pkgs "$user" "${walker_stack_pkgs[@]}"
    fi
    if ((${#other_pkgs[@]})); then
      vlarch_yay_install_pkgs "$user" "${other_pkgs[@]}"
    fi
  fi
}
