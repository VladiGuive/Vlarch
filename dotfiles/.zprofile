# Vlarch tty1 autologin hook (login shells).

if [[ -z ${WAYLAND_DISPLAY-} && ${XDG_VTNR-0} -eq 1 ]] \
    && command -v vlarch-tty-login >/dev/null 2>&1; then
  exec vlarch-tty-login
fi
