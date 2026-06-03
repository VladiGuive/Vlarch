#!/usr/bin/env bash
# Timeshift + grub-btrfs setup for Vlarch (btrfs @ layout, LUKS root). Sourced - no set -e here.

vlarch_grub_btrfs_configure() {
  command -v grub-btrfs >/dev/null 2>&1 || return 0

  local cfg=/etc/default/grub-btrfs/config
  [[ -f "$cfg" ]] || return 1

  if grep -qE '^#?GRUB_BTRFS_ENABLE_CRYPTODISK=' "$cfg"; then
    sed -i 's/^#\?GRUB_BTRFS_ENABLE_CRYPTODISK=.*/GRUB_BTRFS_ENABLE_CRYPTODISK="true"/' "$cfg"
  else
    printf '%s\n' 'GRUB_BTRFS_ENABLE_CRYPTODISK="true"' >>"$cfg"
  fi

  install -d /etc/systemd/system/grub-btrfsd.service.d
  install -Dm0644 /dev/stdin \
    /etc/systemd/system/grub-btrfsd.service.d/vlarch-timeshift.conf <<'UNIT'
[Service]
ExecStart=
ExecStart=/usr/bin/grub-btrfsd --syslog --timeshift-auto
UNIT

  systemctl daemon-reload
  systemctl enable grub-btrfsd.service >/dev/null 2>&1 || true
  systemctl restart grub-btrfsd.service >/dev/null 2>&1 || true
}

vlarch_timeshift_configure_btrfs() {
  command -v timeshift >/dev/null 2>&1 || return 0
  findmnt -n -o FSTYPE --target / 2>/dev/null | grep -qx btrfs || return 0

  local uuid
  uuid=$(findmnt -n -o UUID --target / 2>/dev/null || true)
  [[ -n "$uuid" ]] || return 1

  install -d /etc/timeshift
  if [[ -f /etc/timeshift/timeshift.json ]]; then
    if command -v python3 >/dev/null 2>&1; then
      python3 - "$uuid" <<'PY' || return 1
import json, sys
path = "/etc/timeshift/timeshift.json"
uuid = sys.argv[1]
with open(path, encoding="utf-8") as f:
    data = json.load(f)
data["btrfs_mode"] = "true"
data["backup_device_uuid"] = uuid
data["do_first_run"] = "false"
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
      return 0
    fi
  fi

  install -Dm0644 /dev/stdin /etc/timeshift/timeshift.json <<EOF
{
  "backup_device_uuid" : "${uuid}",
  "parent_device_uuid" : "",
  "do_first_run" : "false",
  "btrfs_mode" : "true",
  "include_btrfs_home_for_backup" : "false",
  "include_btrfs_home_for_restore" : "false",
  "stop_cron_emails" : "true",
  "schedule_monthly" : "false",
  "schedule_weekly" : "false",
  "schedule_daily" : "false",
  "schedule_hourly" : "false",
  "schedule_boot" : "false",
  "count_monthly" : "2",
  "count_weekly" : "3",
  "count_daily" : "5",
  "count_hourly" : "6",
  "count_boot" : "5",
  "date_format" : "%Y-%m-%d %H:%M:%S",
  "exclude" : [],
  "exclude-apps" : []
}
EOF
}

vlarch_grub_regenerate() {
  command -v grub-mkconfig >/dev/null 2>&1 || return 0
  [[ -d /boot/grub ]] || return 0
  grub-mkconfig -o /boot/grub/grub.cfg
}

vlarch_setup_grub_timeshift_snapshots() {
  vlarch_timeshift_configure_btrfs
  vlarch_grub_btrfs_configure
  vlarch_grub_regenerate
}
