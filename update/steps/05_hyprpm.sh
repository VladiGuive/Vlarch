#!/usr/bin/env bash
# 05 - hyprpm: refresh plugin headers/builds as the install user (reload deferred).
set -euo pipefail

# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/log.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/runtime.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/session.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/summary.sh"

vlarch_load_install_info "$VLARCH_INFO_FILE" \
  || vlarch_die "could not load ${VLARCH_INFO_FILE}"

if ((VLARCH_DRY_RUN)); then
  vlarch_update_note "hyprpm: dry-run (skipped)"
  exit 0
fi

if ! command -v hyprpm >/dev/null 2>&1; then
  vlarch_update_note "hyprpm: ok (not installed)"
  exit 0
fi

vlarch_run "hyprpm build deps" \
  pacman -S --noconfirm --needed \
    cmake cpio pkg-config base-devel git meson ninja hyprland

if vlarch_hyprpm_update "$VLARCH_USER"; then
  vlarch_update_note "hyprpm: ok"
else
  vlarch_warn "hyprpm: header update failed (try: hyprpm purge-cache && hyprpm update -fv)"
  vlarch_update_note "hyprpm: failed"
fi
