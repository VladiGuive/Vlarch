#!/usr/bin/env bash
# Run commands in the install user's login shell; quiet unless verbose.

vlarch_run_user() {
  local user="$1" label="$2" cmd="$3"

  if ((VLARCH_VERBOSE)); then
    su - "$user" -c "$cmd" || return 1
    declare -F vlarch_ui_tick >/dev/null 2>&1 && vlarch_ui_tick "$label"
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
  if ((rc == 0)) && declare -F vlarch_ui_tick >/dev/null 2>&1; then
    vlarch_ui_tick "$label"
  fi
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

vlarch_tmux_conf_for_user() {
  local user="$1" home="/home/${user}"

  if [[ -f "${home}/.config/tmux/tmux.conf" ]]; then
    printf '%s/.config/tmux/tmux.conf\n' "$home"
  elif [[ -f "${home}/.tmux.conf" ]]; then
    printf '%s/.tmux.conf\n' "$home"
  else
    return 1
  fi
}

vlarch_sync_tmux_plugins() {
  local user="$1" conf home tpm_install

  command -v tmux >/dev/null 2>&1 || return 1
  conf="$(vlarch_tmux_conf_for_user "$user")" || return 1
  home="/home/${user}"
  tpm_install="${home}/.tmux/plugins/tpm/bin/install_plugins"

  [[ -x "$tpm_install" ]] || return 1
  su - "$user" -c 'tmux list-sessions >/dev/null 2>&1' || return 1

  vlarch_run_user "$user" "tmux source-file" "tmux source-file '${conf}'" || return 1
  vlarch_run_user "$user" "tmux install plugins" "'${tpm_install}'"
}

vlarch_hyprpm_update() {
  local user="$1" attempt cmd='hyprpm update -f'

  for attempt in 1 2; do
    if vlarch_run_user "$user" "hyprpm update (attempt ${attempt})" "$cmd"; then
      return 0
    fi
    ((attempt == 1)) || return 1
    vlarch_info "hyprpm update retrying after dependency refresh"
    pacman -S --noconfirm --needed cmake cpio pkg-config base-devel git hyprland >/dev/null 2>&1 || true
  done
}
