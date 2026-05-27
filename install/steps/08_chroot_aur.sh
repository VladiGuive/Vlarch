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

rm -rf /mnt/root/vlarch-chroot-assets
install -d /mnt/root/vlarch-chroot-assets/manifests /mnt/root/vlarch-chroot-assets/commons/lib
cp "$pac_manifest" /mnt/root/vlarch-chroot-assets/manifests/pacman.txt
cp "$aur_manifest" /mnt/root/vlarch-chroot-assets/manifests/aur.txt
cp -a "${VLARCH_SCRIPT_DIR}/commons/lib/"* /mnt/root/vlarch-chroot-assets/commons/lib/

vlarch_chroot_run '
set -euo pipefail
# shellcheck disable=SC1091
source /root/vlarch-chroot-assets/commons/lib/packages.sh

if ! id "${VLARCH_USER}" >/dev/null 2>&1; then
  echo "user ${VLARCH_USER} not found in chroot" >&2
  exit 1
fi

vlarch_bootstrap_yay "${VLARCH_USER}"
vlarch_yay_install_manifests "${VLARCH_USER}" \
  /root/vlarch-chroot-assets/manifests/pacman.txt \
  /root/vlarch-chroot-assets/manifests/aur.txt

if [[ -x /usr/bin/zsh ]]; then
  chsh -s /usr/bin/zsh "${VLARCH_USER}" || true
fi

rm -rf /root/vlarch-chroot-assets
'
