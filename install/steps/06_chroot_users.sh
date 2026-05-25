#!/usr/bin/env bash
# 06 - chroot_users: root + user accounts, sudo, autologin drop-in.
set -euo pipefail

# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/log.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/config.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/chroot.sh"

vlarch_config_load "$VLARCH_CONFIG_FILE"
vlarch_config_validate

vlarch_step "Creating accounts and configuring autologin"
vlarch_chroot_run '
set -euo pipefail

user_shell="/bin/bash"
[[ -x /usr/bin/zsh ]] && user_shell="/usr/bin/zsh"

echo "root:${VLARCH_ROOT_PASSWORD}" | chpasswd
if ! id "${VLARCH_USER}" >/dev/null 2>&1; then
  useradd -m -G wheel -c "${VLARCH_REAL_NAME}" -s "${user_shell}" "${VLARCH_USER}"
fi
echo "${VLARCH_USER}:${VLARCH_USER_PASSWORD}" | chpasswd

# Vlarch is a personal flavor; passwordless sudo for wheel is intentional.
install -m 0440 /dev/stdin /etc/sudoers.d/wheel <<SUDOERS
%wheel ALL=(ALL:ALL) NOPASSWD: ALL
SUDOERS
visudo -c -f /etc/sudoers.d/wheel >/dev/null

mkdir -p /etc/systemd/system/getty@tty1.service.d
cat >/etc/systemd/system/getty@tty1.service.d/autologin.conf <<UNIT
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${VLARCH_USER} --noclear %I \$TERM
UNIT
'
