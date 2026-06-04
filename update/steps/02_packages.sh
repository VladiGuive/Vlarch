#!/usr/bin/env bash
# 02 - packages: full system upgrade + manifest sync via yay.
set -euo pipefail

# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/log.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/runtime.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/packages.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/summary.sh"

vlarch_load_install_info "$VLARCH_INFO_FILE" \
  || vlarch_die "could not load ${VLARCH_INFO_FILE}"

pac_manifest="${VLARCH_MANIFEST_DIR}/pacman.txt"
aur_manifest="${VLARCH_MANIFEST_DIR}/aur.txt"
[[ -f "$pac_manifest" ]] || vlarch_die "missing manifest: $pac_manifest"
[[ -f "$aur_manifest" ]] || vlarch_die "missing manifest: $aur_manifest"

if ((VLARCH_DRY_RUN)); then
  vlarch_update_note "packages: dry-run (would run pacman -Syu and yay --needed)"
  exit 0
fi

vlarch_run_pacman_syu
vlarch_bootstrap_yay "$VLARCH_USER"
vlarch_run "pacman manifest sync" \
  vlarch_yay_install_manifests "$VLARCH_USER" "$pac_manifest" "$aur_manifest"

if grep -qx 'steam' <(vlarch_read_manifest "$pac_manifest"); then
  vlarch_run "install steam (multilib)" vlarch_pacman_install_steam
fi

vlarch_update_note "packages: ok"
