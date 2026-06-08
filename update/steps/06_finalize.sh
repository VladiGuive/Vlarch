#!/usr/bin/env bash
# 06 - finalize: reinstall vlarch CLI and bump install-info version.
set -euo pipefail

# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/log.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/runtime.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/summary.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/session.sh"

vlarch_load_install_info "$VLARCH_INFO_FILE" \
  || vlarch_die "could not load ${VLARCH_INFO_FILE}"

[[ -f "${VLARCH_BIN_DIR}/vlarch" ]] || vlarch_die "missing bin/vlarch"
[[ -f "${VLARCH_BIN_DIR}/vlarch-tty-login" ]] || vlarch_die "missing bin/vlarch-tty-login"
[[ -f "${VLARCH_BIN_DIR}/vlarch-hyprpm-sync" ]] || vlarch_die "missing bin/vlarch-hyprpm-sync"
[[ -f "${VLARCH_BIN_DIR}/vlarch-walker-services" ]] || vlarch_die "missing bin/vlarch-walker-services"
[[ -f "${VLARCH_BIN_DIR}/vlarch-walker" ]] || vlarch_die "missing bin/vlarch-walker"
[[ -f "${VLARCH_BIN_DIR}/vlarch-waybar-update" ]] || vlarch_die "missing bin/vlarch-waybar-update"
[[ -f "${VLARCH_BIN_DIR}/vlarch-waybar-wifi" ]] || vlarch_die "missing bin/vlarch-waybar-wifi"
[[ -f "${VLARCH_BIN_DIR}/vlarch-waybar-battery" ]] || vlarch_die "missing bin/vlarch-waybar-battery"
[[ -f "${VLARCH_BIN_DIR}/vlarch-wifi" ]] || vlarch_die "missing bin/vlarch-wifi"
[[ -f "${VLARCH_BIN_DIR}/vlarch-keyring-unlock" ]] || vlarch_die "missing bin/vlarch-keyring-unlock"
[[ -f "${VLARCH_BIN_DIR}/vlarch-workspace" ]] || vlarch_die "missing bin/vlarch-workspace"
[[ -f "${VLARCH_BIN_DIR}/vlarch-portal-start" ]] || vlarch_die "missing bin/vlarch-portal-start"
[[ -f "${VLARCH_BIN_DIR}/vlarch-edge" ]] || vlarch_die "missing bin/vlarch-edge"
[[ -f "${VLARCH_BIN_DIR}/vlarch-overrides" ]] || vlarch_die "missing bin/vlarch-overrides"
[[ -f "${VLARCH_BIN_DIR}/vlarch-theme-generate" ]] || vlarch_die "missing bin/vlarch-theme-generate"
[[ -f "${VLARCH_SCRIPT_DIR}/update/lib/overrides.sh" ]] || vlarch_die "missing update/lib/overrides.sh"
[[ -f "${VLARCH_SCRIPT_DIR}/lib/version.sh" ]] || vlarch_die "missing lib/version.sh"

if ((VLARCH_DRY_RUN)); then
  vlarch_update_note "finalize: dry-run (would install bin scripts and bump version to ${VLARCH_VERSION})"
  exit 0
fi

vlarch_run "install vlarch CLI" \
  install -Dm0755 "${VLARCH_BIN_DIR}/vlarch" /usr/local/bin/vlarch

vlarch_run "install vlarch-tty-login" \
  install -Dm0755 "${VLARCH_BIN_DIR}/vlarch-tty-login" /usr/local/bin/vlarch-tty-login

vlarch_run "install vlarch-hyprpm-sync" \
  install -Dm0755 "${VLARCH_BIN_DIR}/vlarch-hyprpm-sync" /usr/local/bin/vlarch-hyprpm-sync

vlarch_run "install vlarch-walker-services" \
  install -Dm0755 "${VLARCH_BIN_DIR}/vlarch-walker-services" /usr/local/bin/vlarch-walker-services

vlarch_run "install vlarch-walker" \
  install -Dm0755 "${VLARCH_BIN_DIR}/vlarch-walker" /usr/local/bin/vlarch-walker

vlarch_run "install vlarch-waybar-update" \
  install -Dm0755 "${VLARCH_BIN_DIR}/vlarch-waybar-update" /usr/local/bin/vlarch-waybar-update

vlarch_run "install vlarch-waybar-wifi" \
  install -Dm0755 "${VLARCH_BIN_DIR}/vlarch-waybar-wifi" /usr/local/bin/vlarch-waybar-wifi

vlarch_run "install vlarch-waybar-battery" \
  install -Dm0755 "${VLARCH_BIN_DIR}/vlarch-waybar-battery" /usr/local/bin/vlarch-waybar-battery

vlarch_run "install vlarch-wifi" \
  install -Dm0755 "${VLARCH_BIN_DIR}/vlarch-wifi" /usr/local/bin/vlarch-wifi

vlarch_run "install vlarch-keyring-unlock" \
  install -Dm0755 "${VLARCH_BIN_DIR}/vlarch-keyring-unlock" /usr/local/bin/vlarch-keyring-unlock

vlarch_run "install vlarch-workspace" \
  install -Dm0755 "${VLARCH_BIN_DIR}/vlarch-workspace" /usr/local/bin/vlarch-workspace

vlarch_run "install vlarch-portal-start" \
  install -Dm0755 "${VLARCH_BIN_DIR}/vlarch-portal-start" /usr/local/bin/vlarch-portal-start

vlarch_run "install vlarch-edge" \
  install -Dm0755 "${VLARCH_BIN_DIR}/vlarch-edge" /usr/local/bin/vlarch-edge

vlarch_run "install vlarch-overrides" \
  install -Dm0755 "${VLARCH_BIN_DIR}/vlarch-overrides" /usr/local/bin/vlarch-overrides

vlarch_run "install vlarch-theme-generate" \
  install -Dm0755 "${VLARCH_BIN_DIR}/vlarch-theme-generate" /usr/local/bin/vlarch-theme-generate

if [[ -f /usr/local/share/vlarch/generate-nord-theme.py ]]; then
  vlarch_run "remove legacy theme generator script" \
    rm -f /usr/local/share/vlarch/generate-nord-theme.py
fi

vlarch_run "install overrides library" \
  install -Dm0644 "${VLARCH_SCRIPT_DIR}/update/lib/overrides.sh" /usr/local/share/vlarch/overrides.sh

vlarch_run "install version library" \
  install -Dm0644 "${VLARCH_SCRIPT_DIR}/lib/version.sh" /usr/local/share/vlarch/version.sh

if [[ -e /usr/local/bin/vlarch-elephant-start ]]; then
  rm -f /usr/local/bin/vlarch-elephant-start
fi

# Remove legacy wrapper that shadowed Hyprland's official /usr/bin/start-hyprland.
if [[ -e /usr/local/bin/start-hyprland ]]; then
  rm -f /usr/local/bin/start-hyprland
fi

# Drop stale first-boot marker and old ~/.local/bin/vlarch wrappers after a manual recovery.
if [[ -f "${VLARCH_STATE_DIR:-/var/lib/vlarch}/post-install.done" ]]; then
  rm -f "${VLARCH_STATE_DIR:-/var/lib/vlarch}/first-boot.pending"
fi
stale_vlarch="/home/${VLARCH_USER}/.local/bin/vlarch"
if [[ -e "$stale_vlarch" && "$stale_vlarch" != /usr/local/bin/vlarch ]]; then
  rm -f "$stale_vlarch"
fi

vlarch_write_install_info_version "$VLARCH_VERSION" \
  || vlarch_die "could not update ${VLARCH_INFO_FILE}"

vlarch_run "verify desktop readiness" \
  vlarch_verify_desktop_readiness "$VLARCH_USER"

if command -v vlarch-waybar-update >/dev/null 2>&1 && [[ -n "${VLARCH_USER:-}" ]]; then
  if command -v runuser >/dev/null 2>&1; then
    runuser -u "$VLARCH_USER" -- vlarch-waybar-update --refresh 2>/dev/null || true
  elif command -v sudo >/dev/null 2>&1; then
    sudo -u "$VLARCH_USER" vlarch-waybar-update --refresh 2>/dev/null || true
  fi
fi

vlarch_update_note "finalize: ok (version ${VLARCH_VERSION})"
