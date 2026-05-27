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
[[ -f "$zprofile" ]] || vlarch_die "missing install asset: $zprofile"

install -Dm0644 "$zprofile" /mnt/root/vlarch-zprofile

vlarch_chroot_run '
set -euo pipefail
home="/home/${VLARCH_USER}"
[[ -d "$home" ]] || { echo "$home missing" >&2; exit 1; }
install -Dm0644 -o "${VLARCH_USER}" -g "${VLARCH_USER}" /root/vlarch-zprofile "${home}/.zprofile"
rm -f /root/vlarch-zprofile
'
