#!/usr/bin/env bash
set -euo pipefail

VLARCH_GIT_URL=https://github.com/VladiGuive/Vlarch.git
VLARCH_GIT_BRANCH=dev
VLARCH_LIVE_MIN_FREE_K=524288
VLARCH_BOOTSTRAP_LOG=/var/log/vlarch_install.log
VLARCH_CONFIG_FILE="${VLARCH_CONFIG_FILE:-/tmp/vlarch-install.env}"

_die() {
  printf '[vlarch] CRITICAL ERROR: %s\n' "$*" >&2
  printf '[vlarch] SEE FULL LOG: %s\n' "$VLARCH_BOOTSTRAP_LOG" >&2
  exit 1
}
_clear() {
  clear
  cat <<'VLARCH_BOOTSTRAP_LOGO'
 _   ____             __
| | / / /__ _________/ /
| |/ / / _ `/ __/ __/ _ \
|___/_/\_,_/_/  \__/_//_/
VLARCH_BOOTSTRAP_LOGO
}

# ---- config helpers (migrated from install/lib/config.sh) ----

# Every VLARCH_* variable the install pipeline relies on. Order matters only
# for human readability of the saved env file.
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
  [[ -f "$path" ]] || _die "config not found: $path"
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
    _die "missing required config values: ${missing[*]}"
  fi
}

# ---- live-ISO helpers (migrated from install/lib/live.sh) ----

vlarch_live_path_free_k() {
  df -k "$1" | awk 'NR==2 {print $4}'
}

# Runs a command, appending output to the bootstrap log; dies on failure.
vlarch_live_run() {
  local label="$1"
  shift
  printf '\n--- %s ---\ncmd: %s\n' "$label" "$*" >>"$VLARCH_BOOTSTRAP_LOG"
  "$@" >>"$VLARCH_BOOTSTRAP_LOG" 2>&1 || _die "${label} failed (exit $?)"
}

vlarch_live_ensure_cowspace() {
  local cow="/run/archiso/cowspace"
  local target="${VLARCH_COW_SPACE_SIZE:-75%}"
  local path avail_k

  [[ -d "$cow" ]] || return 0
  mountpoint -q "$cow" 2>/dev/null || return 0

  for path in / "$cow"; do
    avail_k=$(vlarch_live_path_free_k "$path")
    if ((avail_k < VLARCH_LIVE_MIN_FREE_K)); then
      vlarch_live_run "expand cowspace to ${target}" \
        mount -o remount,size="${target}" "$cow"
      return 0
    fi
  done
}

vlarch_live_assert_disk_space() {
  local path avail_k
  for path in / /run/archiso/cowspace /var/cache/pacman/pkg; do
    [[ -e "$path" ]] || continue
    avail_k=$(vlarch_live_path_free_k "$path")
    if ((avail_k < VLARCH_LIVE_MIN_FREE_K)); then
      _die "low disk space on ${path} ($((avail_k / 1024)) MiB free; need >= $((VLARCH_LIVE_MIN_FREE_K / 1024)) MiB)"
    fi
  done
}

# Initialize/repair the live-ISO pacman keyring if needed.
vlarch_live_ensure_keyring() {
  local gpg_dir="/etc/pacman.d/gnupg"
  local healthy=1

  command -v pacman-key >/dev/null 2>&1 || _die "pacman-key missing on live ISO"

  if [[ ! -d "$gpg_dir" ]]; then
    healthy=0
  elif ! pacman-key -l >/dev/null 2>&1; then
    healthy=0
  elif ! pacman-key -l 2>/dev/null | grep -q 'Arch Linux'; then
    healthy=0
  fi

  ((healthy)) && return 0

  vlarch_live_run "pacman-key --init" pacman-key --init
  vlarch_live_run "pacman-key --populate archlinux" pacman-key --populate archlinux

  pacman-key -l >/dev/null 2>&1 ||
    _die "pacman keyring still unhealthy after --init/--populate"
}

# Pull the current archlinux-keyring from mirrors and refresh packager trust.
# Live ISOs ship a stale keyring; without this, pacstrap fails with "unknown trust".
vlarch_live_sync_keyring() {
  command -v pacman-key >/dev/null 2>&1 || _die "pacman-key missing on live ISO"
  [[ -s /etc/pacman.d/mirrorlist ]] ||
    _die "mirrorlist empty; run vlarch_live_refresh_mirrors first"

  vlarch_live_run "pacman -Sy archlinux-keyring" \
    pacman -Sy archlinux-keyring --needed --noconfirm
  vlarch_live_run "pacman-key --populate archlinux" \
    pacman-key --populate archlinux
}

vlarch_live_refresh_mirrors() {
  if command -v reflector >/dev/null 2>&1; then
    vlarch_live_run "reflector mirrorlist refresh" \
      reflector -f 30 --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
  fi
  [[ -s /etc/pacman.d/mirrorlist ]] || _die "/etc/pacman.d/mirrorlist is empty"
  grep -q '^[[:space:]]*Server[[:space:]]*=' /etc/pacman.d/mirrorlist ||
    _die "/etc/pacman.d/mirrorlist has no Server entries"
}

# ---- TUI input helpers (migrated from install/steps/02_collect_input.sh) ----

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
      printf '  passwords do not match; try again\n' >&2
      continue
    fi
    if [[ -z "$first" ]]; then
      printf '  password cannot be empty\n' >&2
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

# ---- entrypoint ----

echo "Installing Vlarch." >$VLARCH_BOOTSTRAP_LOG
reset
_clear

printf 'Preparing installation environment...\n'

# Needed deps
printf '  Installing needed dependencies...\n'
pacman -Sy --noconfirm --needed git fzf >>$VLARCH_BOOTSTRAP_LOG 2>&1 && printf '  Needed dependencies installed.\n' || _die "Could not install needed dependencies."

# Creating workdir
printf '  Creating temporal workdir...\n'
WORKDIR="${VLARCH_WORKDIR:-$(mktemp -d /tmp/vlarch-install.XXXXXX)}"
trap 'rm -rf "${WORKDIR}" 2>/dev/null || true' EXIT
rm -rf "${WORKDIR}"
printf '  Temporal workdir created.\n'

# Cloning repository
printf '  Cloning Vlarch repository...\n'
git clone --depth 1 --branch "${VLARCH_GIT_BRANCH}" "${VLARCH_GIT_URL}" "${WORKDIR}" >>"$VLARCH_BOOTSTRAP_LOG" 2>&1 && printf '  Repository cloned successfully.\n' || _die "Could not clone Vlarch repository."

# Repo root doubles as VLARCH_SCRIPT_DIR (matches update.sh contract)
VLARCH_SCRIPT_DIR="${WORKDIR}"
export VLARCH_SCRIPT_DIR

# 01 - preflight: prep the live ISO for installs.
printf 'Checking live environment...\n'

printf '  Expanding cowspace if needed...\n'
vlarch_live_ensure_cowspace
printf '  Cowspace ok.\n'

printf '  Checking disk space...\n'
vlarch_live_assert_disk_space
printf '  Disk space suficient.\n'

printf '  Checking pacman keyring...\n'
vlarch_live_ensure_keyring
printf '  Keyring ok.\n'

printf '  Refreshing mirrors...\n'
vlarch_live_refresh_mirrors
printf '  Mirrors refreshed.\n'

printf '  Syncing archlinux-keyring...\n'
vlarch_live_sync_keyring
printf '  Keyring synced.\n'

printf '  Checking required commands...\n'
for cmd in pacstrap arch-chroot cryptsetup mkfs.btrfs mkfs.vfat mkfs.ext4 sgdisk efibootmgr lsblk blkid genfstab fzf; do
  command -v "$cmd" >/dev/null 2>&1 || _die "missing required command: $cmd"
done
printf '  All required commands present.\n'

# 02 - collect_input: capture every VLARCH_* the rest of the installer needs.

_clear
printf 'Vlarch installer\n\n'

reused=0
if [[ -f "$VLARCH_CONFIG_FILE" ]]; then
  reuse=$(printf 'Use existing config\nStart fresh\n' |
    _fzf --header "Found saved config at ${VLARCH_CONFIG_FILE}" --prompt='> ')
  if [[ "$reuse" == "Use existing config" ]]; then
    vlarch_config_load "$VLARCH_CONFIG_FILE"
    if vlarch_config_validate 2>/dev/null; then
      reused=1
    else
      printf '  saved config is incomplete; starting fresh\n' >&2
    fi
  fi
fi

if ((!reused)); then
  current=$(_detect_network_type)
  if [[ "$current" == "wifi" ]]; then
    VLARCH_NETWORK_TYPE="wifi"
  else
    VLARCH_NETWORK_TYPE=$(printf 'ethernet\nwifi\n' |
      _fzf --header 'Networking' --prompt='> ')
  fi
  if [[ "$VLARCH_NETWORK_TYPE" == "wifi" ]]; then
    read -rp "  WiFi SSID: " VLARCH_WIFI_SSID
    read -rsp "  WiFi password: " VLARCH_WIFI_PASSWORD
    echo
  fi

  VLARCH_TIMEZONE=$(find /usr/share/zoneinfo -type f ! -name '*.tab' ! -name '*.list' |
    sed 's|/usr/share/zoneinfo/||' |
    grep -vE '^(posix|right|Etc|Factory)/|^[A-Z0-9_-]+$' |
    sort |
    _fzf --header 'Timezone' --prompt='> ')
  [[ -n "$VLARCH_TIMEZONE" ]] || _die "no timezone selected"

  VLARCH_LOCALE=$(grep -E '^#?[a-z][a-zA-Z_]+\.UTF-8' /etc/locale.gen |
    sed 's/^# *//' |
    _fzf --query='en_US.UTF-8' --header 'Locale' --prompt='> ' |
    awk '{print $1}')
  [[ -n "$VLARCH_LOCALE" ]] || _die "no locale selected"

  VLARCH_DISK=$(lsblk -dno PATH,SIZE,TYPE,MODEL |
    awk '$3 == "disk" { $3=""; print }' |
    _fzf --header 'Target disk (will be ERASED)' --prompt='> ' |
    awk '{print $1}')
  [[ -n "$VLARCH_DISK" ]] || _die "no disk selected"
  [[ -b "$VLARCH_DISK" ]] || _die "not a block device: $VLARCH_DISK"

  read -rp "Username: " VLARCH_USER
  [[ "$VLARCH_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] ||
    _die "invalid username: $VLARCH_USER"
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

  printf 'Captured configuration:\n'
  printf '  user:        %s (%s)\n' "${VLARCH_USER}" "${VLARCH_REAL_NAME}"
  printf '  network:     %s%s\n' "${VLARCH_NETWORK_TYPE}" "${VLARCH_WIFI_SSID:+ (SSID: ${VLARCH_WIFI_SSID})}"
  printf '  timezone:    %s\n' "${VLARCH_TIMEZONE}"
  printf '  locale:      %s\n' "${VLARCH_LOCALE}"
  printf '  disk:        %s\n' "${VLARCH_DISK}"
  printf '\n'
  read -rp "Press Enter to start the install (will ERASE ${VLARCH_DISK}), or Ctrl-C to abort..." _
fi

_clear
