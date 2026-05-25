#!/usr/bin/env bash
# Live-ISO helpers: cowspace expansion, pacman keyring, mirrors, disk space.
# Public: vlarch_live_ensure_cowspace, vlarch_live_assert_disk_space,
#         vlarch_live_ensure_keyring, vlarch_live_refresh_mirrors

VLARCH_LIVE_MIN_FREE_K="${VLARCH_LIVE_MIN_FREE_K:-524288}"

vlarch_live_path_free_k() {
  df -k "$1" | awk 'NR==2 {print $4}'
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
      vlarch_run "expand cowspace to ${target}" \
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
      vlarch_die "low disk space on ${path} ($((avail_k / 1024)) MiB free; need >= $((VLARCH_LIVE_MIN_FREE_K / 1024)) MiB)"
    fi
  done
}

# Initialize/repair the live-ISO pacman keyring if needed.
vlarch_live_ensure_keyring() {
  local gpg_dir="/etc/pacman.d/gnupg"
  local healthy=1

  command -v pacman-key >/dev/null 2>&1 || vlarch_die "pacman-key missing on live ISO"

  if [[ ! -d "$gpg_dir" ]]; then
    healthy=0
  elif ! pacman-key -l >/dev/null 2>&1; then
    healthy=0
  elif ! pacman-key -l 2>/dev/null | grep -q 'Arch Linux'; then
    healthy=0
  fi

  ((healthy)) && return 0

  vlarch_run "pacman-key --init"               pacman-key --init
  vlarch_run "pacman-key --populate archlinux" pacman-key --populate archlinux

  pacman-key -l >/dev/null 2>&1 \
    || vlarch_die "pacman keyring still unhealthy after --init/--populate"
}

vlarch_live_refresh_mirrors() {
  if command -v reflector >/dev/null 2>&1; then
    vlarch_run "reflector mirrorlist refresh" \
      reflector -f 30 --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
  fi
  [[ -s /etc/pacman.d/mirrorlist ]] || vlarch_die "/etc/pacman.d/mirrorlist is empty"
  grep -q '^[[:space:]]*Server[[:space:]]*=' /etc/pacman.d/mirrorlist \
    || vlarch_die "/etc/pacman.d/mirrorlist has no Server entries"
}
