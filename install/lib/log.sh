#!/usr/bin/env bash
# Logging helpers. Sourced - no `set -e` here, the caller already enforces it.
# Public:
#   vlarch_step <msg>            - silent unless VLARCH_VERBOSE=1
#   vlarch_info <msg>            - silent unless VLARCH_VERBOSE=1
#   vlarch_warn <msg>            - silent unless VLARCH_VERBOSE=1
#   vlarch_die  <msg>            - always prints; dumps tail of VLARCH_LAST_LOG; exits 1
#   vlarch_require_cmd <name>    - vlarch_die if missing
#   vlarch_run  <label> <cmd...> - quiet wrapper: captures cmd output to a per-step
#                                  log; on failure prints last 20 lines and dies.
#
# Goal: silent during normal operation; on fatal, print the failure reason and
# enough context (tail of captured log) to debug without re-running.

VLARCH_VERBOSE="${VLARCH_VERBOSE:-0}"
VLARCH_LOG_DIR="${VLARCH_LOG_DIR:-/tmp}"
VLARCH_LAST_LOG="${VLARCH_LAST_LOG:-}"

vlarch_step() {
  if ((VLARCH_VERBOSE)); then
    printf '[vlarch] == %s\n' "$*"
  fi
}

vlarch_info() {
  if ((VLARCH_VERBOSE)); then
    printf '[vlarch] %s\n' "$*"
  fi
}

vlarch_warn() {
  if ((VLARCH_VERBOSE)); then
    printf '[vlarch] warning: %s\n' "$*" >&2
  fi
}

vlarch_die() {
  printf '[vlarch] error: %s\n' "$*" >&2
  if [[ -n "${VLARCH_LAST_LOG:-}" && -s "${VLARCH_LAST_LOG}" ]]; then
    printf '[vlarch] last 20 lines of %s:\n' "${VLARCH_LAST_LOG}" >&2
    tail -n 20 "${VLARCH_LAST_LOG}" | sed 's/^/  /' >&2
    printf '[vlarch] full log: %s\n' "${VLARCH_LAST_LOG}" >&2
  fi
  exit 1
}

vlarch_require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || vlarch_die "missing required command: $cmd"
}

vlarch_log_path() {
  local kind="${1:-step}"
  local name="${VLARCH_CURRENT_STEP:-unknown}"
  printf '%s/vlarch-%s-%s.log' "$VLARCH_LOG_DIR" "$kind" "$name"
}

# Run a command; in verbose mode let it stream, in quiet mode capture to a
# per-step log and die with the tail on failure. Each invocation appends to the
# same per-step log so a multi-step script keeps all its output together.
vlarch_run() {
  local label="$1"
  shift
  if (($# == 0)); then
    vlarch_die "vlarch_run: no command given for label '${label}'"
  fi

  if ((VLARCH_VERBOSE)); then
    "$@"
    return $?
  fi

  local log
  log="$(vlarch_log_path step)"
  mkdir -p "$(dirname "$log")"
  : >>"$log"
  {
    printf '\n--- vlarch_run: %s ---\n' "$label"
    printf 'cmd: %s\n' "$*"
  } >>"$log"

  local rc=0
  "$@" >>"$log" 2>&1 || rc=$?
  if ((rc != 0)); then
    VLARCH_LAST_LOG="$log"
    vlarch_die "${label} failed (exit ${rc})"
  fi
  return 0
}
