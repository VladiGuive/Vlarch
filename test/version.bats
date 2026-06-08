#!/usr/bin/env bats

load test_helper

setup() {
  source_version_lib
}

@test "vlarch_version_compare: equal versions return 0" {
  assert_exit_code 0 vlarch_version_compare "0.0.173" "0.0.173"
}

@test "vlarch_version_compare: lesser version returns 1" {
  assert_exit_code 1 vlarch_version_compare "0.0.9" "0.0.10"
  assert_exit_code 1 vlarch_version_compare "0.0.173" "0.0.174"
}

@test "vlarch_version_compare: greater version returns 2" {
  assert_exit_code 2 vlarch_version_compare "0.0.10" "0.0.9"
  assert_exit_code 2 vlarch_version_compare "0.0.174" "0.0.173"
}

@test "vlarch_version_compare: empty operand returns 3" {
  assert_exit_code 3 vlarch_version_compare "" "0.0.1"
  assert_exit_code 3 vlarch_version_compare "0.0.1" ""
  assert_exit_code 3 vlarch_version_compare "" ""
}

@test "vlarch_version_compare: pre-release ordering follows sort -V" {
  assert_exit_code 1 vlarch_version_compare "0.0.173" "0.0.173-rc1"
  assert_exit_code 1 vlarch_version_compare "1.0.0-alpha" "1.0.0-beta"
  assert_exit_code 1 vlarch_version_compare "1.0.0" "1.0.0-alpha"
}

@test "vlarch_update_available: true when remote is newer" {
  assert_exit_code 0 vlarch_update_available "0.0.173" "0.0.174"
}

@test "vlarch_update_available: false when equal or ahead" {
  assert_exit_code 1 vlarch_update_available "0.0.174" "0.0.173"
  assert_exit_code 1 vlarch_update_available "0.0.173" "0.0.173"
}

@test "vlarch_update_available: false when either operand is empty" {
  assert_exit_code 1 vlarch_update_available "" "0.0.1"
  assert_exit_code 1 vlarch_update_available "0.0.1" ""
}

@test "vlarch_version_up_to_date: true when equal or ahead" {
  assert_exit_code 0 vlarch_version_up_to_date "0.0.173" "0.0.173"
  assert_exit_code 0 vlarch_version_up_to_date "0.0.174" "0.0.173"
}

@test "vlarch_version_up_to_date: false when behind remote" {
  assert_exit_code 1 vlarch_version_up_to_date "0.0.173" "0.0.174"
}

@test "vlarch_version_up_to_date: false when either operand is empty" {
  assert_exit_code 1 vlarch_version_up_to_date "" "0.0.1"
  assert_exit_code 1 vlarch_version_up_to_date "0.0.1" ""
}
