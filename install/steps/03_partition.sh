#!/usr/bin/env bash
# 03 - partition: erase, partition, encrypt, format, mount the target disk.
set -euo pipefail

# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/log.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/config.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/partition.sh"

vlarch_config_load "$VLARCH_CONFIG_FILE"
vlarch_config_validate

vlarch_partition_apply "$VLARCH_DISK"
vlarch_partition_mount

# Persist the partition paths back into the saved config so later steps and
# resumed runs can reuse them without re-discovering blkid.
vlarch_config_save "$VLARCH_CONFIG_FILE"
