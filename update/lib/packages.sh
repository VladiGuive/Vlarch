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
  local build_dir
  build_dir="$(mktemp -d)"
  chown "$user:$user" "$build_dir"
  trap 'rm -rf "$build_dir"' RETURN
  su - "$user" -c "
    set -euo pipefail
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git \"${build_dir}\"
    cd \"${build_dir}\"
    makepkg -si --noconfirm
  "
}

vlarch_remove_conflicting_src_pkgs() {
  local user="$1"
  shift
  local -a to_remove=()
  local pkg src

  for pkg in "$@"; do
    [[ "$pkg" == *-bin ]] || continue
    src="${pkg%-bin}"
    pacman -Q "$src" >/dev/null 2>&1 && to_remove+=("$src")
  done

  ((${#to_remove[@]})) || return 0

  if declare -F vlarch_warn >/dev/null 2>&1; then
    vlarch_warn "removing source packages (switching to -bin): ${to_remove[*]}"
  fi

  pacman -Rdd --noconfirm "${to_remove[@]}" \
    || pacman -Rns --noconfirm "${to_remove[@]}" \
    || runuser -u "$user" -- yay -Rdd --noconfirm "${to_remove[@]}" \
    || true
}

vlarch_yay_install_missing_pkgs() {
  local user="$1"
  shift
  (("$#")) || return 0
  runuser -u "$user" -- yay -S --noconfirm --needed "$@"
}

vlarch_yay_upgrade_installed_pkgs() {
  local user="$1"
  shift
  (("$#")) || return 0
  # Omit --norebuild/--noredownload so yay can fetch AUR updates and rebuild.
  runuser -u "$user" -- yay -S --noconfirm --needed "$@"
}

vlarch_yay_sync_manifest_pkgs() {
  local user="$1"
  shift
  (("$#")) || return 0
  local -a missing=() installed=()
  local pkg

  for pkg in "$@"; do
    if pacman -Q "$pkg" >/dev/null 2>&1; then
      installed+=("$pkg")
    else
      missing+=("$pkg")
    fi
  done

  if ((${#missing[@]} && ${#installed[@]})); then
    # Mixed batch: one transaction keeps inter-dependent AUR versions aligned.
    runuser -u "$user" -- yay -S --noconfirm --needed "$@"
  elif ((${#missing[@]})); then
    vlarch_yay_install_missing_pkgs "$user" "${missing[@]}"
  elif ((${#installed[@]})); then
    vlarch_yay_upgrade_installed_pkgs "$user" "${installed[@]}"
  fi
}

vlarch_yay_install_manifests() {
  local user="$1"
  local pac_manifest="$2"
  local aur_manifest="$3"
  local pac_pkgs aur_pkgs
  local -a all_aur_pkgs other_pkgs=()
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
        *) other_pkgs+=("$pkg") ;;
      esac
    done

    if ((${#other_pkgs[@]})); then
      vlarch_yay_sync_manifest_pkgs "$user" "${other_pkgs[@]}"
    fi
  fi
}
