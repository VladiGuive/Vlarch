#!/usr/bin/env bash
# 06 - getty: restore tty1 autologin drop-in if missing or overwritten.
set -euo pipefail

# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/log.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/runtime.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/summary.sh"

vlarch_load_install_info "$VLARCH_INFO_FILE" \
  || vlarch_die "could not load ${VLARCH_INFO_FILE}"

if ((VLARCH_DRY_RUN)); then
  vlarch_update_note "getty: dry-run (skipped)"
  exit 0
fi

dropin="/etc/systemd/system/getty@tty1.service.d/autologin.conf"
install -d "$(dirname "$dropin")"

vlarch_run "configure tty1 autologin" \
  install -Dm0644 /dev/stdin "$dropin" <<UNIT
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${VLARCH_USER} --noclear %I \$TERM
UNIT

vlarch_update_note "getty: ok"
