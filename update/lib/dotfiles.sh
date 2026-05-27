#!/usr/bin/env bash
# Dotfile deploy helpers. Sourced - no set -e here.
# Only syncs paths present in the repo; never deletes or chowns the whole home.

vlarch_deploy_dotfiles() {
  local user="$1"
  local src_dir="$2"
  local home="/home/${user}"
  local rel

  [[ -d "$src_dir" ]] || return 1
  [[ -d "$home" ]] || return 1

  for rel in .zshrc .zprofile .bashrc .bash_profile; do
    [[ -f "${src_dir}/${rel}" ]] || continue
    install -Dm0644 -o "$user" -g "$user" "${src_dir}/${rel}" "${home}/${rel}"
  done

  if [[ -d "${src_dir}/.config" ]]; then
    mkdir -p "${home}/.config"
    rsync -a --delete --chown="${user}:${user}" \
      "${src_dir}/.config/" "${home}/.config/"
  fi

  if [[ -d "${src_dir}/.local" ]]; then
    mkdir -p "${home}/.local"
    rsync -a --chown="${user}:${user}" \
      "${src_dir}/.local/" "${home}/.local/"
  fi
}
