#!/usr/bin/env bash
# Manifest helpers. Sourced - no set -e here.
# Public: vlarch_read_manifest <file>

vlarch_read_manifest() {
  local manifest="$1"
  sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$manifest"
}

vlarch_manifest_to_space_list() {
  vlarch_read_manifest "$1" | tr '\n' ' '
}
