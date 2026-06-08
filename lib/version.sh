#!/usr/bin/env bash
# Shared semver-style version helpers (sort -V semantics).

# Compare two dotted version strings.
# Exit 0 if equal, 1 if $1 < $2, 2 if $1 > $2, 3 if either operand is empty.
vlarch_version_compare() {
  local a="${1:-}" b="${2:-}"
  [[ -n "$a" && -n "$b" ]] || return 3
  if [[ "$a" == "$b" ]]; then
    return 0
  fi
  if [[ "$(printf '%s\n%s\n' "$a" "$b" | sort -V | head -1)" == "$a" ]]; then
    return 1
  fi
  return 2
}

# Exit 0 when $2 is newer than $1.
vlarch_update_available() {
  local local_ver="$1" remote_ver="$2" cmp=0
  [[ -n "$local_ver" && -n "$remote_ver" ]] || return 1
  vlarch_version_compare "$local_ver" "$remote_ver" || cmp=$?
  [[ "$cmp" -eq 1 ]]
}

# Exit 0 when installed version is current (equal or ahead of remote).
vlarch_version_up_to_date() {
  local local_ver="$1" remote_ver="$2" cmp=0
  [[ -n "$local_ver" && -n "$remote_ver" ]] || return 1
  vlarch_version_compare "$local_ver" "$remote_ver" || cmp=$?
  [[ "$cmp" -eq 0 || "$cmp" -eq 2 ]]
}
