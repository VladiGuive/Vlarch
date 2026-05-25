#!/usr/bin/env bash
# Persisted install config helpers. The captured config lives at
# /tmp/vlarch-install.env so a stopped run can be resumed.
# Public: vlarch_config_save, vlarch_config_load, vlarch_config_validate

# Every VLARCH_* variable that the install pipeline relies on. Order matters
# only for human readability of the saved env file.
VLARCH_CONFIG_KEYS=(
  VLARCH_NETWORK_TYPE
  VLARCH_WIFI_SSID
  VLARCH_WIFI_PASSWORD
  VLARCH_TIMEZONE
  VLARCH_LOCALE
  VLARCH_DISK
  VLARCH_USER
  VLARCH_REAL_NAME
  VLARCH_USER_EMAIL
  VLARCH_USER_PASSWORD
  VLARCH_ROOT_PASSWORD
  VLARCH_LUKS_PASSPHRASE
  VLARCH_PART_EFI
  VLARCH_PART_BOOT
  VLARCH_PART_LUKS
  VLARCH_LUKS_UUID
)

# Variables that must be non-empty before partitioning starts.
VLARCH_CONFIG_REQUIRED=(
  VLARCH_NETWORK_TYPE
  VLARCH_TIMEZONE
  VLARCH_LOCALE
  VLARCH_DISK
  VLARCH_USER
  VLARCH_USER_PASSWORD
  VLARCH_ROOT_PASSWORD
  VLARCH_LUKS_PASSPHRASE
)

vlarch_config_save() {
  local path="$1"
  local key
  : >"$path"
  chmod 600 "$path"
  for key in "${VLARCH_CONFIG_KEYS[@]}"; do
    printf '%s=%q\n' "$key" "${!key:-}" >>"$path"
  done
}

vlarch_config_load() {
  local path="$1"
  [[ -f "$path" ]] || vlarch_die "config not found: $path"
  set -a
  # shellcheck disable=SC1090
  source "$path"
  set +a
}

vlarch_config_validate() {
  local key missing=()
  for key in "${VLARCH_CONFIG_REQUIRED[@]}"; do
    [[ -n "${!key:-}" ]] || missing+=("$key")
  done
  if ((${#missing[@]})); then
    vlarch_die "missing required config values: ${missing[*]}"
  fi
}
