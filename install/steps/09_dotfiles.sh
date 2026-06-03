#!/usr/bin/env bash
# 09 - zprofile: install first-boot hook from install/assets/.zprofile.
set -euo pipefail

# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/log.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/config.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/chroot.sh"

vlarch_config_load "$VLARCH_CONFIG_FILE"
vlarch_config_validate

zprofile="${VLARCH_ASSETS_DIR}/.zprofile"
zshrc="${VLARCH_ASSETS_DIR}/.zshrc"
[[ -f "$zprofile" ]] || vlarch_die "missing install asset: $zprofile"
[[ -f "$zshrc" ]] || vlarch_die "missing install asset: $zshrc"

install -Dm0644 "$zprofile" /mnt/root/vlarch-zprofile
install -Dm0644 "$zshrc" /mnt/root/vlarch-zshrc

vlarch_chroot_run '
set -euo pipefail
home="/home/${VLARCH_USER}"
[[ -d "$home" ]] || { echo "$home missing" >&2; exit 1; }
install -Dm0644 -o "${VLARCH_USER}" -g "${VLARCH_USER}" /root/vlarch-zprofile "${home}/.zprofile"
install -Dm0644 -o "${VLARCH_USER}" -g "${VLARCH_USER}" /root/vlarch-zshrc "${home}/.zshrc"
rm -f /root/vlarch-zprofile /root/vlarch-zshrc
'
