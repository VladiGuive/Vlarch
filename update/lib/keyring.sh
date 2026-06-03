#!/usr/bin/env bash
# gnome-keyring PAM hooks for tty login (Edge, NetworkManager secrets, etc.).

vlarch_configure_gnome_keyring_pam() {
  local f

  command -v pacman >/dev/null 2>&1 \
    && pacman -Q gnome-keyring >/dev/null 2>&1 \
    || return 0

  for f in /etc/pam.d/login; do
    [[ -f "$f" ]] || continue
    grep -q 'pam_gnome_keyring\.so' "$f" && continue
    cat >>"$f" <<'PAM'

# Vlarch: gnome-keyring for Chromium/Edge and org.freedesktop.secrets
auth       optional     pam_gnome_keyring.so
session    optional     pam_gnome_keyring.so auto_start
PAM
  done
}
