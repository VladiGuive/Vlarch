#!/usr/bin/env bash
# 10 - finalize: install bin/vlarch, write install-info, arm first-boot, enable NM.
set -euo pipefail

# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/log.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/config.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/chroot.sh"

vlarch_config_load "$VLARCH_CONFIG_FILE"
vlarch_config_validate

[[ -f "${VLARCH_BIN_DIR}/vlarch" ]] || vlarch_die "missing bin/vlarch"

vlarch_step "Installing bin/vlarch into /mnt/usr/local/bin"
install -Dm0755 "${VLARCH_BIN_DIR}/vlarch" /mnt/usr/local/bin/vlarch

vlarch_step "Writing /etc/vlarch/install-info"
mkdir -p /mnt/etc/vlarch /mnt/var/lib/vlarch
{
  printf 'version=%s\n'      "${VLARCH_VERSION}"
  printf 'installed_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'user=%s\n'         "${VLARCH_USER}"
  printf 'disk=%s\n'         "${VLARCH_DISK}"
  printf 'timezone=%s\n'     "${VLARCH_TIMEZONE}"
  printf 'locale=%s\n'       "${VLARCH_LOCALE}"
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

vlarch_step "Enabling NetworkManager in target"
arch-chroot /mnt systemctl enable NetworkManager.service >/dev/null

vlarch_step "Finalize done"
