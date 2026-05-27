#!/usr/bin/env bash
# 05 - finalize: reinstall vlarch CLI and bump install-info version.
set -euo pipefail

# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/log.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/runtime.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/summary.sh"

vlarch_load_install_info "$VLARCH_INFO_FILE" \
  || vlarch_die "could not load ${VLARCH_INFO_FILE}"

[[ -f "${VLARCH_BIN_DIR}/vlarch" ]] || vlarch_die "missing bin/vlarch"
[[ -f "${VLARCH_BIN_DIR}/vlarch-tty-login" ]] || vlarch_die "missing bin/vlarch-tty-login"
[[ -f "${VLARCH_BIN_DIR}/vlarch-hyprpm-sync" ]] || vlarch_die "missing bin/vlarch-hyprpm-sync"

if ((VLARCH_DRY_RUN)); then
  vlarch_update_note "finalize: dry-run (would install bin scripts and bump version to ${VLARCH_VERSION})"
  exit 0
fi

vlarch_run "install vlarch CLI" \
  install -Dm0755 "${VLARCH_BIN_DIR}/vlarch" /usr/local/bin/vlarch

vlarch_run "install vlarch-tty-login" \
  install -Dm0755 "${VLARCH_BIN_DIR}/vlarch-tty-login" /usr/local/bin/vlarch-tty-login

vlarch_run "install vlarch-hyprpm-sync" \
  install -Dm0755 "${VLARCH_BIN_DIR}/vlarch-hyprpm-sync" /usr/local/bin/vlarch-hyprpm-sync

# Remove legacy wrapper that shadowed Hyprland's official /usr/bin/start-hyprland.
if [[ -e /usr/local/bin/start-hyprland ]]; then
  rm -f /usr/local/bin/start-hyprland
fi

# Drop stale first-boot marker and old ~/.local/bin/vlarch wrappers after a manual recovery.
if [[ -f "${VLARCH_STATE_DIR:-/var/lib/vlarch}/post-install.done" ]]; then
  rm -f "${VLARCH_STATE_DIR:-/var/lib/vlarch}/first-boot.pending"
fi
stale_vlarch="/home/${VLARCH_USER}/.local/bin/vlarch"
if [[ -e "$stale_vlarch" && "$stale_vlarch" != /usr/local/bin/vlarch ]]; then
  rm -f "$stale_vlarch"
fi

vlarch_write_install_info_version "$VLARCH_VERSION" \
  || vlarch_die "could not update ${VLARCH_INFO_FILE}"

vlarch_update_note "finalize: ok (version ${VLARCH_VERSION})"
