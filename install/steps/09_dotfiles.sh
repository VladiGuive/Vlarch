#!/usr/bin/env bash
# 09 - dotfiles: rsync install/dotfiles/ into the new user's home.
set -euo pipefail

# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/log.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/config.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/chroot.sh"

vlarch_config_load "$VLARCH_CONFIG_FILE"
vlarch_config_validate

[[ -d "$VLARCH_DOTFILES_DIR" ]] || vlarch_die "dotfiles dir missing: $VLARCH_DOTFILES_DIR"

rm -rf /mnt/root/vlarch-dotfiles /mnt/root/vlarch-commons
cp -a "$VLARCH_DOTFILES_DIR" /mnt/root/vlarch-dotfiles
cp -a "${VLARCH_SCRIPT_DIR}/commons/lib" /mnt/root/vlarch-commons

vlarch_chroot_run '
set -euo pipefail
# shellcheck disable=SC1091
source /root/vlarch-commons/dotfiles.sh
vlarch_deploy_dotfiles "${VLARCH_USER}" /root/vlarch-dotfiles
rm -rf /root/vlarch-dotfiles /root/vlarch-commons
'
