#!/usr/bin/env bash
# Run commands in the install user's login shell; quiet unless verbose.

vlarch_user_home() {
  printf '/home/%s' "$1"
}

vlarch_user_runtime() {
  printf '/run/user/%s' "$(id -u "$1")"
}

vlarch_run_user() {
  local user="$1" label="$2" cmd="$3"
  local home runtime wrapped

  home="$(vlarch_user_home "$user")"
  runtime="$(vlarch_user_runtime "$user")"
  wrapped="export HOME='${home}' USER='${user}' XDG_RUNTIME_DIR='${runtime}'; ${cmd}"

  if ((VLARCH_VERBOSE)); then
    runuser -u "$user" -- bash -lc "$wrapped" || return 1
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
    printf 'cmd: %s\n' "$wrapped"
  } >>"$log"
  runuser -u "$user" -- bash -lc "$wrapped" >>"$log" 2>&1 || rc=$?
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
  home="$(vlarch_user_home "$user")"
  tpm_install="${home}/.tmux/plugins/tpm/bin/install_plugins"

  [[ -x "$tpm_install" ]] || return 1
  runuser -u "$user" -- bash -lc \
    "export HOME='${home}'; tmux list-sessions >/dev/null 2>&1" || return 1

  vlarch_run_user "$user" "tmux source-file" "tmux source-file '${conf}'" || return 1
  vlarch_run_user "$user" "tmux install plugins" "'${tpm_install}'"
}

vlarch_hyprpm_user_env() {
  local user="$1" home runtime sig
  home="$(vlarch_user_home "$user")"
  runtime="$(vlarch_user_runtime "$user")"
  printf "export HOME='%s' USER='%s' XDG_RUNTIME_DIR='%s'" "$home" "$user" "$runtime"
  sig="$(vlarch_hyprland_signature_for_user "$user" 2>/dev/null || true)"
  if [[ -n "$sig" ]]; then
    printf " HYPRLAND_INSTANCE_SIGNATURE='%s'" "$sig"
  fi
}

vlarch_hyprpm_headers_ok() {
  local user="$1" home
  home="$(vlarch_user_home "$user")"
  [[ -d "${home}/.local/share/hyprpm/headersRoot/include/hyprland" ]]
}

# Headers/plugins refresh; plugin reload also runs via vlarch-hyprpm-sync on Hyprland start.
vlarch_hyprpm_update() {
  local user="$1" env cmd

  command -v hyprpm >/dev/null 2>&1 || return 0

  env="$(vlarch_hyprpm_user_env "$user")"
  cmd="${env}; hyprpm update -f"

  if vlarch_run_user "$user" "hyprpm update" "$cmd"; then
    return 0
  fi

  if declare -F vlarch_warn >/dev/null 2>&1; then
    vlarch_warn "hyprpm update failed; purging cache and retrying"
  fi
  vlarch_run_user "$user" "hyprpm purge-cache" "${env}; hyprpm purge-cache" || true
  cmd="${env}; hyprpm update -fv"
  if vlarch_run_user "$user" "hyprpm update retry" "$cmd"; then
    return 0
  fi

  if vlarch_hyprpm_headers_ok "$user"; then
    if declare -F vlarch_warn >/dev/null 2>&1; then
      vlarch_warn "hyprpm could not reload plugins (Hyprland offline); headers present"
    fi
    return 0
  fi

  return 1
}
