#!/usr/bin/env bash
# Install orchestrator. Sources libs, runs install/steps/NN_*.sh in order,
# emits a final summary, and prompts for reboot.
set -euo pipefail

[[ -n "${VLARCH_SCRIPT_DIR:-}" && -d "${VLARCH_SCRIPT_DIR}" ]] \
  || { printf '[vlarch] error: VLARCH_SCRIPT_DIR not set\n' >&2; exit 1; }

# shellcheck disable=SC1091
source "${VLARCH_SCRIPT_DIR}/install/lib/log.sh"
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
VLARCH_MANIFEST_DIR="${VLARCH_MANIFEST_DIR:-${VLARCH_SCRIPT_DIR}/install/packages}"
VLARCH_DOTFILES_DIR="${VLARCH_DOTFILES_DIR:-${VLARCH_SCRIPT_DIR}/install/dotfiles}"
VLARCH_ASSETS_DIR="${VLARCH_ASSETS_DIR:-${VLARCH_SCRIPT_DIR}/install/assets}"
VLARCH_BIN_DIR="${VLARCH_BIN_DIR:-${VLARCH_SCRIPT_DIR}/bin}"
export VLARCH_DRY_RUN VLARCH_VERBOSE VLARCH_CONFIG_FILE VLARCH_VERSION
export VLARCH_MANIFEST_DIR VLARCH_DOTFILES_DIR VLARCH_ASSETS_DIR VLARCH_BIN_DIR

while (($#)); do
  case "$1" in
    --dry-run) VLARCH_DRY_RUN=1; shift ;;
    --verbose) VLARCH_VERBOSE=1; shift ;;
    --repo)    [[ $# -ge 2 ]] || vlarch_die "--repo requires a URL";    export VLARCH_GIT_URL="$2";    shift 2 ;;
    --branch)  [[ $# -ge 2 ]] || vlarch_die "--branch requires a ref";  export VLARCH_GIT_BRANCH="$2"; shift 2 ;;
    --help|-h)
      cat <<USAGE
Vlarch installer
Usage: install.sh [--dry-run] [--verbose] [--repo URL] [--branch REF]

  --dry-run   Stop after collect_input; print the captured config.
  --verbose   Show vlarch_info messages.
  --repo URL  Override clone source (passed through by install.sh).
  --branch R  Override clone ref (passed through by install.sh).
USAGE
      exit 0
      ;;
    *) vlarch_die "unknown option: $1" ;;
  esac
done
export VLARCH_DRY_RUN VLARCH_VERBOSE

((VLARCH_VERBOSE)) && set -x

VLARCH_CURRENT_STEP="boot"
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

for step_path in "${VLARCH_STEPS[@]}"; do
  step_name="$(basename "$step_path" .sh)"
  VLARCH_CURRENT_STEP="$step_name"
  vlarch_step "Step: ${step_name}"
  bash "$step_path"
  if ((VLARCH_DRY_RUN)) && [[ "$step_name" == 02_collect_input ]]; then
    vlarch_step "Dry-run requested; stopping after ${step_name}"
    if [[ -f "$VLARCH_CONFIG_FILE" ]]; then
      vlarch_info "Captured config (${VLARCH_CONFIG_FILE}):"
      sed 's/^/  /' "$VLARCH_CONFIG_FILE"
    fi
    exit 0
  fi
done

trap - ERR

vlarch_step "Install summary"
if [[ -f "$VLARCH_CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$VLARCH_CONFIG_FILE"
  printf '  user:      %s\n' "${VLARCH_USER:-?}"
  printf '  disk:      %s\n' "${VLARCH_DISK:-?}"
  printf '  timezone:  %s\n' "${VLARCH_TIMEZONE:-?}"
  printf '  locale:    %s\n' "${VLARCH_LOCALE:-?}"
  printf '  partitions: EFI=%s BOOT=%s LUKS=%s\n' \
    "${VLARCH_PART_EFI:-?}" "${VLARCH_PART_BOOT:-?}" "${VLARCH_PART_LUKS:-?}"
fi

printf '\nInstall complete. Press Enter to reboot, or Ctrl-C to drop to a shell...\n'
if read -r _; then
  vlarch_partition_unmount
  reboot
else
  vlarch_warn "no interactive input; not rebooting automatically"
fi
