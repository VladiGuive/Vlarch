#!/usr/bin/env bash
# Dotfile deploy helpers. Sourced - no set -e here.
# Syncs only repo-managed paths; never mirrors or deletes all of ~/.config.

vlarch_user_active_theme() {
  local user="$1" home="/home/${user}" active
  if [[ -f "${home}/.config/vlarch/active-theme" ]]; then
    active="$(<"${home}/.config/vlarch/active-theme")"
    if [[ -f "$active" ]]; then
      printf '%s' "$active"
      return 0
    fi
  fi
  if [[ -f "${home}/.config/themes/nord.json" ]]; then
    printf '%s/.config/themes/nord.json' "$home"
    return 0
  fi
  return 1
}

vlarch_theme_generate_bin() {
  local bin="${VLARCH_BIN_DIR:-}/vlarch-theme-generate"
  if [[ -n "${VLARCH_BIN_DIR:-}" && -x "$bin" ]]; then
    printf '%s' "$bin"
    return 0
  fi
  if [[ -x /usr/local/bin/vlarch-theme-generate ]]; then
    printf '%s' /usr/local/bin/vlarch-theme-generate
    return 0
  fi
  return 1
}

vlarch_theme_generate_staged() {
  local theme_file="$1" output_root="$2"
  local theme_bin

  theme_bin="$(vlarch_theme_generate_bin)" || return 1
  if ! "$theme_bin" --help 2>&1 | grep -q -- '--output'; then
    if declare -F vlarch_die >/dev/null 2>&1; then
      vlarch_die "vlarch-theme-generate is too old for staged dotfiles (missing --output); update vlarch first"
    fi
    return 1
  fi
  "$theme_bin" --output "$output_root" --no-refresh --no-persist "$theme_file"
}

# Copy repo dotfiles, bake the user's active theme and ~/.overrides, return staging dir.
vlarch_prepare_dotfiles_staging() {
  local user="$1" src_dir="$2"
  local stage home theme

  [[ -d "$src_dir" ]] || return 1
  home="/home/${user}"
  [[ -d "$home" ]] || return 1

  stage="$(mktemp -d /tmp/vlarch-dotfiles-stage.XXXXXX)"
  rsync -a "${src_dir}/" "${stage}/"

  theme="$(vlarch_user_active_theme "$user" 2>/dev/null || true)"
  if [[ -z "$theme" && -f "${stage}/.config/themes/nord.json" ]]; then
    theme="${stage}/.config/themes/nord.json"
  fi

  if [[ -n "$theme" ]]; then
    vlarch_theme_generate_staged "$theme" "${stage}/.config" \
      || return 1
  fi

  if declare -F vlarch_apply_overrides_at_root >/dev/null 2>&1; then
    vlarch_apply_overrides_at_root "$user" "$stage"
  fi

  printf '%s' "$stage"
}

vlarch_run_prepare_dotfiles_staging() {
  local user="$1" src_dir="$2"
  VLARCH_DOTFILES_STAGE="$(vlarch_prepare_dotfiles_staging "$user" "$src_dir")"
  [[ -n "$VLARCH_DOTFILES_STAGE" && -d "$VLARCH_DOTFILES_STAGE" ]]
}

vlarch_deploy_dotfiles() {
  local user="$1"
  local src_dir="$2"
  local home="/home/${user}"
  local rel entry base

  [[ -d "$src_dir" ]] || return 1
  [[ -d "$home" ]] || return 1

  for rel in .zshrc .zprofile .bashrc .bash_profile; do
    [[ -f "${src_dir}/${rel}" ]] || continue
    install -Dm0644 -o "$user" -g "$user" "${src_dir}/${rel}" "${home}/${rel}"
  done

  if [[ -d "${src_dir}/.config" ]]; then
    mkdir -p "${home}/.config"
    while IFS= read -r -d '' entry; do
      base="$(basename "$entry")"
      if [[ -d "$entry" ]]; then
        mkdir -p "${home}/.config/${base}"
        rsync -a --delete --chown="${user}:${user}" \
          "${entry}/" "${home}/.config/${base}/"
      elif [[ -f "$entry" ]]; then
        install -Dm0644 -o "$user" -g "$user" \
          "$entry" "${home}/.config/${base}"
      fi
    done < <(find "${src_dir}/.config" -mindepth 1 -maxdepth 1 -print0)

    if [[ ! -f "${home}/.config/vlarch/active-theme" && -f "${home}/.config/themes/nord.json" ]]; then
      mkdir -p "${home}/.config/vlarch"
      printf '%s\n' "${home}/.config/themes/nord.json" >"${home}/.config/vlarch/active-theme"
      chown "${user}:${user}" "${home}/.config/vlarch/active-theme"
    fi
  fi

  if [[ -d "${src_dir}/.local" ]]; then
    mkdir -p "${home}/.local"
    rsync -a --chown="${user}:${user}" \
      "${src_dir}/.local/" "${home}/.local/"
  fi
}
