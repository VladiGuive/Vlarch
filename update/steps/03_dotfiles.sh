#!/usr/bin/env bash
# 03 - dotfiles: non-destructive rsync from dotfiles/.
set -euo pipefail

# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/log.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/runtime.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/dotfiles.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/wallpapers.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/summary.sh"

vlarch_load_install_info "$VLARCH_INFO_FILE" \
  || vlarch_die "could not load ${VLARCH_INFO_FILE}"

[[ -d "$VLARCH_DOTFILES_DIR" ]] || vlarch_die "dotfiles dir missing: $VLARCH_DOTFILES_DIR"

if ((VLARCH_DRY_RUN)); then
  vlarch_update_note "dotfiles: dry-run (would rsync to /home/${VLARCH_USER})"
  vlarch_update_note "wallpapers: dry-run (would install to /usr/share/hypr)"
  exit 0
fi

vlarch_run "deploy dotfiles" \
  vlarch_deploy_dotfiles "$VLARCH_USER" "$VLARCH_DOTFILES_DIR"

vlarch_run "install wallpapers" \
  vlarch_install_wallpapers "${VLARCH_SCRIPT_DIR}/install/assets"

vlarch_update_note "dotfiles: ok"
vlarch_update_note "wallpapers: ok"
