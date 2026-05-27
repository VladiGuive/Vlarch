#!/usr/bin/env bash
# 04 - hyprpm: ensure plugin headers and builds are up to date (quiet).
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
  pacman -S --noconfirm --needed cmake cpio pkg-config base-devel git hyprland

vlarch_hyprpm_update "$VLARCH_USER"

if vlarch_hyprland_session_for_user "$VLARCH_USER"; then
  uid="$(id -u "$VLARCH_USER")"
  runtime="/run/user/${uid}"
  sig="$(vlarch_hyprland_signature_for_user "$VLARCH_USER")"
  vlarch_run_user "$VLARCH_USER" "hyprpm reload" \
    "export XDG_RUNTIME_DIR='${runtime}' HYPRLAND_INSTANCE_SIGNATURE='${sig}'; hyprpm reload -n" \
    || true
fi

vlarch_update_note "hyprpm: ok"
