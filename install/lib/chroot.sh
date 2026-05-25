#!/usr/bin/env bash
# arch-chroot wrapper that exports the captured VLARCH_* env into the chroot.
# Public: vlarch_chroot_run "<bash script body>"

# Shovel every loaded VLARCH_* var into `arch-chroot env … bash` so the chroot
# script can read them without further plumbing. Quoting is preserved by env.
vlarch_chroot_run() {
  local script="$1"
  [[ -d /mnt ]] || vlarch_die "/mnt not mounted"
  command -v arch-chroot >/dev/null 2>&1 || vlarch_die "arch-chroot missing"

  local key vars=()
  while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    vars+=("${key}=${!key-}")
  done < <(compgen -v | grep '^VLARCH_' || true)

  arch-chroot /mnt env "${vars[@]}" bash -s <<<"$script"
}
