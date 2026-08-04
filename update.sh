#!/usr/bin/env bash
# update.sh - actualiza Vlarch.
#
# Flags:
#   -b, --bin            actualiza bin/ -> /usr/local/bin
#   -d, --dotfiles       copia dotfiles/ -> home del usuario
#   -p, --packages       instala paquetes faltantes (pacman.txt + aur.txt)
#   -s, --splashscreen   actualiza el theme de plymouth
#   -h, --help           muestra este texto
#
# Sin argumentos: muestra la ayuda.
set -euo pipefail

VLARCH_GIT_URL=https://github.com/VladiGuive/Vlarch.git
VLARCH_GIT_BRANCH=dev
VLARCH_BOOTSTRAP_LOG=/var/log/vlarch_update.log

usage() {
  sed -n '2,11p' "${BASH_SOURCE[0]}"
}

_die() {
  printf '[vlarch] CRITICAL ERROR: %s\n' "$*" >&2
  printf '[vlarch] SEE FULL LOG: %s\n' "$VLARCH_BOOTSTRAP_LOG" >&2
  exit 1
}
_clear() {
  clear
  cat <<'VLARCH_BOOTSTRAP_LOGO'
 _   ____             __
| | / / /__ _________/ /
| |/ / / _ `/ __/ __/ _ \
|___/_/\_,_/_/  \__/_//_/
VLARCH_BOOTSTRAP_LOGO
}

DO_BIN=0
DO_DOTFILES=0
DO_PACKAGES=0
DO_SPLASH=0

while (($#)); do
  case "$1" in
    -b|--bin) DO_BIN=1; shift ;;
    -d|--dotfiles) DO_DOTFILES=1; shift ;;
    -p|--packages) DO_PACKAGES=1; shift ;;
    -s|--splashscreen) DO_SPLASH=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'update: unknown option: %s\n' "$1" >&2; usage >&2; exit 1 ;;
  esac
done

if ((!DO_BIN && !DO_DOTFILES && !DO_PACKAGES && !DO_SPLASH)); then
  usage
  exit 0
fi

[[ "$(id -u)" -eq 0 ]] || _die "update must run as root"

VLARCH_USER="$(sed -n 's/^user=//p' /etc/vlarch/install-info 2>/dev/null || true)"
[[ -n "$VLARCH_USER" ]] || _die "no user found in /etc/vlarch/install-info"
VLARCH_HOME="/home/${VLARCH_USER}"
[[ -d "$VLARCH_HOME" ]] || _die "home not found: ${VLARCH_HOME}"

_clear
printf 'Vlarch update\n\n'

echo "Updating Vlarch." >"$VLARCH_BOOTSTRAP_LOG"

printf 'Downloading repository...\n'
WORKDIR="$(mktemp -d /tmp/vlarch-update.XXXXXX)"
trap 'rm -rf "${WORKDIR}" 2>/dev/null || true' EXIT
rm -rf "${WORKDIR}"
printf '  Cloning Vlarch repository...\n'
git clone --depth 1 --branch "${VLARCH_GIT_BRANCH}" "${VLARCH_GIT_URL}" "${WORKDIR}" >>"$VLARCH_BOOTSTRAP_LOG" 2>&1 \
  && printf '  Repository cloned.\n' || _die "could not clone repository"
VLARCH_SCRIPT_DIR="${WORKDIR}"
export VLARCH_SCRIPT_DIR

if ((DO_PACKAGES)); then
  printf 'Checking packages...\n'
  mapfile -t PACMAN_PKGS < <(grep -vE '^[[:space:]]*#|^[[:space:]]*$' "${VLARCH_SCRIPT_DIR}/pacman.txt")
  mapfile -t AUR_PKGS < <(grep -vE '^[[:space:]]*#|^[[:space:]]*$' "${VLARCH_SCRIPT_DIR}/aur.txt")

  missing_pacman=()
  for pkg in "${PACMAN_PKGS[@]}"; do
    pacman -Q "$pkg" >/dev/null 2>&1 || missing_pacman+=("$pkg")
  done
  missing_aur=()
  for pkg in "${AUR_PKGS[@]}"; do
    pacman -Q "$pkg" >/dev/null 2>&1 || missing_aur+=("$pkg")
  done
  total=$(( ${#missing_pacman[@]} + ${#missing_aur[@]} ))

  if ((total == 0)); then
    printf '  All packages up to date.\n'
  else
    if ((${#missing_aur[@]})) && ! su - "${VLARCH_USER}" -c 'command -v yay' >/dev/null 2>&1; then
      printf '  Bootstrapping yay...\n'
      su - "${VLARCH_USER}" -c '
        set -euo pipefail
        build_dir="$(mktemp -d)"
        trap "rm -rf \"$build_dir\"" EXIT
        git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$build_dir"
        cd "$build_dir"
        makepkg -si --noconfirm
      ' >>"$VLARCH_BOOTSTRAP_LOG" 2>&1 || _die "yay bootstrap failed"
    fi

    n=0
    for pkg in "${missing_pacman[@]}"; do
      n=$((n + 1))
      _clear
      printf 'Package %d/%d\n' "$n" "$total"
      printf '  %s...\n' "$pkg"
      pacman -S --noconfirm --needed "$pkg" >>"$VLARCH_BOOTSTRAP_LOG" 2>&1 ||
        _die "pacman -S ${pkg} failed"
    done
    for pkg in "${missing_aur[@]}"; do
      n=$((n + 1))
      _clear
      printf 'Package %d/%d\n' "$n" "$total"
      printf '  %s...\n' "$pkg"
      su - "${VLARCH_USER}" -c "yay -S --noconfirm --needed '$pkg'" >>"$VLARCH_BOOTSTRAP_LOG" 2>&1 ||
        _die "yay -S ${pkg} failed"
    done
    printf '  Packages up to date.\n'
  fi
fi

if ((DO_BIN)); then
  printf 'Installing bins...\n'
  for script in "${VLARCH_SCRIPT_DIR}"/bin/*; do
    install -Dm0755 "$script" "/usr/local/bin/$(basename "$script")"
  done
  printf '  Bins installed.\n'
fi

if ((DO_DOTFILES)); then
  printf 'Deploying dotfiles...\n'
  cp -r "${VLARCH_SCRIPT_DIR}/dotfiles/." "${VLARCH_HOME}/"
  chown -R "${VLARCH_USER}:${VLARCH_USER}" "${VLARCH_HOME}"
  printf '  Dotfiles deployed.\n'
fi

if ((DO_SPLASH)); then
  printf 'Updating plymouth theme...\n'
  cp -r "${VLARCH_SCRIPT_DIR}/plymouth/vlarch" /usr/share/plymouth/themes/
  plymouth-set-default-theme vlarch
  mkinitcpio -P >>"$VLARCH_BOOTSTRAP_LOG" 2>&1
  printf '  Theme updated.\n'
fi

printf 'Update complete.\n'
read -rp "  Reboot now? [y/N] " _ans </dev/tty
if [[ "${_ans,,}" == "y" ]]; then
  reboot
fi
