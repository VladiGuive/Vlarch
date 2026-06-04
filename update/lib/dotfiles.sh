#!/usr/bin/env bash
# Dotfile deploy helpers. Sourced - no set -e here.
# Syncs only repo-managed paths; never mirrors or deletes all of ~/.config.

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
  fi

  if [[ -d "${src_dir}/.local" ]]; then
    mkdir -p "${home}/.local"
    rsync -a --chown="${user}:${user}" \
      "${src_dir}/.local/" "${home}/.local/"
  fi
}
