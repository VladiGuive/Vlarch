#!/usr/bin/env bash
# Install orchestrator. Sources libs and runs install/steps/NN_*.sh in order.
# Silent during normal operation; only fatal errors print (with the tail of
# the captured tool output to make them debuggable). --verbose restores the
# previous loud behavior plus `set -x`.
set -euo pipefail

[[ -n "${VLARCH_SCRIPT_DIR:-}" && -d "${VLARCH_SCRIPT_DIR}" ]] \
  || { printf '[vlarch] error: VLARCH_SCRIPT_DIR not set\n' >&2; exit 1; }

# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/log.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/ui.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/config.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/live.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/partition.sh"
# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/chroot.sh"

VLARCH_DRY_RUN="${VLARCH_DRY_RUN:-0}"
VLARCH_VERBOSE="${VLARCH_VERBOSE:-0}"
VLARCH_CONFIG_FILE="${VLARCH_CONFIG_FILE:-/tmp/vlarch-install.env}"
VLARCH_VERSION="${VLARCH_VERSION:-0.0.0-dev}"
VLARCH_ASSETS_DIR="${VLARCH_ASSETS_DIR:-${VLARCH_SCRIPT_DIR}/install/assets}"
VLARCH_BIN_DIR="${VLARCH_BIN_DIR:-${VLARCH_SCRIPT_DIR}/bin}"
export VLARCH_DRY_RUN VLARCH_VERBOSE VLARCH_CONFIG_FILE VLARCH_VERSION
export VLARCH_ASSETS_DIR VLARCH_BIN_DIR

while (($#)); do
  case "$1" in
    --dry-run) VLARCH_DRY_RUN=1; shift ;;
    --verbose) VLARCH_VERBOSE=1; shift ;;
    --quiet)   VLARCH_VERBOSE=0; shift ;;
    --repo)    [[ $# -ge 2 ]] || vlarch_die "--repo requires a URL";    export VLARCH_GIT_URL="$2";    shift 2 ;;
    --branch)  [[ $# -ge 2 ]] || vlarch_die "--branch requires a ref";  export VLARCH_GIT_BRANCH="$2"; shift 2 ;;
    --help|-h)
      cat <<USAGE
Vlarch installer
Usage: install.sh [--quiet|--verbose] [--dry-run] [--repo URL] [--branch REF]

  --quiet     Silent except on fatal errors (default).
  --verbose   Stream every command's output and enable bash xtrace.
  --dry-run   Stop after collect_input; print the captured config.
  --repo URL  Override clone source (passed through by install.sh).
  --branch R  Override clone ref (passed through by install.sh).

On a fatal error vlarch always prints the failure reason and the last 20
lines of the captured tool log; the full log path is printed too so you
can inspect it without re-running.
USAGE
      exit 0
      ;;
    *) vlarch_die "unknown option: $1" ;;
  esac
done
export VLARCH_DRY_RUN VLARCH_VERBOSE

((VLARCH_VERBOSE)) && set -x

VLARCH_CURRENT_STEP="boot"
export VLARCH_CURRENT_STEP
trap 'vlarch_die "install failed in step ${VLARCH_CURRENT_STEP:-?}"' ERR

if [[ "$(id -u)" -ne 0 ]]; then
  vlarch_die "install must run as root from the live ISO"
fi

vlarch_step "Vlarch ${VLARCH_VERSION} installer"

# Run every install/steps/NN_*.sh in lexical order. Each step is a subprocess so
# its `set -e` cannot leak into the orchestrator; persisted state flows through
# /tmp/vlarch-install.env which steps source/save themselves.
shopt -s nullglob
mapfile -t VLARCH_STEPS < <(printf '%s\n' "${VLARCH_SCRIPT_DIR}/install/steps/"[0-9][0-9]_*.sh | sort)
shopt -u nullglob
((${#VLARCH_STEPS[@]})) || vlarch_die "no step scripts found in install/steps"

vlarch_ui_init
export VLARCH_SCRIPT_DIR
step_idx=0
step_total=${#VLARCH_STEPS[@]}

for step_path in "${VLARCH_STEPS[@]}"; do
  step_name="$(basename "$step_path" .sh)"
  VLARCH_CURRENT_STEP="$step_name"
  export VLARCH_CURRENT_STEP
  step_idx=$((step_idx + 1))
  vlarch_step "Step: ${step_name}"

  case "$step_name" in
    01_preflight|02_collect_input)
      VLARCH_UI=0
      ;;
    *)
      export VLARCH_UI=1
      if vlarch_ui_enabled; then
        vlarch_ui_begin_step "$step_idx" "$step_total" "$step_name"
      fi
      ;;
  esac
  export VLARCH_UI

  if [[ "$step_name" == 09_dotfiles ]]; then
    vlarch_install_wallpapers
  fi

  bash "$step_path"
  if ((VLARCH_DRY_RUN)) && [[ "$step_name" == 02_collect_input ]]; then
    if [[ -f "$VLARCH_CONFIG_FILE" ]]; then
      printf '[vlarch] dry-run: captured config at %s\n' "$VLARCH_CONFIG_FILE"
      sed 's/^/  /' "$VLARCH_CONFIG_FILE"
    fi
    exit 0
  fi
done

trap - ERR

# Reboot automatically when install completes.
if declare -F vlarch_ui_say >/dev/null 2>&1 && !((VLARCH_VERBOSE)); then
  clear || true
  vlarch_ui_print_logo || true
  printf '\n'
  vlarch_ui_say "${VLARCH_NORD_GREEN}" "Install complete. Rebooting..."
else
  printf '\n[vlarch] Install complete. Rebooting...\n'
fi
sleep 2
vlarch_partition_unmount
reboot
