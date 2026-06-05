#!/usr/bin/env bash
# 03 - dotfiles: sync managed paths only (.zprofile, .config/, etc.).
set -euo pipefail

# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/log.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/runtime.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/dotfiles.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/overrides.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/wallpapers.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/session.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/summary.sh"

vlarch_load_install_info "$VLARCH_INFO_FILE" \
  || vlarch_die "could not load ${VLARCH_INFO_FILE}"

[[ -d "$VLARCH_DOTFILES_DIR" ]] || vlarch_die "dotfiles dir missing: $VLARCH_DOTFILES_DIR"

if ((VLARCH_DRY_RUN)); then
  vlarch_update_note "dotfiles: dry-run (would rsync to /home/${VLARCH_USER})"
  vlarch_update_note "overrides: dry-run (would apply ~/.overrides after dotfiles)"
  vlarch_update_note "wallpaper: dry-run (would install to /usr/share/vlarch/background.png)"
  exit 0
fi

vlarch_run "install wallpaper" \
  vlarch_install_wallpaper "${VLARCH_SCRIPT_DIR}/install/assets"

vlarch_run "deploy dotfiles" \
  vlarch_deploy_dotfiles "$VLARCH_USER" "$VLARCH_DOTFILES_DIR"

vlarch_run "apply dotfile overrides" \
  vlarch_apply_overrides "$VLARCH_USER"

_user_apps="/home/${VLARCH_USER}/.local/share/applications"
for _stale in microsoft-edge-stable.desktop vlarch-edge.desktop; do
  if [[ -f "${_user_apps}/${_stale}" ]]; then
    vlarch_run "remove stale Edge desktop entry (${_stale})" rm -f "${_user_apps}/${_stale}"
  fi
done

if command -v update-desktop-database >/dev/null 2>&1 && [[ -d "$_user_apps" ]]; then
  vlarch_run "refresh desktop database" \
    runuser -u "$VLARCH_USER" -- update-desktop-database "$_user_apps"
fi

if runuser -u "$VLARCH_USER" -- systemctl --user is-active --quiet elephant.service 2>/dev/null; then
  vlarch_run "restart elephant app index" \
    runuser -u "$VLARCH_USER" -- systemctl --user restart elephant.service
fi

vlarch_run "tmux plugins (TPM)" vlarch_sync_tmux_plugins "$VLARCH_USER"

vlarch_update_note "dotfiles: ok (tmux plugins installed)"
