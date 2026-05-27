#!/usr/bin/env bash
# Run commands in the install user's login shell; quiet unless verbose.

vlarch_run_user() {
  local user="$1" label="$2" cmd="$3"

  if ((VLARCH_VERBOSE)); then
    su - "$user" -c "$cmd" || return 1
    return 0
  fi

  local log rc=0
  log="$(vlarch_log_path user)"
  mkdir -p "$(dirname "$log")"
  : >>"$log"
  {
    printf '\n--- vlarch_run_user: %s ---\n' "$label"
    printf 'user: %s\n' "$user"
    printf 'cmd: %s\n' "$cmd"
  } >>"$log"
  su - "$user" -c "$cmd" >>"$log" 2>&1 || rc=$?
  return "$rc"
}

vlarch_hyprland_session_for_user() {
  local user="$1" uid runtime sig
  uid="$(id -u "$user")"
  runtime="/run/user/${uid}"
  [[ -d "${runtime}/hypr" ]] || return 1
  sig="$(find "${runtime}/hypr" -mindepth 1 -maxdepth 1 -printf '%f\n' 2>/dev/null | head -1)"
  [[ -n "$sig" ]]
}

vlarch_hyprland_signature_for_user() {
  local user="$1" uid runtime
  uid="$(id -u "$user")"
  runtime="/run/user/${uid}"
  find "${runtime}/hypr" -mindepth 1 -maxdepth 1 -printf '%f\n' 2>/dev/null | head -1
}

vlarch_reload_tmux_config() {
  local user="$1"
  local conf="/home/${user}/.config/tmux/tmux.conf"

  [[ -f "$conf" ]] || return 1
  command -v tmux >/dev/null 2>&1 || return 1

  vlarch_run_user "$user" "tmux reload" \
    'tmux list-sessions >/dev/null 2>&1 && tmux source-file ~/.config/tmux/tmux.conf'
}
