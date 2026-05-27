#!/usr/bin/env bash
# Dotfile deploy helpers. Sourced - no set -e here.

vlarch_deploy_dotfiles() {
  local user="$1"
  local src_dir="$2"
  local home="/home/${user}"

  [[ -d "$src_dir" ]] || return 1
  [[ -d "$home" ]] || return 1

  rm -f "$home/.zshrc" "$home/.zprofile" "$home/.bashrc" "$home/.bash_profile"
  rsync -a "${src_dir}/" "$home/"
  chown -R "${user}:${user}" "$home"
}
