# Vlarch tty1 autologin hook (non-login shells; agetty may skip .zprofile).

export PATH="/usr/local/bin:$HOME/.local/bin:/usr/bin:$PATH"

if [[ -z ${VLARCH_TTY_LOGIN-} ]] \
    && [[ -z ${WAYLAND_DISPLAY-} ]] \
    && { [[ $(tty 2>/dev/null) == /dev/tty1 ]] || [[ ${XDG_VTNR-0} -eq 1 ]]; } \
    && command -v vlarch-tty-login >/dev/null 2>&1; then
  exec vlarch-tty-login
fi
