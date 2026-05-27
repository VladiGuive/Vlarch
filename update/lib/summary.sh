#!/usr/bin/env bash
# Append-only stage notes for update/main.sh summary. Sourced - no set -e here.
# Public: vlarch_update_note <message>

vlarch_update_note() {
  printf '%s\n' "$1" >>"${VLARCH_UPDATE_SUMMARY_FILE:-/tmp/vlarch-update-summary.log}"
}
