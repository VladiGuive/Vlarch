#!/usr/bin/env bash
# 07 - chroot_boot: mkinitcpio + GRUB so a single LUKS passphrase at GRUB
# unlocks the system; no plaintext key on disk.
set -euo pipefail

# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/log.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/config.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/chroot.sh"

vlarch_config_load "$VLARCH_CONFIG_FILE"
vlarch_config_validate
[[ -n "${VLARCH_LUKS_UUID:-}" ]] || vlarch_die "VLARCH_LUKS_UUID not set; rerun step 03"

vlarch_step "Configuring mkinitcpio + GRUB (LUKS passphrase at GRUB)"
vlarch_chroot_run '
set -euo pipefail

# encrypt hook between block and filesystems for LUKS-on-root.
sed -i -E "s/^HOOKS=.*/HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block encrypt filesystems fsck)/" /etc/mkinitcpio.conf
mkinitcpio -P

cmdline="cryptdevice=UUID=${VLARCH_LUKS_UUID}:cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@"

if grep -q "^GRUB_ENABLE_CRYPTODISK=" /etc/default/grub; then
  sed -i "s|^GRUB_ENABLE_CRYPTODISK=.*|GRUB_ENABLE_CRYPTODISK=y|" /etc/default/grub
else
  echo "GRUB_ENABLE_CRYPTODISK=y" >>/etc/default/grub
fi

if grep -q "^GRUB_CMDLINE_LINUX=" /etc/default/grub; then
  sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"${cmdline}\"|" /etc/default/grub
else
  echo "GRUB_CMDLINE_LINUX=\"${cmdline}\"" >>/etc/default/grub
fi

mount -t efivarfs efivarfs /sys/firmware/efi/efivars 2>/dev/null || true
grub-install --target=x86_64-efi --efi-directory=/boot/EFI --bootloader-id=Vlarch
grub-mkconfig -o /boot/grub/grub.cfg
'
