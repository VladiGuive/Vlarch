#!/usr/bin/env bash
# update.sh - actualiza Vlarch: repo + deps faltantes + dotfiles.
#
#   bash update.sh          (desde el repo)
#   curl -fsSL <url>/update.sh | bash
set -euo pipefail

VLARCH_GIT_URL=https://github.com/VladiGuive/Vlarch.git
VLARCH_GIT_BRANCH=dev
VLARCH_BOOTSTRAP_LOG=/var/log/vlarch_update.log

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

[[ "$(id -u)" -eq 0 ]] || _die "update must run as root"

# Usuario del sistema (para dotfiles y yay).
VLARCH_USER="$(sed -n 's/^user=//p' /etc/vlarch/install-info 2>/dev/null || true)"
[[ -n "$VLARCH_USER" ]] || _die "no user found in /etc/vlarch/install-info"
VLARCH_HOME="/home/${VLARCH_USER}"
[[ -d "$VLARCH_HOME" ]] || _die "home not found: ${VLARCH_HOME}"

_clear
printf 'Vlarch update\n\n'

echo "Updating Vlarch." >"$VLARCH_BOOTSTRAP_LOG"

# 1 - descarga el repo (igual que install.sh).
printf 'Downloading repository...\n'
WORKDIR="$(mktemp -d /tmp/vlarch-update.XXXXXX)"
trap 'rm -rf "${WORKDIR}" 2>/dev/null || true' EXIT
rm -rf "${WORKDIR}"
printf '  Cloning Vlarch repository...\n'
git clone --depth 1 --branch "${VLARCH_GIT_BRANCH}" "${VLARCH_GIT_URL}" "${WORKDIR}" >>"$VLARCH_BOOTSTRAP_LOG" 2>&1 \
  && printf '  Repository cloned.\n' || _die "could not clone repository"
VLARCH_SCRIPT_DIR="${WORKDIR}"
export VLARCH_SCRIPT_DIR

# 2 - instala los paquetes FALTANTES de pacman.txt y aur.txt.
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
  # yay bootstrap si hace falta para los paquetes AUR.
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

# 3 - copia dotfiles al home del usuario.
printf 'Deploying dotfiles...\n'
cp -r "${VLARCH_SCRIPT_DIR}/dotfiles/." "${VLARCH_HOME}/"
chown -R "${VLARCH_USER}:${VLARCH_USER}" "${VLARCH_HOME}"
printf '  Dotfiles deployed.\n'

# 4 - pide reinicio.
printf 'Update complete.\n'
read -rp "  Reboot now? [y/N] " _ans </dev/tty
if [[ "${_ans,,}" == "y" ]]; then
  reboot
fi
