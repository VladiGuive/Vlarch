#!/usr/bin/env bash
# 05 - finalize: reinstall vlarch CLI and bump install-info version.
set -euo pipefail

# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/log.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/runtime.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/summary.sh"

[[ -f "${VLARCH_BIN_DIR}/vlarch" ]] || vlarch_die "missing bin/vlarch"
[[ -f "${VLARCH_BIN_DIR}/start-hyprland" ]] || vlarch_die "missing bin/start-hyprland"

if ((VLARCH_DRY_RUN)); then
  vlarch_update_note "finalize: dry-run (would install bin/vlarch, start-hyprland and bump version to ${VLARCH_VERSION})"
  exit 0
fi

vlarch_run "install vlarch CLI" \
  install -Dm0755 "${VLARCH_BIN_DIR}/vlarch" /usr/local/bin/vlarch

vlarch_run "install start-hyprland" \
  install -Dm0755 "${VLARCH_BIN_DIR}/start-hyprland" /usr/local/bin/start-hyprland

vlarch_write_install_info_version "$VLARCH_VERSION" \
  || vlarch_die "could not update ${VLARCH_INFO_FILE}"

vlarch_update_note "finalize: ok (version ${VLARCH_VERSION})"
