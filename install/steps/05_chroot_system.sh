#!/usr/bin/env bash
# 05 - chroot_system: timezone, locale, hostname inside /mnt.
set -euo pipefail

# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/log.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/config.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/chroot.sh"

vlarch_config_load "$VLARCH_CONFIG_FILE"
vlarch_config_validate

vlarch_chroot_run '
set -euo pipefail
ln -sf "/usr/share/zoneinfo/${VLARCH_TIMEZONE}" /etc/localtime
hwclock --systohc

if ! grep -qE "^${VLARCH_LOCALE} UTF-8" /etc/locale.gen; then
  if grep -qE "^#${VLARCH_LOCALE} UTF-8" /etc/locale.gen; then
    sed -i "s/^#\(${VLARCH_LOCALE} UTF-8\)/\1/" /etc/locale.gen
  else
    echo "${VLARCH_LOCALE} UTF-8" >>/etc/locale.gen
  fi
fi
locale-gen
echo "LANG=${VLARCH_LOCALE}" >/etc/locale.conf

echo "vlarch" >/etc/hostname
cat >/etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   vlarch.localdomain vlarch
HOSTS
'
