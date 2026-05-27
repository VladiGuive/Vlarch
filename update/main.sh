#!/usr/bin/env bash
# Update orchestrator. Sources libs and runs update/steps/NN_*.sh in order.
set -euo pipefail

[[ -n "${VLARCH_SCRIPT_DIR:-}" && -d "${VLARCH_SCRIPT_DIR}" ]] \
  || { printf '[vlarch] error: VLARCH_SCRIPT_DIR not set\n' >&2; exit 1; }

# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/log.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/runtime.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/update/lib/summary.sh"

VLARCH_DRY_RUN="${VLARCH_DRY_RUN:-0}"
VLARCH_VERBOSE="${VLARCH_VERBOSE:-0}"
VLARCH_INFO_FILE="${VLARCH_INFO_FILE:-/etc/vlarch/install-info}"
VLARCH_VERSION="${VLARCH_VERSION:-0.0.0-dev}"
VLARCH_MANIFEST_DIR="${VLARCH_MANIFEST_DIR:-${VLARCH_SCRIPT_DIR}/update/packages}"
VLARCH_DOTFILES_DIR="${VLARCH_DOTFILES_DIR:-${VLARCH_SCRIPT_DIR}/dotfiles}"
VLARCH_BIN_DIR="${VLARCH_BIN_DIR:-${VLARCH_SCRIPT_DIR}/bin}"
VLARCH_UPDATE_SUMMARY_FILE="${VLARCH_UPDATE_SUMMARY_FILE:-/tmp/vlarch-update-summary.$$}"
export VLARCH_DRY_RUN VLARCH_VERBOSE VLARCH_INFO_FILE VLARCH_VERSION
export VLARCH_MANIFEST_DIR VLARCH_DOTFILES_DIR VLARCH_BIN_DIR VLARCH_UPDATE_SUMMARY_FILE

: >"$VLARCH_UPDATE_SUMMARY_FILE"

while (($#)); do
  case "$1" in
    --dry-run) VLARCH_DRY_RUN=1; shift ;;
    --verbose) VLARCH_VERBOSE=1; shift ;;
    --quiet)   VLARCH_VERBOSE=0; shift ;;
    --force)   shift ;;
    --help|-h)
      cat <<USAGE
Vlarch update
Usage: update.sh [--quiet|--verbose] [--dry-run] [--force] [--cdn-base URL] [--repo URL] [--branch REF]
USAGE
      exit 0
      ;;
    --cdn-base|--repo|--branch)
      shift 2
      ;;
    *) vlarch_die "unknown option: $1" ;;
  esac
done
export VLARCH_DRY_RUN VLARCH_VERBOSE

((VLARCH_VERBOSE)) && set -x

VLARCH_CURRENT_STEP="boot"
export VLARCH_CURRENT_STEP
trap 'vlarch_die "update failed in step ${VLARCH_CURRENT_STEP:-?}"' ERR

[[ "$(id -u)" -eq 0 ]] || vlarch_die "update must run as root"

vlarch_step "Vlarch ${VLARCH_VERSION} update"

shopt -s nullglob
mapfile -t VLARCH_STEPS < <(printf '%s\n' "${VLARCH_SCRIPT_DIR}/update/steps/"[0-9][0-9]_*.sh | sort)
shopt -u nullglob
((${#VLARCH_STEPS[@]})) || vlarch_die "no step scripts found in update/steps"

for step_path in "${VLARCH_STEPS[@]}"; do
  step_name="$(basename "$step_path" .sh)"
  VLARCH_CURRENT_STEP="$step_name"
  export VLARCH_CURRENT_STEP
  vlarch_step "Step: ${step_name}"
  bash "$step_path"
done

trap - ERR

printf '[vlarch] update complete (%s)\n' "${VLARCH_VERSION}"
if [[ -s "$VLARCH_UPDATE_SUMMARY_FILE" ]]; then
  while IFS= read -r line; do
    printf '[vlarch]   %s\n' "$line"
  done <"$VLARCH_UPDATE_SUMMARY_FILE"
fi
rm -f "$VLARCH_UPDATE_SUMMARY_FILE"
