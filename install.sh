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
    read -rsp "$prompt: " first </dev/tty
    printf '\n' >&2
    read -rsp "$prompt (again): " second </dev/tty
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

# ---- partition helpers (migrated from install/lib/partition.sh) ----

# Partition + LUKS + btrfs layout (fixed):
#   p1  512 MiB  EFI  (vfat)
#   p2    1 GiB  /boot (ext4, unencrypted - GRUB needs it readable)
#   p3   rest    LUKS1 -> btrfs subvolumes @, @home, @snapshots, @var_log, @swap

vlarch_partition_part_path() {
  local disk="$1" idx="$2"
  if [[ "$disk" == /dev/nvme* || "$disk" == /dev/loop* || "$disk" == /dev/mmcblk* ]]; then
    printf '%sp%s' "$disk" "$idx"
  else
    printf '%s%s' "$disk" "$idx"
  fi
}

vlarch_partition_default_swap_size_mib() {
  local ram_mib
  ram_mib=$(awk '/^MemTotal:/ {print int($2/1024)}' /proc/meminfo)
  printf '%s' $((ram_mib + 2048))
}

# Quietly close any prior cryptroot / mounts / swap from a previous attempt.
_vlarch_partition_reset() {
  swapoff -a >/dev/null 2>&1 || true
  umount -R /mnt >/dev/null 2>&1 || true
  cryptsetup close cryptroot >/dev/null 2>&1 || true
}

# Erase, partition, encrypt, format the target disk in `VLARCH_DISK`.
# Exports VLARCH_PART_EFI / VLARCH_PART_BOOT / VLARCH_PART_LUKS / VLARCH_LUKS_UUID.
vlarch_partition_apply() {
  local disk="$1"
  [[ -b "$disk" ]] || _die "not a block device: $disk"
  [[ -n "${VLARCH_LUKS_PASSPHRASE:-}" ]] || _die "VLARCH_LUKS_PASSPHRASE not set"

  printf '  Erasing %s...\n' "$disk"
  _vlarch_partition_reset
  vlarch_live_run "wipefs ${disk}" wipefs -af "$disk"
  vlarch_live_run "sgdisk zap ${disk}" sgdisk --zap-all "$disk"
  printf '  Creating partition layout...\n'
  vlarch_live_run "sgdisk layout ${disk}" \
    sgdisk \
      -n1:0:+512M -t1:ef00 -c1:VLARCH_EFI \
      -n2:0:+1G   -t2:8300 -c2:VLARCH_BOOT \
      -n3:0:0     -t3:8309 -c3:VLARCH_LUKS \
      "$disk"
  vlarch_live_run "partprobe ${disk}" partprobe "$disk"
  sleep 1

  local p1 p2 p3
  p1="$(vlarch_partition_part_path "$disk" 1)"
  p2="$(vlarch_partition_part_path "$disk" 2)"
  p3="$(vlarch_partition_part_path "$disk" 3)"

  printf '  Formatting EFI and /boot...\n'
  vlarch_live_run "mkfs.vfat ${p1}" mkfs.vfat -F32 -n VLARCH_EFI "$p1"
  vlarch_live_run "mkfs.ext4 ${p2}" mkfs.ext4 -F -L VLARCH_BOOT "$p2"
  printf '  EFI and /boot formatted.\n'

  # luksFormat reads the passphrase from stdin, so it can't use vlarch_live_run.
  printf '  Encrypting with LUKS...\n'
  if ! printf '%s' "$VLARCH_LUKS_PASSPHRASE" \
       | cryptsetup --type luks1 --batch-mode -v luksFormat "$p3" --key-file - \
         >>"$VLARCH_BOOTSTRAP_LOG" 2>&1; then
    _die "cryptsetup luksFormat ${p3} failed"
  fi
  if ! printf '%s' "$VLARCH_LUKS_PASSPHRASE" \
       | cryptsetup open "$p3" cryptroot --key-file - >>"$VLARCH_BOOTSTRAP_LOG" 2>&1; then
    _die "cryptsetup open ${p3} failed"
  fi
  printf '  LUKS encryption ready.\n'

  printf '  Creating btrfs subvolumes...\n'
  vlarch_live_run "mkfs.btrfs cryptroot" mkfs.btrfs -f -L VLARCH_ROOT /dev/mapper/cryptroot
  vlarch_live_run "mount cryptroot top" mount /dev/mapper/cryptroot /mnt
  vlarch_live_run "btrfs subvolume create @"          btrfs subvolume create /mnt/@
  vlarch_live_run "btrfs subvolume create @home"      btrfs subvolume create /mnt/@home
  vlarch_live_run "btrfs subvolume create @snapshots" btrfs subvolume create /mnt/@snapshots
  vlarch_live_run "btrfs subvolume create @var_log"   btrfs subvolume create /mnt/@var_log
  vlarch_live_run "btrfs subvolume create @swap"      btrfs subvolume create /mnt/@swap
  vlarch_live_run "umount cryptroot top" umount /mnt
  printf '  Subvolumes created.\n'

  local luks_uuid
  luks_uuid=$(blkid -s UUID -o value "$p3")
  [[ -n "$luks_uuid" ]] || _die "could not read LUKS UUID for $p3"

  VLARCH_PART_EFI="$p1"
  VLARCH_PART_BOOT="$p2"
  VLARCH_PART_LUKS="$p3"
  VLARCH_LUKS_UUID="$luks_uuid"
  export VLARCH_PART_EFI VLARCH_PART_BOOT VLARCH_PART_LUKS VLARCH_LUKS_UUID
}

# Mount every subvolume + EFI + /boot at /mnt and create the swapfile.
vlarch_partition_mount() {
  [[ -n "${VLARCH_PART_EFI:-}"  ]] || _die "VLARCH_PART_EFI not set"
  [[ -n "${VLARCH_PART_BOOT:-}" ]] || _die "VLARCH_PART_BOOT not set"
  [[ -e /dev/mapper/cryptroot ]] || _die "cryptroot is not open"

  local opts="rw,noatime,compress=zstd:3,space_cache=v2"

  printf '  Mounting filesystems...\n'
  vlarch_live_run "mount @"          mount -o "${opts},subvol=@"          /dev/mapper/cryptroot /mnt
  mkdir -p /mnt/{home,.snapshots,var/log,swap,boot,boot/EFI}
  vlarch_live_run "mount @home"      mount -o "${opts},subvol=@home"      /dev/mapper/cryptroot /mnt/home
  vlarch_live_run "mount @snapshots" mount -o "${opts},subvol=@snapshots" /dev/mapper/cryptroot /mnt/.snapshots
  vlarch_live_run "mount @var_log"   mount -o "${opts},subvol=@var_log"   /dev/mapper/cryptroot /mnt/var/log
  # Swap subvolume must not be compressed/CoW.
  vlarch_live_run "mount @swap"      mount -o "rw,noatime,subvol=@swap"   /dev/mapper/cryptroot /mnt/swap

  vlarch_live_run "mount /boot"      mount "${VLARCH_PART_BOOT}" /mnt/boot
  mkdir -p /mnt/boot/EFI
  vlarch_live_run "mount /boot/EFI"  mount "${VLARCH_PART_EFI}"  /mnt/boot/EFI

  printf '  Creating swapfile...\n'
  local swapfile="/mnt/swap/swapfile"
  if [[ ! -f "$swapfile" ]]; then
    local size_mib
    size_mib=$(vlarch_partition_default_swap_size_mib)
    chattr +C /mnt/swap >/dev/null 2>&1 || true
    if ! btrfs filesystem mkswapfile --size "${size_mib}m" "$swapfile" >/dev/null 2>&1; then
      vlarch_live_run "fallocate swapfile" truncate -s 0 "$swapfile"
      chattr +C "$swapfile" >/dev/null 2>&1 || true
      vlarch_live_run "fallocate ${size_mib}M swapfile" fallocate -l "${size_mib}M" "$swapfile"
      chmod 600 "$swapfile"
      vlarch_live_run "mkswap" mkswap "$swapfile"
    fi
  fi
  swapon "$swapfile" >/dev/null 2>&1 || true
  printf '  Swap ready.\n'
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

printf '  Refreshing mirrors (this one takes a while)...\n'
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

# NOTE: do NOT `exec </dev/tty` here — bash reads this script from the curl
# pipe in chunks; redirecting fd 0 mid-script loses the unread tail and the
# install hangs waiting for the rest of the script on /dev/tty. Every
# interactive `read` below redirects its own stdin to /dev/tty instead.
trap 'exit 130' INT

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
    read -rp "  WiFi SSID: " VLARCH_WIFI_SSID </dev/tty
    read -rsp "  WiFi password: " VLARCH_WIFI_PASSWORD </dev/tty
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

  read -rp "Username: " VLARCH_USER </dev/tty
  [[ "$VLARCH_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] ||
    _die "invalid username: $VLARCH_USER"
  read -rp "Real name: " VLARCH_REAL_NAME </dev/tty
  read -rp "Email: " VLARCH_USER_EMAIL </dev/tty

  VLARCH_USER_PASSWORD=$(_read_password_twice "Password for $VLARCH_USER")
  VLARCH_ROOT_PASSWORD=$(_read_password_twice "Password for root user")
  VLARCH_LUKS_PASSPHRASE=$(_read_password_twice "Password for disk encryption (asked at every boot)")

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
  read -rp "Press Enter to start the install (will ERASE ${VLARCH_DISK}), or Ctrl-C to abort..." _ </dev/tty
fi

_clear

# 03 - partition: erase, partition, encrypt, format, mount the target disk.

printf 'Partitioning %s...\n' "$VLARCH_DISK"
vlarch_config_load "$VLARCH_CONFIG_FILE"
vlarch_config_validate
vlarch_partition_apply "$VLARCH_DISK"
vlarch_partition_mount
vlarch_config_save "$VLARCH_CONFIG_FILE"
printf 'Partitioning complete.\n'

_clear

# 04 - software: pacstrap the base, then every system package + the AUR stack
# one at a time with a Package n/m counter.

printf 'Installing base system...\n'
mountpoint -q /mnt || _die "/mnt is not mounted; run step 03 first"

vlarch_live_refresh_mirrors
vlarch_live_sync_keyring

printf '  Installing base...\n'
if ! pacstrap -K /mnt base >>"$VLARCH_BOOTSTRAP_LOG" 2>&1; then
  _die "pacstrap failed"
fi
printf '  Base installed.\n'

if ! genfstab -U /mnt >>/mnt/etc/fstab 2>>"$VLARCH_BOOTSTRAP_LOG"; then
  _die "genfstab failed"
fi
if [[ -f /etc/resolv.conf ]]; then
  cp -L /etc/resolv.conf /mnt/etc/resolv.conf
fi

# Every explicit package, one at a time, with a global progress counter.
BASE_EXTRA=(base-devel linux linux-firmware btrfs-progs grub efibootmgr
  networkmanager git curl sudo zsh rsync)
mapfile -t PACMAN_PKGS < <(grep -vE '^[[:space:]]*#|^[[:space:]]*$' "${VLARCH_SCRIPT_DIR}/pacman.txt")
mapfile -t AUR_PKGS < <(grep -vE '^[[:space:]]*#|^[[:space:]]*$' "${VLARCH_SCRIPT_DIR}/aur.txt")
total=$(( ${#BASE_EXTRA[@]} + ${#PACMAN_PKGS[@]} + ${#AUR_PKGS[@]} ))
n=0

for pkg in "${BASE_EXTRA[@]}" "${PACMAN_PKGS[@]}"; do
  n=$((n + 1))
  _clear
  printf 'Package %d/%d\n' "$n" "$total"
  printf '  %s...\n' "$pkg"
  arch-chroot /mnt pacman -S --noconfirm --needed "$pkg" >>"$VLARCH_BOOTSTRAP_LOG" 2>&1 ||
    _die "pacman -S ${pkg} failed"
done

# yay needs a real user (makepkg refuses to run as root).
printf '  Creating user %s...\n' "$VLARCH_USER"
user_shell=/bin/bash
[[ -x /mnt/usr/bin/zsh ]] && user_shell=/usr/bin/zsh
printf '%s\n' "root:${VLARCH_ROOT_PASSWORD}" | arch-chroot /mnt chpasswd
if ! arch-chroot /mnt id "$VLARCH_USER" >/dev/null 2>&1; then
  arch-chroot /mnt useradd -m -G wheel -c "${VLARCH_REAL_NAME}" -s "$user_shell" "$VLARCH_USER"
fi
printf '%s\n' "${VLARCH_USER}:${VLARCH_USER_PASSWORD}" | arch-chroot /mnt chpasswd
install -m 0440 /dev/stdin /mnt/etc/sudoers.d/wheel <<SUDOERS
%wheel ALL=(ALL:ALL) NOPASSWD: ALL
SUDOERS
arch-chroot /mnt visudo -c -f /etc/sudoers.d/wheel >/dev/null

printf '  Bootstrapping yay...\n'
arch-chroot /mnt env "VLARCH_USER=${VLARCH_USER}" bash -s <<'YAY'
set -euo pipefail
if ! command -v yay >/dev/null 2>&1; then
  build_dir="$(mktemp -d)"
  chown "${VLARCH_USER}:${VLARCH_USER}" "$build_dir"
  trap 'rm -rf "$build_dir"' EXIT
  su - "${VLARCH_USER}" -c "
    set -euo pipefail
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git \"${build_dir}\"
    cd \"${build_dir}\"
    makepkg -si --noconfirm
  "
fi
YAY

for pkg in "${AUR_PKGS[@]}"; do
  n=$((n + 1))
  _clear
  printf 'Package %d/%d\n' "$n" "$total"
  printf '  %s...\n' "$pkg"
  arch-chroot /mnt su - "$VLARCH_USER" -c "yay -S --noconfirm --needed '$pkg'" >>"$VLARCH_BOOTSTRAP_LOG" 2>&1 ||
    _die "yay -S ${pkg} failed"
done

# plymouth (AUR) depends on systemd, which stays as the init system.
missing=()
for pkg in base "${BASE_EXTRA[@]}" "${PACMAN_PKGS[@]}" "${AUR_PKGS[@]}"; do
  if ! arch-chroot /mnt pacman -Q "$pkg" >/dev/null 2>&1; then
    missing+=("$pkg")
  fi
done
((${#missing[@]} == 0)) || _die "packages missing: ${missing[*]}"
printf '  All packages present.\n'

_clear

# 05 - system: timezone, locale, hostname inside /mnt.

printf 'Configuring system...\n'
arch-chroot /mnt env \
  "VLARCH_TIMEZONE=${VLARCH_TIMEZONE}" \
  "VLARCH_LOCALE=${VLARCH_LOCALE}" \
  bash -s <<'SYS'
set -euo pipefail

printf '  Timezone...\n'
ln -sf "/usr/share/zoneinfo/${VLARCH_TIMEZONE}" /etc/localtime
hwclock --systohc

printf '  Locale...\n'
if ! grep -qE "^${VLARCH_LOCALE} UTF-8" /etc/locale.gen; then
  if grep -qE "^#${VLARCH_LOCALE} UTF-8" /etc/locale.gen; then
    sed -i "s/^#\(${VLARCH_LOCALE} UTF-8\)/\1/" /etc/locale.gen
  else
    echo "${VLARCH_LOCALE} UTF-8" >>/etc/locale.gen
  fi
fi
locale-gen
echo "LANG=${VLARCH_LOCALE}" >/etc/locale.conf

printf '  Hostname...\n'
echo "vlarch" >/etc/hostname
cat >/etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   vlarch.localdomain vlarch
HOSTS
SYS
printf '  System configured.\n'

_clear

# 06 - users: autologin for the install user.

printf 'Setting up autologin...\n'
arch-chroot /mnt env "VLARCH_USER=${VLARCH_USER}" bash -s <<'USERS'
set -euo pipefail
# systemd drop-in: autologin on tty1.
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat >/etc/systemd/system/getty@tty1.service.d/autologin.conf <<UNIT
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${VLARCH_USER} --noclear %I \$TERM
UNIT
USERS
printf '  Autologin ready.\n'

_clear

# 07 - boot: plymouth + LUKS initramfs, GRUB, services.

printf 'Setting up boot...\n'
arch-chroot /mnt env "VLARCH_LUKS_UUID=${VLARCH_LUKS_UUID}" bash -s <<'BOOT'
set -euo pipefail

printf '  Building initramfs...\n'
# plymouth draws the LUKS passphrase prompt (no console text); the
# plymouth-encrypt hook replaces plain encrypt.
sed -i -E "s/^HOOKS=.*/HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block plymouth plymouth-encrypt filesystems fsck)/" /etc/mkinitcpio.conf
mkinitcpio -P

printf '  Installing GRUB...\n'
cmdline="cryptdevice=UUID=${VLARCH_LUKS_UUID}:cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ quiet splash"
if grep -q "^GRUB_ENABLE_CRYPTODISK=" /etc/default/grub; then
  sed -i "s|^GRUB_ENABLE_CRYPTODISK=.*|GRUB_ENABLE_CRYPTODISK=y|" /etc/default/grub
else
  echo "GRUB_ENABLE_CRYPTODISK=y" >>/etc/default/grub
fi
if grep -q "^GRUB_CMDLINE_LINUX=" /etc/default/grub; then
  sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"${cmdline}\"|" /etc/default/grub
else
  echo "GRUB_CMDLINE_LINUX=\"${cmdline}\"" >>/etc/default/grub
fi
mount -t efivarfs efivarfs /sys/firmware/efi/efivars 2>/dev/null || true
grub-install --target=x86_64-efi --efi-directory=/boot/EFI --bootloader-id=Vlarch
grub-mkconfig -o /boot/grub/grub.cfg

printf '  Enabling services...\n'
# swapfile entry (genfstab does not emit it).
grep -q '^/swap/swapfile' /etc/fstab || echo '/swap/swapfile none swap defaults 0 0' >>/etc/fstab
systemctl enable NetworkManager.service
systemctl enable plymouth-start.service
BOOT
printf '  Boot ready.\n'

_clear

# 09 - dotfiles: minimal seed - fastfetch config as a first-boot sanity check.

printf 'Seeding dotfiles...\n'
ff_src="${VLARCH_SCRIPT_DIR}/dotfiles/.config/fastfetch/config.jsonc"
[[ -f "$ff_src" ]] || _die "missing fastfetch config: $ff_src"
install -Dm0644 -o "${VLARCH_USER}" -g "${VLARCH_USER}" \
  "$ff_src" "/mnt/home/${VLARCH_USER}/.config/fastfetch/config.jsonc"
printf '  fastfetch config deployed.\n'

_clear

# 10 - finalize: vlarch bins, install-info, wallpaper, first-boot marker.

printf 'Finalizing install...\n'
mountpoint -q /mnt || _die "/mnt not mounted; cannot finalize install"

for script in "${VLARCH_SCRIPT_DIR}"/bin/*; do
  install -Dm0755 "$script" "/mnt/usr/local/bin/$(basename "$script")"
done

mkdir -p /mnt/etc/vlarch /mnt/var/lib/vlarch
{
  printf 'installed_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'user=%s\n'         "${VLARCH_USER}"
  printf 'disk=%s\n'         "${VLARCH_DISK}"
  printf 'timezone=%s\n'     "${VLARCH_TIMEZONE}"
  printf 'locale=%s\n'       "${VLARCH_LOCALE}"
  printf 'branch=%s\n'       "${VLARCH_GIT_BRANCH:-main}"
} >/mnt/etc/vlarch/install-info

# Persist non-secret runtime hints for post-install (WiFi join, etc).
{
  if [[ -n "${VLARCH_WIFI_SSID:-}" ]]; then
    printf 'VLARCH_WIFI_SSID=%q\n' "${VLARCH_WIFI_SSID}"
    printf 'VLARCH_WIFI_PASSWORD=%q\n' "${VLARCH_WIFI_PASSWORD:-}"
  fi
} >/mnt/var/lib/vlarch/runtime.env
chmod 600 /mnt/var/lib/vlarch/runtime.env

# First-login marker (consumed by a future first-boot hook).
: >/mnt/var/lib/vlarch/first-boot.pending
printf '  Install complete.\n'

_clear

# Unmount everything so the user can reboot or re-run the installer cleanly.
printf 'Unmounting...\n'
swapoff -a >/dev/null 2>&1 || true
umount -R /mnt >/dev/null 2>&1 || true
cryptsetup close cryptroot >/dev/null 2>&1 || true
printf '  Done. Reboot into the installed system.\n'
