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

vlarch_ensure_tpm() {
  local user="$1" home tpm_dir
  home="$(vlarch_user_home "$user")"
  tpm_dir="${home}/.tmux/plugins/tpm"

  if [[ -x "${tpm_dir}/bin/install_plugins" ]]; then
    return 0
  fi

  command -v git >/dev/null 2>&1 \
    || vlarch_die "tmux TPM: git is required to install tmux-plugins/tpm"

  # Remove a broken or partial checkout from a previous failed run.
  if [[ -e "$tpm_dir" ]]; then
    vlarch_run_user "$user" "tmux tpm reset" "rm -rf '${tpm_dir}'" \
      || vlarch_die "tmux TPM: could not reset ${tpm_dir}"
  fi

  vlarch_run_user "$user" "tmux tpm clone" \
    "mkdir -p '${home}/.tmux/plugins' && git clone --depth 1 https://github.com/tmux-plugins/tpm.git '${tpm_dir}'" \
    || vlarch_die "tmux TPM: git clone https://github.com/tmux-plugins/tpm.git failed"

  [[ -x "${tpm_dir}/bin/install_plugins" ]] \
    || vlarch_die "tmux TPM: ${tpm_dir}/bin/install_plugins missing after clone"

  return 0
}

vlarch_tmux_server_socket() {
  local user="$1" uid
  uid="$(id -u "$user")"
  printf '/tmp/tmux-%s/default' "$uid"
}

vlarch_reload_tmux_config() {
  local user="$1" conf sock

  command -v tmux >/dev/null 2>&1 || return 0
  conf="$(vlarch_tmux_conf_for_user "$user")" || return 0
  sock="$(vlarch_tmux_server_socket "$user")"
  [[ -S "$sock" ]] || return 0

  vlarch_run_user "$user" "tmux reload config" \
    "tmux source-file '${conf}' && tmux refresh-client -a" || true
  return 0
}

vlarch_sync_tmux_plugins() {
  local user="$1" conf home tpm_install plugins_dir

  command -v tmux >/dev/null 2>&1 || return 1
  conf="$(vlarch_tmux_conf_for_user "$user")" || return 1
  home="$(vlarch_user_home "$user")"
  plugins_dir="${home}/.tmux/plugins"
  tpm_install="${plugins_dir}/tpm/bin/install_plugins"

  vlarch_ensure_tpm "$user"

  # TPM install_plugins does not require a running tmux server (see tpm bin/install_plugins).
  vlarch_run_user "$user" "tmux install plugins" \
    "export TMUX_PLUGIN_MANAGER_PATH='${plugins_dir}'; '${tpm_install}'" || return 1

  vlarch_reload_tmux_config "$user"
  return 0
}

vlarch_regenerate_active_theme() {
  local user="$1" home active theme_bin
  home="$(vlarch_user_home "$user")"
  [[ -f "${home}/.config/vlarch/active-theme" ]] || return 0
  active="$(<"${home}/.config/vlarch/active-theme")"
  [[ -f "$active" ]] || return 0

  if [[ -x /usr/local/bin/vlarch-theme-generate ]]; then
    theme_bin=/usr/local/bin/vlarch-theme-generate
  elif [[ -n "${VLARCH_BIN_DIR:-}" && -x "${VLARCH_BIN_DIR}/vlarch-theme-generate" ]]; then
    theme_bin="${VLARCH_BIN_DIR}/vlarch-theme-generate"
  else
    return 0
  fi

  vlarch_run_user "$user" "regenerate active theme" "'${theme_bin}'" || return 1
  return 0
}

vlarch_restart_walker_if_session() {
  local user="$1"
  command -v vlarch-walker-services >/dev/null 2>&1 || return 0
  vlarch_hyprland_session_for_user "$user" || return 0
  vlarch_run_user "$user" "restart walker service" "vlarch-walker-services" || true
  return 0
}

vlarch_verify_desktop_readiness() {
  local user="$1" home plugin_count
  home="$(vlarch_user_home "$user")"

  command -v Hyprland >/dev/null 2>&1 \
    || vlarch_die "desktop readiness: Hyprland not installed"
  command -v tmux >/dev/null 2>&1 \
    || vlarch_die "desktop readiness: tmux not installed"
  command -v kitty >/dev/null 2>&1 \
    || vlarch_die "desktop readiness: kitty not installed"
  command -v waybar >/dev/null 2>&1 \
    || vlarch_die "desktop readiness: waybar not installed"

  vlarch_ensure_tpm "$user"

  plugin_count="$(find "${home}/.tmux/plugins" -mindepth 1 -maxdepth 1 -type d ! -name tpm 2>/dev/null | wc -l)"
  ((plugin_count > 0)) \
    || vlarch_die "desktop readiness: no tmux plugins under ${home}/.tmux/plugins"
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
