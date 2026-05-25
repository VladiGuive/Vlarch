#!/usr/bin/env bash
# 08 - chroot_aur: bootstrap yay, then install pacman.txt + aur.txt as the user.
set -euo pipefail

# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/log.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/config.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/chroot.sh"

vlarch_config_load "$VLARCH_CONFIG_FILE"
vlarch_config_validate

pac_manifest="${VLARCH_MANIFEST_DIR}/pacman.txt"
aur_manifest="${VLARCH_MANIFEST_DIR}/aur.txt"
[[ -f "$pac_manifest" ]] || vlarch_die "missing manifest: $pac_manifest"
[[ -f "$aur_manifest" ]] || vlarch_die "missing manifest: $aur_manifest"

read_manifest() {
  sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$1"
}

# Pass the package lists as space-separated strings to the chroot script.
VLARCH_PACMAN_PKGS="$(read_manifest "$pac_manifest" | tr '\n' ' ')"
VLARCH_AUR_PKGS="$(read_manifest "$aur_manifest" | tr '\n' ' ')"
export VLARCH_PACMAN_PKGS VLARCH_AUR_PKGS

vlarch_chroot_run '
set -euo pipefail

if ! id "${VLARCH_USER}" >/dev/null 2>&1; then
  echo "user ${VLARCH_USER} not found in chroot" >&2
  exit 1
fi

# yay-bin must be built as a non-root user.
if ! command -v yay >/dev/null 2>&1; then
  rm -rf /tmp/yay-bin
  install -d -o "${VLARCH_USER}" -g "${VLARCH_USER}" /tmp/yay-bin
  su - "${VLARCH_USER}" -c "
    set -euo pipefail
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
    cd /tmp/yay-bin
    makepkg -si --noconfirm
  "
fi

if [[ -n "${VLARCH_PACMAN_PKGS}" ]]; then
  su - "${VLARCH_USER}" -c "yay -S --noconfirm --needed --norebuild --noredownload ${VLARCH_PACMAN_PKGS}"
fi
if [[ -n "${VLARCH_AUR_PKGS}" ]]; then
  su - "${VLARCH_USER}" -c "yay -S --noconfirm --needed --norebuild --noredownload ${VLARCH_AUR_PKGS}"
fi

if [[ -x /usr/bin/zsh ]]; then
  chsh -s /usr/bin/zsh "${VLARCH_USER}" || true
fi
'
