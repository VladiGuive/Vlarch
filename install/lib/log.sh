#!/usr/bin/env bash
# Logging helpers. Sourced — no `set -e` here, the caller already enforces it.
# Public: vlarch_step, vlarch_info, vlarch_warn, vlarch_die, vlarch_require_cmd

VLARCH_VERBOSE="${VLARCH_VERBOSE:-0}"

vlarch_step() {
  printf '[vlarch] == %s\n' "$*"
}

vlarch_info() {
  if ((VLARCH_VERBOSE)); then
    printf '[vlarch] %s\n' "$*"
  fi
}

vlarch_warn() {
  printf '[vlarch] warning: %s\n' "$*" >&2
}

vlarch_die() {
  printf '[vlarch] error: %s\n' "$*" >&2
  exit 1
}

vlarch_require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || vlarch_die "missing required command: $cmd"
}
