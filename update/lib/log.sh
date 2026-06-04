#!/usr/bin/env bash
# Logging helpers. Sourced - no `set -e` here, the caller already enforces it.

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
  if declare -F vlarch_ui_tick >/dev/null 2>&1; then
    vlarch_ui_tick "$label"
  fi
  return 0
}

# pacman -Syu with live package name in the TTY UI (quiet mode only).
vlarch_run_pacman_syu() {
  local label="pacman -Syu"

  if ((VLARCH_VERBOSE)); then
    pacman -Syu --noconfirm
    return $?
  fi

  if ! declare -F vlarch_ui_set_op_label >/dev/null 2>&1 || ! vlarch_ui_enabled; then
    vlarch_run "$label" pacman -Syu --noconfirm
    return $?
  fi

  local log rc=0 line pkg cur tot
  log="$(vlarch_log_path step)"
  mkdir -p "$(dirname "$log")"
  : >>"$log"
  {
    printf '\n--- vlarch_run: %s ---\n' "$label"
    printf 'cmd: pacman -Syu --noconfirm\n'
  } >>"$log"

  vlarch_ui_set_op_label "$label"

  local -a pacman_cmd=(pacman -Syu --noconfirm)
  if command -v stdbuf >/dev/null 2>&1; then
    pacman_cmd=(stdbuf -oL -eL pacman -Syu --noconfirm)
  fi

  while IFS= read -r line; do
    printf '%s\n' "$line" >>"$log"
    if [[ "$line" =~ ^\(([0-9]+)/([0-9]+)\)[[:space:]]+(installing|upgrading|reinstalling|removing|downgrading)[[:space:]]+([^[:space:]]+) ]]; then
      cur="${BASH_REMATCH[1]}"
      tot="${BASH_REMATCH[2]}"
      pkg="${BASH_REMATCH[4]}"
      [[ "$pkg" == *... ]] && pkg="${pkg%...}"
      vlarch_ui_set_op_label "$(vlarch_ui_pacman_syu_label "$pkg" "$cur" "$tot")"
    fi
  done < <("${pacman_cmd[@]}" 2>&1)
  rc=${PIPESTATUS[0]:-0}

  if ((rc != 0)); then
    VLARCH_LAST_LOG="$log"
    vlarch_die "${label} failed (exit ${rc})"
  fi
  vlarch_ui_tick "$label"
  return 0
}

if [[ -n "${VLARCH_SCRIPT_DIR:-}" && -f "${VLARCH_SCRIPT_DIR}/update/lib/ui.sh" ]]; then
  # shellcheck disable=SC1091
  source "${VLARCH_SCRIPT_DIR}/update/lib/ui.sh"
fi
