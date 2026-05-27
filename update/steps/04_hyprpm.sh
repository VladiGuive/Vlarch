#!/usr/bin/env bash
# 04 - hyprpm: refresh Hyprland plugins as the login user.
set -euo pipefail

# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/log.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/runtime.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/summary.sh"

_hyprland_session_for_user() {
  local user="$1" uid runtime sig
  uid="$(id -u "$user")"
  runtime="/run/user/${uid}"
  [[ -d "${runtime}/hypr" ]] || return 1
  sig="$(find "${runtime}/hypr" -mindepth 1 -maxdepth 1 -printf '%f\n' 2>/dev/null | head -1)"
  [[ -n "$sig" ]]
}

_hyprpm_reload() {
  local user="$1" uid runtime sig
  uid="$(id -u "$user")"
  runtime="/run/user/${uid}"
  sig="$(find "${runtime}/hypr" -mindepth 1 -maxdepth 1 -printf '%f\n' 2>/dev/null | head -1)"
  su - "$user" -c "
    export XDG_RUNTIME_DIR='${runtime}'
    export HYPRLAND_INSTANCE_SIGNATURE='${sig}'
    hyprpm reload
  "
}

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
reload_status="deferred"

if ! su - "$VLARCH_USER" -c 'hyprpm update'; then
  vlarch_warn "hyprpm update failed"
  update_status="failed"
fi

if [[ "$update_status" == ok ]]; then
  if _hyprland_session_for_user "$VLARCH_USER"; then
    if _hyprpm_reload "$VLARCH_USER"; then
      reload_status="ok"
    else
      vlarch_warn "hyprpm reload failed"
      reload_status="failed"
    fi
  else
    vlarch_info "Hyprland not running; hyprpm reload deferred to session start"
  fi
fi

case "$update_status:$reload_status" in
  ok:ok)         vlarch_update_note "hyprpm: ok" ;;
  ok:deferred)   vlarch_update_note "hyprpm: ok (reload on Hyprland start)" ;;
  ok:failed)     vlarch_update_note "hyprpm: failed (reload)" ;;
  *)             vlarch_update_note "hyprpm: failed (continued)" ;;
esac
