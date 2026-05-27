#!/usr/bin/env bash
# 04 - hyprpm: refresh Hyprland plugins as the login user.
set -euo pipefail

# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/log.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/commons/lib/runtime.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/summary.sh"

vlarch_load_install_info "$VLARCH_INFO_FILE" \
  || vlarch_die "could not load ${VLARCH_INFO_FILE}"

if ((VLARCH_DRY_RUN)); then
  vlarch_update_note "hyprpm: dry-run (skipped)"
  exit 0
fi

if ! command -v hyprpm >/dev/null 2>&1; then
  vlarch_warn "hyprpm not found; skipping plugin refresh"
  vlarch_update_note "hyprpm: skipped (not installed)"
  exit 0
fi

update_status="ok"
reload_status="ok"

if ! su - "$VLARCH_USER" -c 'hyprpm update'; then
  vlarch_warn "hyprpm update failed"
  update_status="failed"
fi

if ! su - "$VLARCH_USER" -c 'hyprpm reload'; then
  vlarch_warn "hyprpm reload failed"
  reload_status="failed"
fi

if [[ "$update_status" == ok && "$reload_status" == ok ]]; then
  vlarch_update_note "hyprpm: ok"
else
  vlarch_update_note "hyprpm: failed (continued)"
fi
