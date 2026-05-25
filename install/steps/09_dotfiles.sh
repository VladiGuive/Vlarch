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

vlarch_step "Staging dotfiles into /mnt/root/vlarch-dotfiles"
rm -rf /mnt/root/vlarch-dotfiles
cp -a "$VLARCH_DOTFILES_DIR" /mnt/root/vlarch-dotfiles

vlarch_chroot_run '
set -euo pipefail
home="/home/${VLARCH_USER}"
[[ -d "$home" ]] || { echo "$home missing" >&2; exit 1; }

# Drop default skel files that we want to fully replace.
rm -f "$home/.zshrc" "$home/.zprofile" "$home/.bashrc" "$home/.bash_profile"

# rsync without --delete so re-running the installer is non-destructive.
rsync -a /root/vlarch-dotfiles/ "$home/"
chown -R "${VLARCH_USER}:${VLARCH_USER}" "$home"
rm -rf /root/vlarch-dotfiles
'
