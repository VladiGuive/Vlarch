#!/usr/bin/env bash
# 01 - preflight: validate environment and load install-info.
set -euo pipefail

# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/log.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/commons/lib/runtime.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/summary.sh"

vlarch_require_cmd git
vlarch_require_cmd rsync
vlarch_require_cmd curl

vlarch_load_install_info "$VLARCH_INFO_FILE" \
  || vlarch_die "could not load ${VLARCH_INFO_FILE} (is this a Vlarch system?)"

id "$VLARCH_USER" >/dev/null 2>&1 \
  || vlarch_die "install user not found: ${VLARCH_USER}"

if command -v yay >/dev/null 2>&1; then
  :
elif id "$VLARCH_USER" >/dev/null 2>&1 && su - "$VLARCH_USER" -c 'command -v yay' >/dev/null 2>&1; then
  :
else
  vlarch_die "yay not found for user ${VLARCH_USER}"
fi

if ((VLARCH_DRY_RUN)); then
  vlarch_update_note "preflight: ok (dry-run)"
else
  if command -v timeshift >/dev/null 2>&1; then
    if timeshift --create --comments "vlarch pre-update" --tags D >/dev/null 2>&1; then
      vlarch_update_note "preflight: ok (timeshift snapshot created)"
    else
      vlarch_warn "timeshift pre-update snapshot failed"
      vlarch_update_note "preflight: ok (timeshift snapshot skipped)"
    fi
  else
    vlarch_update_note "preflight: ok"
  fi
fi
