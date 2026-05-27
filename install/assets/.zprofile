# Install seed copy — keep in sync with dotfiles/.zprofile at repo root.
# Vlarch login shell hook. Runs only on tty1 outside an existing Wayland session.
# Triggers the one-shot first-boot bootstrap when armed, then execs Hyprland.

if [[ -z ${WAYLAND_DISPLAY-} && ${XDG_VTNR-0} -eq 1 ]]; then
  if [[ -f /var/lib/vlarch/first-boot.pending ]] && command -v vlarch >/dev/null 2>&1; then
    vlarch first-boot
  fi
  if command -v Hyprland >/dev/null 2>&1; then
    exec Hyprland
  fi
fi
