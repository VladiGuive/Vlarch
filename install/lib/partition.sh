#!/usr/bin/env bash
# Partition + LUKS + btrfs helpers. The layout is fixed:
#   p1  512 MiB  EFI  (vfat)
#   p2    1 GiB  /boot (ext4, unencrypted - GRUB needs it readable)
#   p3   rest    LUKS1 -> btrfs subvolumes @, @home, @snapshots, @var_log, @swap
# Public: vlarch_partition_apply <disk>, vlarch_partition_mount, vlarch_partition_unmount
#
# All loud commands run via vlarch_run so they are silent unless --verbose;
# their output is captured into the per-step log and the tail is dumped on
# failure via vlarch_die.

vlarch_partition_part_path() {
  local disk="$1" idx="$2"
  if [[ "$disk" == /dev/nvme* || "$disk" == /dev/loop* || "$disk" == /dev/mmcblk* ]]; then
    printf '%sp%s' "$disk" "$idx"
  else
    printf '%s%s' "$disk" "$idx"
  fi
}

vlarch_partition_default_swap_size_mib() {
  local ram_mib
  ram_mib=$(awk '/^MemTotal:/ {print int($2/1024)}' /proc/meminfo)
  printf '%s' $((ram_mib + 2048))
}

# Quietly close any prior cryptroot / mounts / swap from a previous attempt.
_vlarch_partition_reset() {
  swapoff -a >/dev/null 2>&1 || true
  umount -R /mnt >/dev/null 2>&1 || true
  cryptsetup close cryptroot >/dev/null 2>&1 || true
}

# Erase, partition, encrypt, format the target disk in `VLARCH_DISK`.
# Exports VLARCH_PART_EFI / VLARCH_PART_BOOT / VLARCH_PART_LUKS / VLARCH_LUKS_UUID.
vlarch_partition_apply() {
  local disk="$1"
  [[ -b "$disk" ]] || vlarch_die "not a block device: $disk"
  [[ -n "${VLARCH_LUKS_PASSPHRASE:-}" ]] || vlarch_die "VLARCH_LUKS_PASSPHRASE not set"

  _vlarch_partition_reset

  vlarch_run "wipefs ${disk}"     wipefs -af "$disk"
  vlarch_run "sgdisk zap ${disk}" sgdisk --zap-all "$disk"
  vlarch_run "sgdisk layout ${disk}" \
    sgdisk \
      -n1:0:+512M -t1:ef00 -c1:VLARCH_EFI \
      -n2:0:+1G   -t2:8300 -c2:VLARCH_BOOT \
      -n3:0:0     -t3:8309 -c3:VLARCH_LUKS \
      "$disk"
  vlarch_run "partprobe ${disk}" partprobe "$disk"
  sleep 1

  local p1 p2 p3
  p1="$(vlarch_partition_part_path "$disk" 1)"
  p2="$(vlarch_partition_part_path "$disk" 2)"
  p3="$(vlarch_partition_part_path "$disk" 3)"

  vlarch_run "mkfs.vfat ${p1}" mkfs.vfat -F32 -n VLARCH_EFI "$p1"
  vlarch_run "mkfs.ext4 ${p2}" mkfs.ext4 -F -L VLARCH_BOOT "$p2"

  # luksFormat reads the passphrase from stdin; vlarch_run can't help here
  # because we need to pipe the passphrase in. Capture stderr to the step log
  # ourselves so the run stays silent.
  local log
  log="$(vlarch_log_path step)"
  mkdir -p "$(dirname "$log")"
  if ! printf '%s' "$VLARCH_LUKS_PASSPHRASE" \
       | cryptsetup --type luks1 --batch-mode -v luksFormat "$p3" --key-file - \
         >>"$log" 2>&1; then
    VLARCH_LAST_LOG="$log"
    vlarch_die "cryptsetup luksFormat ${p3} failed"
  fi
  if ! printf '%s' "$VLARCH_LUKS_PASSPHRASE" \
       | cryptsetup open "$p3" cryptroot --key-file - >>"$log" 2>&1; then
    VLARCH_LAST_LOG="$log"
    vlarch_die "cryptsetup open ${p3} failed"
  fi

  vlarch_run "mkfs.btrfs cryptroot" mkfs.btrfs -f -L VLARCH_ROOT /dev/mapper/cryptroot

  local tmp_mnt="/mnt"
  vlarch_run "mount cryptroot top" mount /dev/mapper/cryptroot "$tmp_mnt"
  vlarch_run "btrfs subvolume create @"          btrfs subvolume create "$tmp_mnt/@"
  vlarch_run "btrfs subvolume create @home"      btrfs subvolume create "$tmp_mnt/@home"
  vlarch_run "btrfs subvolume create @snapshots" btrfs subvolume create "$tmp_mnt/@snapshots"
  vlarch_run "btrfs subvolume create @var_log"   btrfs subvolume create "$tmp_mnt/@var_log"
  vlarch_run "btrfs subvolume create @swap"      btrfs subvolume create "$tmp_mnt/@swap"
  vlarch_run "umount cryptroot top"              umount "$tmp_mnt"

  local luks_uuid
  luks_uuid=$(blkid -s UUID -o value "$p3")
  [[ -n "$luks_uuid" ]] || vlarch_die "could not read LUKS UUID for $p3"

  VLARCH_PART_EFI="$p1"
  VLARCH_PART_BOOT="$p2"
  VLARCH_PART_LUKS="$p3"
  VLARCH_LUKS_UUID="$luks_uuid"
  export VLARCH_PART_EFI VLARCH_PART_BOOT VLARCH_PART_LUKS VLARCH_LUKS_UUID
}

# Mount every subvolume + EFI + /boot at /mnt and create the swapfile.
vlarch_partition_mount() {
  [[ -n "${VLARCH_PART_EFI:-}"  ]] || vlarch_die "VLARCH_PART_EFI not set"
  [[ -n "${VLARCH_PART_BOOT:-}" ]] || vlarch_die "VLARCH_PART_BOOT not set"
  [[ -e /dev/mapper/cryptroot ]] || vlarch_die "cryptroot is not open"

  local opts="rw,noatime,compress=zstd:3,space_cache=v2"

  vlarch_run "mount @"          mount -o "${opts},subvol=@"          /dev/mapper/cryptroot /mnt
  mkdir -p /mnt/{home,.snapshots,var/log,swap,boot,boot/EFI}
  vlarch_run "mount @home"      mount -o "${opts},subvol=@home"      /dev/mapper/cryptroot /mnt/home
  vlarch_run "mount @snapshots" mount -o "${opts},subvol=@snapshots" /dev/mapper/cryptroot /mnt/.snapshots
  vlarch_run "mount @var_log"   mount -o "${opts},subvol=@var_log"   /dev/mapper/cryptroot /mnt/var/log
  # Swap subvolume must not be compressed/CoW.
  vlarch_run "mount @swap"      mount -o "rw,noatime,subvol=@swap"   /dev/mapper/cryptroot /mnt/swap

  vlarch_run "mount /boot"      mount "${VLARCH_PART_BOOT}" /mnt/boot
  mkdir -p /mnt/boot/EFI
  vlarch_run "mount /boot/EFI"  mount "${VLARCH_PART_EFI}"  /mnt/boot/EFI

  local swapfile="/mnt/swap/swapfile"
  if [[ ! -f "$swapfile" ]]; then
    local size_mib
    size_mib=$(vlarch_partition_default_swap_size_mib)
    chattr +C /mnt/swap >/dev/null 2>&1 || true
    if ! btrfs filesystem mkswapfile --size "${size_mib}m" "$swapfile" >/dev/null 2>&1; then
      vlarch_run "fallocate swapfile" truncate -s 0 "$swapfile"
      chattr +C "$swapfile" >/dev/null 2>&1 || true
      vlarch_run "fallocate ${size_mib}M swapfile" fallocate -l "${size_mib}M" "$swapfile"
      chmod 600 "$swapfile"
      vlarch_run "mkswap" mkswap "$swapfile"
    fi
  fi
  swapon "$swapfile" >/dev/null 2>&1 || true
}

vlarch_partition_unmount() {
  swapoff -a >/dev/null 2>&1 || true
  umount -R /mnt >/dev/null 2>&1 || true
  cryptsetup close cryptroot >/dev/null 2>&1 || true
}
