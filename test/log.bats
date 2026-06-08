#!/usr/bin/env bats

load test_helper

@test "install log: vlarch_warn prints when VLARCH_VERBOSE=0" {
  VLARCH_VERBOSE=0
  unset VLARCH_SCRIPT_DIR
  # shellcheck disable=SC1091
  source "${VLARCH_REPO_ROOT}/install/lib/log.sh"
  run vlarch_warn "test message"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[vlarch] warning: test message"* ]]
}

@test "install log: vlarch_info stays silent when VLARCH_VERBOSE=0" {
  VLARCH_VERBOSE=0
  unset VLARCH_SCRIPT_DIR
  # shellcheck disable=SC1091
  source "${VLARCH_REPO_ROOT}/install/lib/log.sh"
  run vlarch_info "quiet info"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "update log: vlarch_warn prints when VLARCH_VERBOSE=0" {
  VLARCH_VERBOSE=0
  unset VLARCH_SCRIPT_DIR
  # shellcheck disable=SC1091
  source "${VLARCH_REPO_ROOT}/update/lib/log.sh"
  run vlarch_warn "test message"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[vlarch] warning: test message"* ]]
}

@test "update log: vlarch_info stays silent when VLARCH_VERBOSE=0" {
  VLARCH_VERBOSE=0
  unset VLARCH_SCRIPT_DIR
  # shellcheck disable=SC1091
  source "${VLARCH_REPO_ROOT}/update/lib/log.sh"
  run vlarch_info "quiet info"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
