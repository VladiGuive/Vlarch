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
source "${VLARCH_SCRIPT_DIR}/update/lib/session.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/summary.sh"

vlarch_load_install_info "$VLARCH_INFO_FILE" \
  || vlarch_die "could not load ${VLARCH_INFO_FILE}"

[[ -d "$VLARCH_DOTFILES_DIR" ]] || vlarch_die "dotfiles dir missing: $VLARCH_DOTFILES_DIR"

if ((VLARCH_DRY_RUN)); then
  vlarch_update_note "dotfiles: dry-run (would rsync to /home/${VLARCH_USER})"
  exit 0
fi

vlarch_run "deploy dotfiles" \
  vlarch_deploy_dotfiles "$VLARCH_USER" "$VLARCH_DOTFILES_DIR"

if vlarch_sync_tmux_plugins "$VLARCH_USER"; then
  vlarch_update_note "dotfiles: ok (tmux plugins installed)"
else
  vlarch_update_note "dotfiles: ok"
fi
