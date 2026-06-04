#!/usr/bin/env bash
# gnome-keyring PAM hooks for tty autologin (Edge, NetworkManager secrets, etc.).

_vlarch_configure_gnome_keyring_pam_file() {
  local f="$1"

  [[ -f "$f" ]] || return 0
  grep -q 'pam_gnome_keyring\.so' "$f" && return 0

  cat >>"$f" <<'PAM'

# Vlarch: gnome-keyring for Chromium/Edge and org.freedesktop.secrets
auth       optional     pam_gnome_keyring.so
session    optional     pam_gnome_keyring.so auto_start
PAM
}

vlarch_configure_gnome_keyring_pam() {
  command -v pacman >/dev/null 2>&1 \
    && pacman -Q gnome-keyring >/dev/null 2>&1 \
    || return 0

  _vlarch_configure_gnome_keyring_pam_file /etc/pam.d/login
  _vlarch_configure_gnome_keyring_pam_file /etc/pam.d/system-login
}
