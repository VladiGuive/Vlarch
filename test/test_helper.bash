#!/usr/bin/env bash
# Shared helpers for Vlarch Bats tests.

bats_require_minimum_version 1.5.0

VLARCH_REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"

assert_exit_code() {
  local expected="$1"
  shift
  run -"$expected" "$@"
}

source_version_lib() {
  # shellcheck disable=SC1091
  source "${VLARCH_REPO_ROOT}/lib/version.sh"
}

source_overrides_lib() {
  VLARCH_TEST_WARNINGS=()
  vlarch_warn() {
    VLARCH_TEST_WARNINGS+=("$*")
    printf '[vlarch] warning: %s\n' "$*" >&2
  }
  vlarch_info() {
    :
  }
  # shellcheck disable=SC1091
  source "${VLARCH_REPO_ROOT}/update/lib/overrides.sh"
}

warnings_contain() {
  local needle="$1"
  local w
  for w in "${VLARCH_TEST_WARNINGS[@]}"; do
    [[ "$w" == *"$needle"* ]] && return 0
  done
  return 1
}
