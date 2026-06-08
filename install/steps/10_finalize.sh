#!/usr/bin/env bash
# 10 - finalize: install bin/vlarch, write install-info, arm first-boot, enable NM.
set -euo pipefail

# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/log.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/config.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/wallpapers.sh"

vlarch_config_load "$VLARCH_CONFIG_FILE"
vlarch_config_validate

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
[[ -f "${VLARCH_BIN_DIR}/vlarch-ensure-hermes" ]] || vlarch_die "missing bin/vlarch-ensure-hermes"
[[ -f "${VLARCH_BIN_DIR}/vlarch-hermes-dashboard" ]] || vlarch_die "missing bin/vlarch-hermes-dashboard"
[[ -f "${VLARCH_BIN_DIR}/vlarch-agent" ]] || vlarch_die "missing bin/vlarch-agent"
[[ -f "${VLARCH_SCRIPT_DIR}/update/lib/overrides.sh" ]] || vlarch_die "missing update/lib/overrides.sh"
[[ -f "${VLARCH_SCRIPT_DIR}/lib/version.sh" ]] || vlarch_die "missing lib/version.sh"

mountpoint -q /mnt || vlarch_die "/mnt not mounted; cannot finalize install"
[[ -f "${VLARCH_ASSETS_DIR}/background.png" ]] || vlarch_die "missing wallpaper asset: ${VLARCH_ASSETS_DIR}/background.png"
vlarch_install_wallpaper "${VLARCH_ASSETS_DIR}" /mnt

install -Dm0755 "${VLARCH_BIN_DIR}/vlarch" /mnt/usr/local/bin/vlarch
install -Dm0755 "${VLARCH_BIN_DIR}/vlarch-tty-login" /mnt/usr/local/bin/vlarch-tty-login
install -Dm0755 "${VLARCH_BIN_DIR}/vlarch-hyprpm-sync" /mnt/usr/local/bin/vlarch-hyprpm-sync
install -Dm0755 "${VLARCH_BIN_DIR}/vlarch-walker-services" /mnt/usr/local/bin/vlarch-walker-services
install -Dm0755 "${VLARCH_BIN_DIR}/vlarch-walker" /mnt/usr/local/bin/vlarch-walker
install -Dm0755 "${VLARCH_BIN_DIR}/vlarch-waybar-update" /mnt/usr/local/bin/vlarch-waybar-update
install -Dm0755 "${VLARCH_BIN_DIR}/vlarch-waybar-wifi" /mnt/usr/local/bin/vlarch-waybar-wifi
install -Dm0755 "${VLARCH_BIN_DIR}/vlarch-waybar-battery" /mnt/usr/local/bin/vlarch-waybar-battery
install -Dm0755 "${VLARCH_BIN_DIR}/vlarch-wifi" /mnt/usr/local/bin/vlarch-wifi
install -Dm0755 "${VLARCH_BIN_DIR}/vlarch-keyring-unlock" /mnt/usr/local/bin/vlarch-keyring-unlock
install -Dm0755 "${VLARCH_BIN_DIR}/vlarch-workspace" /mnt/usr/local/bin/vlarch-workspace
install -Dm0755 "${VLARCH_BIN_DIR}/vlarch-portal-start" /mnt/usr/local/bin/vlarch-portal-start
install -Dm0755 "${VLARCH_BIN_DIR}/vlarch-edge" /mnt/usr/local/bin/vlarch-edge
install -Dm0755 "${VLARCH_BIN_DIR}/vlarch-overrides" /mnt/usr/local/bin/vlarch-overrides
install -Dm0755 "${VLARCH_BIN_DIR}/vlarch-theme-generate" /mnt/usr/local/bin/vlarch-theme-generate
install -Dm0755 "${VLARCH_BIN_DIR}/vlarch-ensure-hermes" /mnt/usr/local/bin/vlarch-ensure-hermes
install -Dm0755 "${VLARCH_BIN_DIR}/vlarch-hermes-dashboard" /mnt/usr/local/bin/vlarch-hermes-dashboard
install -Dm0755 "${VLARCH_BIN_DIR}/vlarch-agent" /mnt/usr/local/bin/vlarch-agent
install -Dm0644 "${VLARCH_SCRIPT_DIR}/update/lib/overrides.sh" /mnt/usr/local/share/vlarch/overrides.sh
install -Dm0644 "${VLARCH_SCRIPT_DIR}/lib/version.sh" /mnt/usr/local/share/vlarch/version.sh

mkdir -p /mnt/etc/vlarch /mnt/var/lib/vlarch
{
  printf 'installed_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'user=%s\n'         "${VLARCH_USER}"
  printf 'disk=%s\n'         "${VLARCH_DISK}"
  printf 'timezone=%s\n'     "${VLARCH_TIMEZONE}"
  printf 'locale=%s\n'       "${VLARCH_LOCALE}"
  printf 'branch=%s\n'       "${VLARCH_GIT_BRANCH:-main}"
  if [[ -f "${VLARCH_SCRIPT_DIR}/version.txt" ]]; then
    printf 'version=%s\n' "$(tr -d '[:space:]' <"${VLARCH_SCRIPT_DIR}/version.txt")"
  fi
} >/mnt/etc/vlarch/install-info

# Persist non-secret runtime hints for `vlarch post-install` (WiFi join, etc).
{
  if [[ -n "${VLARCH_WIFI_SSID:-}" ]]; then
    printf 'VLARCH_WIFI_SSID=%q\n' "${VLARCH_WIFI_SSID}"
    printf 'VLARCH_WIFI_PASSWORD=%q\n' "${VLARCH_WIFI_PASSWORD:-}"
  fi
} >/mnt/var/lib/vlarch/runtime.env
chmod 600 /mnt/var/lib/vlarch/runtime.env

# First-login marker; ~/.zprofile checks for this and chains into `vlarch first-boot`.
: >/mnt/var/lib/vlarch/first-boot.pending

vlarch_run "systemctl enable NetworkManager (in target)" \
  arch-chroot /mnt systemctl enable NetworkManager.service
