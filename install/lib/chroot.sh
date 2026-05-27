#!/usr/bin/env bash
# arch-chroot wrapper that exports the captured VLARCH_* env into the chroot
# and behaves silently in quiet mode (capturing chroot output to a per-step log
# and dumping the tail via vlarch_die on failure).
# Public: vlarch_chroot_run "<bash script body>"

vlarch_chroot_run() {
  local script="$1"
  [[ -d /mnt ]] || vlarch_die "/mnt not mounted"
  command -v arch-chroot >/dev/null 2>&1 || vlarch_die "arch-chroot missing"

  # Shovel every loaded VLARCH_* var into `arch-chroot env … bash` so the
  # chroot script can read them without further plumbing.
  local key vars=()
  while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    vars+=("${key}=${!key-}")
  done < <(compgen -v | grep '^VLARCH_' || true)

  if ((VLARCH_VERBOSE)); then
    arch-chroot /mnt env "${vars[@]}" bash -s <<<"$script"
    return $?
  fi

  local log
  log="$(vlarch_log_path chroot)"
  mkdir -p "$(dirname "$log")"
  : >>"$log"
  {
    printf '\n--- vlarch_chroot_run (step=%s) ---\n' "${VLARCH_CURRENT_STEP:-unknown}"
  } >>"$log"

  local rc=0
  arch-chroot /mnt env "${vars[@]}" bash -s >>"$log" 2>&1 <<<"$script" || rc=$?
  if ((rc != 0)); then
    VLARCH_LAST_LOG="$log"
    vlarch_die "chroot script failed in ${VLARCH_CURRENT_STEP:-unknown} (exit ${rc})"
  fi
  if declare -F vlarch_ui_tick >/dev/null 2>&1; then
    vlarch_ui_tick "chroot: ${VLARCH_CURRENT_STEP:-unknown}"
  fi
  return 0
}
