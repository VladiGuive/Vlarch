#!/usr/bin/env bash
# Live-ISO helpers: cowspace expansion, pacman keyring, mirrors, disk space.
# Bootstrap-compatible: uses _die() and $VLARCH_BOOTSTRAP_LOG (the same
# contract as install.sh / update.sh bootstrap) — no dependency on log.sh.
# Public: vlarch_live_ensure_cowspace, vlarch_live_assert_disk_space,
#         vlarch_live_ensure_keyring, vlarch_live_sync_keyring,
#         vlarch_live_refresh_mirrors

VLARCH_LIVE_MIN_FREE_K="${VLARCH_LIVE_MIN_FREE_K:-524288}"
VLARCH_BOOTSTRAP_LOG="${VLARCH_BOOTSTRAP_LOG:-/var/log/vlarch_install.log}"

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

  vlarch_live_run "pacman-key --init"               pacman-key --init
  vlarch_live_run "pacman-key --populate archlinux" pacman-key --populate archlinux

  pacman-key -l >/dev/null 2>&1 \
    || _die "pacman keyring still unhealthy after --init/--populate"
}

# Pull the current archlinux-keyring from mirrors and refresh packager trust.
# Live ISOs ship a stale keyring; without this, pacstrap fails with "unknown trust".
vlarch_live_sync_keyring() {
  command -v pacman-key >/dev/null 2>&1 || _die "pacman-key missing on live ISO"
  [[ -s /etc/pacman.d/mirrorlist ]] \
    || _die "mirrorlist empty; run vlarch_live_refresh_mirrors first"

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
  grep -q '^[[:space:]]*Server[[:space:]]*=' /etc/pacman.d/mirrorlist \
    || _die "/etc/pacman.d/mirrorlist has no Server entries"
}
