#!/usr/bin/env bash
# 08 - chroot_yay: bootstrap yay as the install user (packages come from update).
set -euo pipefail

# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/log.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/config.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/chroot.sh"

vlarch_config_load "$VLARCH_CONFIG_FILE"
vlarch_config_validate

vlarch_chroot_run '
set -euo pipefail

if ! id "${VLARCH_USER}" >/dev/null 2>&1; then
  echo "user ${VLARCH_USER} not found in chroot" >&2
  exit 1
fi

if ! command -v yay >/dev/null 2>&1; then
  build_dir="$(mktemp -d)"
  chown "${VLARCH_USER}:${VLARCH_USER}" "$build_dir"
  trap '"'"'rm -rf "$build_dir"'"'"' EXIT
  su - "${VLARCH_USER}" -c "
    set -euo pipefail
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git \"${build_dir}\"
    cd \"${build_dir}\"
    makepkg -si --noconfirm
  "
fi

if [[ -x /usr/bin/zsh ]]; then
  chsh -s /usr/bin/zsh "${VLARCH_USER}" || true
fi
'
