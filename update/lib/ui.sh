#!/usr/bin/env bash
# Nord-themed TTY UI for the Vlarch updater (256-color SGR, pure bash).

VLARCH_UI="${VLARCH_UI:-0}"
VLARCH_UI_STATE="${VLARCH_UI_STATE:-/tmp/vlarch-update-ui.state}"

VLARCH_ESC_RESET=$'\033[0m'
VLARCH_NORD_FG=$'\033[38;5;253m'
VLARCH_NORD_DIM=$'\033[38;5;245m'
VLARCH_NORD_RED=$'\033[38;5;174m'
VLARCH_NORD_GREEN=$'\033[38;5;150m'
VLARCH_NORD_YELLOW=$'\033[38;5;221m'
VLARCH_NORD_BLUE=$'\033[38;5;109m'
VLARCH_NORD_CYAN=$'\033[38;5;109m'
VLARCH_NORD_MAGENTA=$'\033[38;5;176m'
VLARCH_NORD_WHITE=$'\033[38;5;255m'

declare -gA VLARCH_STEP_TITLES=(
  [01_preflight]="Preflight checks"
  [02_packages]="Package sync"
  [03_dotfiles]="Dotfiles and tmux"
  [04_hyprpm]="Hyprland plugins"
  [05_grub_snapshots]="GRUB snapshot menu"
  [06_finalize]="Finalize update"
  [07_getty_login]="Configure tty1 autologin"
)

vlarch_ui_enabled() {
  ((VLARCH_UI)) && !((VLARCH_VERBOSE))
}

vlarch_ui_bar_width() {
  local w="${COLUMNS:-80}"
  ((w > 52)) && w=48
  ((w < 24)) && w=24
  printf '%s' "$w"
}

vlarch_ui_state_write() {
  local key="$1" val="$2"
  local tmp="${VLARCH_UI_STATE}.$$"
  if [[ -f "$VLARCH_UI_STATE" ]]; then
    grep -v "^${key}=" "$VLARCH_UI_STATE" >"$tmp" 2>/dev/null || : >"$tmp"
  else
    : >"$tmp"
  fi
  printf '%s=%s\n' "$key" "$val" >>"$tmp"
  mv -f "$tmp" "$VLARCH_UI_STATE"
}

vlarch_ui_state_read() {
  local key="$1" default="${2:-0}"
  local line
  [[ -f "$VLARCH_UI_STATE" ]] || { printf '%s' "$default"; return; }
  line=$(grep -m1 "^${key}=" "$VLARCH_UI_STATE" 2>/dev/null) || true
  [[ -n "$line" ]] || { printf '%s' "$default"; return; }
  printf '%s' "${line#*=}"
}

vlarch_ui_init() {
  local runs steps total
  runs=$(grep -rhE '^\s*vlarch_run ' "${VLARCH_SCRIPT_DIR}/update" 2>/dev/null | wc -l | tr -d ' ')
  steps=${#VLARCH_STEPS[@]}
  ((steps < 1)) && steps=5
  total=$((runs + steps))
  ((total < 1)) && total=1
  rm -f "$VLARCH_UI_STATE"
  vlarch_ui_state_write total "$total"
  vlarch_ui_state_write current 0
  vlarch_ui_state_write step_index 0
  vlarch_ui_state_write step_total "$steps"
  vlarch_ui_state_write step_title ""
  vlarch_ui_state_write op_label ""
}

vlarch_ui_print_logo() {
  local assets="${VLARCH_ASSETS_DIR:-${VLARCH_SCRIPT_DIR}/install/assets}"
  local plain="${assets}/logo.txt"

  if [[ -f "$plain" ]]; then
    printf '%b' "${VLARCH_NORD_CYAN}"
    cat "$plain"
    printf '%b\n' "${VLARCH_ESC_RESET}"
    return 0
  fi

  printf '%b' "${VLARCH_NORD_CYAN}"
  cat <<'LOGO'
 _   ____             __
| | / / /__ _________/ /
| |/ / / _ `/ __/ __/ _ \
|___/_/\_,_/_/  \__/_//_/
LOGO
  printf '%b\n' "${VLARCH_ESC_RESET}"
  return 0
}

vlarch_ui_say() {
  local color="$1"; shift
  printf '%b%b%b\n' "$color" "$*" "${VLARCH_ESC_RESET}"
}

vlarch_ui_draw_bar() {
  local pct="$1" width filled empty i
  width=$(vlarch_ui_bar_width)
  filled=$((pct * width / 100))
  ((filled > width)) && filled=$width
  empty=$((width - filled))
  printf '%b' "${VLARCH_NORD_CYAN}"
  for ((i = 0; i < filled; i++)); do printf '█'; done
  printf '%b' "${VLARCH_NORD_DIM}"
  for ((i = 0; i < empty; i++)); do printf '░'; done
  printf '%b' "${VLARCH_ESC_RESET}"
}

vlarch_ui_render_frame() {
  local step_idx="$1" step_total="$2" title="$3" macro_pct="$4"
  local current total op_label width from_ver to_ver
  current=$(vlarch_ui_state_read current 0)
  total=$(vlarch_ui_state_read total 1)
  op_label=$(vlarch_ui_state_read op_label "")
  from_ver=$(vlarch_ui_state_read from_version "")
  to_ver=$(vlarch_ui_state_read to_version "${VLARCH_VERSION:-}")
  width=$(vlarch_ui_bar_width)

  if [[ -t 1 ]]; then
    clear || true
  fi
  vlarch_ui_print_logo || true
  printf '\n'
  if [[ -n "$from_ver" && -n "$to_ver" ]]; then
    vlarch_ui_say "${VLARCH_NORD_FG}" "Updating ${from_ver} → ${to_ver}"
  else
    vlarch_ui_say "${VLARCH_NORD_FG}" "Vlarch ${VLARCH_VERSION:-update}"
  fi
  printf '%b%-*s%b Step %s/%s\n' \
    "${VLARCH_NORD_FG}" "$((width - 12))" "$title" "${VLARCH_ESC_RESET}" \
    "$step_idx" "$step_total"
  vlarch_ui_draw_bar "$macro_pct"
  printf '  %3s%%\n' "$macro_pct"
  printf '\n'
  if [[ -n "$op_label" ]]; then
    printf '%b▸ %-*s%b %s/%s\n' \
      "${VLARCH_NORD_GREEN}" "$((width - 8))" "$op_label" "${VLARCH_ESC_RESET}" \
      "$current" "$total"
  fi
}

vlarch_ui_begin_step() {
  local step_idx="$1" step_total="$2" step_name="$3"
  local title="${VLARCH_STEP_TITLES[$step_name]:-$step_name}"
  local macro_pct=$((step_idx * 100 / step_total))
  ((macro_pct > 100)) && macro_pct=100
  vlarch_ui_state_write step_index "$step_idx"
  vlarch_ui_state_write step_total "$step_total"
  vlarch_ui_state_write step_title "$title"
  vlarch_ui_state_write op_label ""
  vlarch_ui_render_frame "$step_idx" "$step_total" "$title" "$macro_pct"
}

vlarch_ui_tick() {
  local label="$1"
  local current total step_idx step_total title macro_pct
  vlarch_ui_enabled || return 0
  current=$(vlarch_ui_state_read current 0)
  current=$((current + 1))
  vlarch_ui_state_write current "$current"
  vlarch_ui_state_write op_label "$label"
  total=$(vlarch_ui_state_read total 1)
  step_idx=$(vlarch_ui_state_read step_index 1)
  step_total=$(vlarch_ui_state_read step_total 1)
  title=$(vlarch_ui_state_read step_title "Working")
  macro_pct=$((step_idx * 100 / step_total))
  ((macro_pct > 100)) && macro_pct=100
  vlarch_ui_render_frame "$step_idx" "$step_total" "$title" "$macro_pct"
}

vlarch_ui_set_versions() {
  local from="$1" to="$2"
  vlarch_ui_state_write from_version "$from"
  vlarch_ui_state_write to_version "$to"
}

vlarch_ui_show_complete() {
  if [[ -t 1 ]]; then
    clear || true
  fi
  vlarch_ui_print_logo || true
  printf '\n'
  vlarch_ui_say "${VLARCH_NORD_GREEN}" "Update complete (${VLARCH_VERSION:-})"
  vlarch_ui_draw_bar 100
  printf '  100%%\n\n'
}
