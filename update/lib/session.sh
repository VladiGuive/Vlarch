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

vlarch_tmux_plugins_from_conf() {
  local conf="$1"
  grep -E '^[[:space:]]*set -g @plugin' "$conf" \
    | sed -n "s/.*@plugin ['\"]\([^'\"]*\)['\"].*/\1/p"
}

vlarch_ensure_tmux_tpm() {
  local user="$1" home="/home/${user}"
  local tpm_dir="${home}/.tmux/plugins/tpm"

  install -d -o "$user" -g "$user" "${home}/.tmux/plugins"
  [[ -d "${tpm_dir}/.git" ]] && return 0

  vlarch_run_user "$user" "tmux tpm clone" \
    "git clone --depth 1 https://github.com/tmux-plugins/tpm.git '${tpm_dir}'"
}

vlarch_clone_tmux_plugins() {
  local user="$1" conf="$2" home="/home/${user}"
  local repo name plugin_dir

  while IFS= read -r repo; do
    [[ -n "$repo" ]] || continue
    [[ "$repo" == tmux-plugins/tpm ]] && continue
    name="${repo##*/}"
    plugin_dir="${home}/.tmux/plugins/${name}"
    [[ -d "${plugin_dir}/.git" ]] && continue
    install -d -o "$user" -g "$user" "${home}/.tmux/plugins"
    vlarch_run_user "$user" "tmux plugin ${name}" \
      "git clone --depth 1 'https://github.com/${repo}.git' '${plugin_dir}'" \
      || true
  done < <(vlarch_tmux_plugins_from_conf "$conf")
}

# Bootstrap TPM and plugins on update — no manual source or prefix+I.
vlarch_sync_tmux_plugins() {
  local user="$1" conf home tpm_bin update_bin

  command -v tmux >/dev/null 2>&1 || return 1
  conf="$(vlarch_tmux_conf_for_user "$user")" || return 1
  home="/home/${user}"
  tpm_bin="${home}/.tmux/plugins/tpm/bin/install_plugins"
  update_bin="${home}/.tmux/plugins/tpm/bin/update_plugins"

  vlarch_ensure_tmux_tpm "$user" || return 1
  vlarch_clone_tmux_plugins "$user" "$conf"

  if su - "$user" -c 'tmux list-sessions >/dev/null 2>&1'; then
    vlarch_run_user "$user" "tmux source-file" "tmux source-file '${conf}'" || true
    [[ -x "$tpm_bin" ]] && vlarch_run_user "$user" "tmux plugins install" "'${tpm_bin}'" || true
    [[ -x "$update_bin" ]] && vlarch_run_user "$user" "tmux plugins update" "'${update_bin}'" || true
  fi

  return 0
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
