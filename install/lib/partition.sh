#!/usr/bin/env bash
# Partition + LUKS + btrfs helpers. The layout is fixed:
#   p1  512 MiB  EFI  (vfat)
#   p2    1 GiB  /boot (ext4, unencrypted - GRUB needs it readable)
#   p3   rest    LUKS1 -> btrfs subvolumes @, @home, @snapshots, @var_log, @swap
# Public: vlarch_partition_apply <disk>, vlarch_partition_mount, vlarch_partition_unmount

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

# Erase, partition, encrypt, format the target disk in `VLARCH_DISK`.
# Exports VLARCH_PART_EFI / VLARCH_PART_BOOT / VLARCH_PART_LUKS / VLARCH_LUKS_UUID.
vlarch_partition_apply() {
  local disk="$1"
  [[ -b "$disk" ]] || vlarch_die "not a block device: $disk"
  [[ -n "${VLARCH_LUKS_PASSPHRASE:-}" ]] || vlarch_die "VLARCH_LUKS_PASSPHRASE not set"

  vlarch_step "Wiping and partitioning $disk"
  swapoff -a 2>/dev/null || true
  umount -R /mnt 2>/dev/null || true
  cryptsetup close cryptroot 2>/dev/null || true
  wipefs -af "$disk"
  sgdisk --zap-all "$disk"
  sgdisk \
    -n1:0:+512M -t1:ef00 -c1:VLARCH_EFI \
    -n2:0:+1G   -t2:8300 -c2:VLARCH_BOOT \
    -n3:0:0     -t3:8309 -c3:VLARCH_LUKS \
    "$disk"
  partprobe "$disk"
  sleep 1

  local p1 p2 p3
  p1="$(vlarch_partition_part_path "$disk" 1)"
  p2="$(vlarch_partition_part_path "$disk" 2)"
  p3="$(vlarch_partition_part_path "$disk" 3)"

  vlarch_info "Formatting $p1 (EFI)"
  mkfs.vfat -F32 -n VLARCH_EFI "$p1"

  vlarch_info "Formatting $p2 (/boot)"
  mkfs.ext4 -F -L VLARCH_BOOT "$p2"

  vlarch_step "Encrypting $p3 with LUKS1"
  printf '%s' "$VLARCH_LUKS_PASSPHRASE" \
    | cryptsetup --type luks1 --batch-mode -v luksFormat "$p3" --key-file -
  printf '%s' "$VLARCH_LUKS_PASSPHRASE" \
    | cryptsetup open "$p3" cryptroot --key-file -

  vlarch_info "Creating btrfs filesystem on /dev/mapper/cryptroot"
  mkfs.btrfs -f -L VLARCH_ROOT /dev/mapper/cryptroot

  local tmp_mnt="/mnt"
  mount /dev/mapper/cryptroot "$tmp_mnt"
  btrfs subvolume create "$tmp_mnt/@"
  btrfs subvolume create "$tmp_mnt/@home"
  btrfs subvolume create "$tmp_mnt/@snapshots"
  btrfs subvolume create "$tmp_mnt/@var_log"
  btrfs subvolume create "$tmp_mnt/@swap"
  umount "$tmp_mnt"

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
  vlarch_step "Mounting target filesystem at /mnt"
  mount -o "${opts},subvol=@" /dev/mapper/cryptroot /mnt
  mkdir -p /mnt/{home,.snapshots,var/log,swap,boot,boot/EFI}
  mount -o "${opts},subvol=@home"      /dev/mapper/cryptroot /mnt/home
  mount -o "${opts},subvol=@snapshots" /dev/mapper/cryptroot /mnt/.snapshots
  mount -o "${opts},subvol=@var_log"   /dev/mapper/cryptroot /mnt/var/log
  # Swap subvolume must not be compressed/CoW.
  mount -o "rw,noatime,subvol=@swap"   /dev/mapper/cryptroot /mnt/swap

  mount "${VLARCH_PART_BOOT}" /mnt/boot
  mkdir -p /mnt/boot/EFI
  mount "${VLARCH_PART_EFI}"  /mnt/boot/EFI

  local swapfile="/mnt/swap/swapfile"
  if [[ ! -f "$swapfile" ]]; then
    local size_mib
    size_mib=$(vlarch_partition_default_swap_size_mib)
    vlarch_info "Creating ${size_mib} MiB swapfile at ${swapfile}"
    chattr +C /mnt/swap 2>/dev/null || true
    btrfs filesystem mkswapfile --size "${size_mib}m" "$swapfile" 2>/dev/null \
      || {
        truncate -s 0 "$swapfile"
        chattr +C "$swapfile" 2>/dev/null || true
        fallocate -l "${size_mib}M" "$swapfile"
        chmod 600 "$swapfile"
        mkswap "$swapfile"
      }
  fi
  swapon "$swapfile" 2>/dev/null || true
}

vlarch_partition_unmount() {
  swapoff -a 2>/dev/null || true
  umount -R /mnt 2>/dev/null || true
  cryptsetup close cryptroot 2>/dev/null || true
}
