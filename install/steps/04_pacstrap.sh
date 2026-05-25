#!/usr/bin/env bash
# 04 - pacstrap: install the minimal base into /mnt.
set -euo pipefail

# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/log.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/config.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/live.sh"

vlarch_config_load "$VLARCH_CONFIG_FILE"
vlarch_config_validate

manifest="${VLARCH_MANIFEST_DIR}/pacstrap.txt"
[[ -f "$manifest" ]] || vlarch_die "missing manifest: $manifest"

mountpoint -q /mnt || vlarch_die "/mnt is not mounted; run step 03 first"

# Enable multilib on the live ISO (so pacstrap can pull 32-bit deps if asked).
sed -i '/^\[multilib\]/,/Include/ s/^#//' /etc/pacman.conf

# Strip comments + blanks from the manifest.
mapfile -t pkgs < <(sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$manifest")
((${#pkgs[@]})) || vlarch_die "pacstrap manifest is empty"

# pacstrap is the loudest command in the whole install; capture every attempt
# into the per-step log and retry up to 3 times. Only the final failure
# surfaces (with the captured tail) via vlarch_die.
log="$(vlarch_log_path step)"
mkdir -p "$(dirname "$log")"
attempt=1
max_attempts=3
while ((attempt <= max_attempts)); do
  rc=0
  {
    printf '\n--- pacstrap attempt %d/%d ---\n' "$attempt" "$max_attempts"
  } >>"$log"
  if ((VLARCH_VERBOSE)); then
    pacstrap -K /mnt "${pkgs[@]}" || rc=$?
  else
    pacstrap -K /mnt "${pkgs[@]}" >>"$log" 2>&1 || rc=$?
  fi
  if ((rc == 0)); then
    break
  fi
  if ((attempt == max_attempts)); then
    VLARCH_LAST_LOG="$log"
    vlarch_die "pacstrap failed after ${max_attempts} attempts (exit ${rc})"
  fi
  vlarch_live_refresh_mirrors
  vlarch_run "pacman -Syy" pacman -Syy --noconfirm
  ((attempt++)) || true
done

# Verify every manifest package landed in /mnt; fail loudly if not.
missing=()
for pkg in "${pkgs[@]}"; do
  if ! arch-chroot /mnt pacman -Q "$pkg" >/dev/null 2>&1; then
    missing+=("$pkg")
  fi
done
((${#missing[@]} == 0)) || vlarch_die "pacstrap incomplete; missing: ${missing[*]}"

# genfstab's stdout *is* the fstab content; only silence its stderr.
if ((VLARCH_VERBOSE)); then
  genfstab -U /mnt >>/mnt/etc/fstab
else
  if ! genfstab -U /mnt >>/mnt/etc/fstab 2>>"$log"; then
    VLARCH_LAST_LOG="$log"
    vlarch_die "genfstab failed"
  fi
fi

# Carry the live ISO's resolver into the chroot so AUR/yay calls have DNS.
if [[ -f /etc/resolv.conf ]]; then
  cp -L /etc/resolv.conf /mnt/etc/resolv.conf
fi
