#!/usr/bin/env bash
# 03 - hermes: bootstrap Hermes agent when ~/.hermes is missing.
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

[[ -f "${VLARCH_BIN_DIR}/vlarch-ensure-hermes" ]] \
  || vlarch_die "missing bin/vlarch-ensure-hermes"

if ((VLARCH_DRY_RUN)); then
  vlarch_update_note "hermes: dry-run (would run vlarch-ensure-hermes as ${VLARCH_USER})"
  exit 0
fi

vlarch_run "ensure hermes agent" \
  vlarch_run_user "$VLARCH_USER" "ensure hermes" \
    "${VLARCH_BIN_DIR}/vlarch-ensure-hermes --foreground"

hermes_py="/home/${VLARCH_USER}/.hermes/hermes-agent/venv/bin/python"
if [[ -x "$hermes_py" ]]; then
  vlarch_run "hermes setcap (port 80)" \
    setcap 'cap_net_bind_service=+ep' "$(readlink -f "$hermes_py")" || true
fi

vlarch_update_note "hermes: ok"
