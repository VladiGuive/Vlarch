#!/usr/bin/env bash
# 02 - collect_input: TUI capturing every VLARCH_* the rest of the installer needs.
set -euo pipefail

# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/log.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/config.sh"

# Make sure stdin is a TTY when running under `curl | bash`.
if [[ ! -t 0 ]] && [[ -c /dev/tty ]]; then
  exec </dev/tty
fi
trap 'exit 130' INT

_fzf() {
  fzf --height=12 --layout=reverse --border "$@" || {
    local rc=$?
    ((rc == 130)) && exit 130
    return $rc
  }
}

_read_password_twice() {
  # NOTE: this function is called as $(_read_password_twice ...) so anything
  # written to stdout is captured into the password. Every visible character
  # (prompt newlines, validation messages) MUST go to stderr. Only the final
  # `printf '%s' "$first"` writes the captured value.
  local prompt="$1" first second
  while :; do
    read -rsp "$prompt: " first
    printf '\n' >&2
    read -rsp "$prompt (again): " second
    printf '\n' >&2
    if [[ "$first" != "$second" ]]; then
      printf '%b  passwords do not match; try again%b\n' "${VLARCH_NORD_YELLOW}" "${VLARCH_ESC_RESET}" >&2
      continue
    fi
    if [[ -z "$first" ]]; then
      printf '%b  password cannot be empty%b\n' "${VLARCH_NORD_YELLOW}" "${VLARCH_ESC_RESET}" >&2
      continue
    fi
    printf '%s' "$first"
    return 0
  done
}

_detect_network_type() {
  shopt -s nullglob
  local iface name state
  for iface in /sys/class/net/*; do
    name=$(basename "$iface")
    [[ "$name" == "lo" ]] && continue
    state=$(<"$iface/operstate" 2>/dev/null || echo down)
    [[ "$state" != "up" ]] && continue
    if [[ -d "$iface/phy80211" ]]; then
      printf 'wifi'
      return
    fi
  done
  printf 'ethernet'
}

clear || true
vlarch_ui_print_logo || true
printf '\n'
vlarch_ui_say "${VLARCH_NORD_FG}" "Vlarch installer"
printf '\n'

if [[ -f "$VLARCH_CONFIG_FILE" ]]; then
  reuse=$(printf 'Use existing config\nStart fresh\n' \
    | _fzf --header "Found saved config at ${VLARCH_CONFIG_FILE}" --prompt='> ')
  if [[ "$reuse" == "Use existing config" ]]; then
    vlarch_config_load "$VLARCH_CONFIG_FILE"
    if vlarch_config_validate 2>/dev/null; then
      exit 0
    fi
    printf '%b  saved config is incomplete; starting fresh%b\n' "${VLARCH_NORD_YELLOW}" "${VLARCH_ESC_RESET}" >&2
  fi
fi

current=$(_detect_network_type)
if [[ "$current" == "wifi" ]]; then
  VLARCH_NETWORK_TYPE="wifi"
else
  VLARCH_NETWORK_TYPE=$(printf 'ethernet\nwifi\n' \
    | _fzf --header 'Networking' --prompt='> ')
fi
if [[ "$VLARCH_NETWORK_TYPE" == "wifi" ]]; then
  read -rp "  WiFi SSID: " VLARCH_WIFI_SSID
  read -rsp "  WiFi password: " VLARCH_WIFI_PASSWORD
  echo
fi

VLARCH_TIMEZONE=$(find /usr/share/zoneinfo -type f ! -name '*.tab' ! -name '*.list' \
  | sed 's|/usr/share/zoneinfo/||' \
  | grep -vE '^(posix|right|Etc|Factory)/|^[A-Z0-9_-]+$' \
  | sort \
  | _fzf --header 'Timezone' --prompt='> ')
[[ -n "$VLARCH_TIMEZONE" ]] || vlarch_die "no timezone selected"

VLARCH_LOCALE=$(grep -E '^#?[a-z][a-zA-Z_]+\.UTF-8' /etc/locale.gen \
  | sed 's/^# *//' \
  | _fzf --query='en_US.UTF-8' --header 'Locale' --prompt='> ' \
  | awk '{print $1}')
[[ -n "$VLARCH_LOCALE" ]] || vlarch_die "no locale selected"

VLARCH_DISK=$(lsblk -dno PATH,SIZE,TYPE,MODEL \
  | awk '$3 == "disk" { $3=""; print }' \
  | _fzf --header 'Target disk (will be ERASED)' --prompt='> ' \
  | awk '{print $1}')
[[ -n "$VLARCH_DISK" ]] || vlarch_die "no disk selected"
[[ -b "$VLARCH_DISK" ]] || vlarch_die "not a block device: $VLARCH_DISK"

read -rp "Username: " VLARCH_USER
[[ "$VLARCH_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] \
  || vlarch_die "invalid username: $VLARCH_USER"
read -rp "Real name: " VLARCH_REAL_NAME
read -rp "Email: " VLARCH_USER_EMAIL

VLARCH_USER_PASSWORD=$(_read_password_twice "Password for $VLARCH_USER")
VLARCH_ROOT_PASSWORD=$(_read_password_twice "Root password")
VLARCH_LUKS_PASSPHRASE=$(_read_password_twice "Disk encryption passphrase (typed at every boot)")

export VLARCH_NETWORK_TYPE VLARCH_WIFI_SSID VLARCH_WIFI_PASSWORD
export VLARCH_TIMEZONE VLARCH_LOCALE VLARCH_DISK
export VLARCH_USER VLARCH_REAL_NAME VLARCH_USER_EMAIL
export VLARCH_USER_PASSWORD VLARCH_ROOT_PASSWORD VLARCH_LUKS_PASSPHRASE

vlarch_config_validate
vlarch_config_save "$VLARCH_CONFIG_FILE"

vlarch_ui_say "${VLARCH_NORD_CYAN}" "Captured configuration:"
printf '%b  user:        %s (%s)%b\n' "${VLARCH_NORD_DIM}" "${VLARCH_USER}" "${VLARCH_REAL_NAME}" "${VLARCH_ESC_RESET}"
printf '%b  network:     %s%s%b\n' "${VLARCH_NORD_DIM}" "${VLARCH_NETWORK_TYPE}" "${VLARCH_WIFI_SSID:+ (SSID: ${VLARCH_WIFI_SSID})}" "${VLARCH_ESC_RESET}"
printf '%b  timezone:    %s%b\n' "${VLARCH_NORD_DIM}" "${VLARCH_TIMEZONE}" "${VLARCH_ESC_RESET}"
printf '%b  locale:      %s%b\n' "${VLARCH_NORD_DIM}" "${VLARCH_LOCALE}" "${VLARCH_ESC_RESET}"
printf '%b  disk:        %s%b\n' "${VLARCH_NORD_DIM}" "${VLARCH_DISK}" "${VLARCH_ESC_RESET}"
printf '\n'
read -rp "$(printf '%b' "${VLARCH_NORD_YELLOW}")Press Enter to start the install (will ERASE ${VLARCH_DISK}), or Ctrl-C to abort...$(printf '%b' "${VLARCH_ESC_RESET}")" _
