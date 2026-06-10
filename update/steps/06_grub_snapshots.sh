#!/usr/bin/env bash
# 06 - grub_snapshots: Timeshift btrfs + grub-btrfs menu entries (LUKS-aware).
set -euo pipefail

# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/log.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/runtime.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/grub_snapshots.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/summary.sh"

vlarch_load_install_info "$VLARCH_INFO_FILE" \
  || vlarch_die "could not load ${VLARCH_INFO_FILE}"

if ((VLARCH_DRY_RUN)); then
  vlarch_update_note "grub_snapshots: dry-run (would configure timeshift + grub-btrfs)"
  exit 0
fi

if ! command -v grub-btrfs >/dev/null 2>&1; then
  vlarch_update_note "grub_snapshots: skipped (grub-btrfs not installed)"
  exit 0
fi

vlarch_run "configure timeshift btrfs" vlarch_timeshift_configure_btrfs
vlarch_run "configure grub-btrfs" vlarch_grub_btrfs_configure
vlarch_run "regenerate grub.cfg" vlarch_grub_regenerate

vlarch_update_note "grub_snapshots: ok"
