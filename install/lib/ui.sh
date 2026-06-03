#!/usr/bin/env bash
# Nord-themed TTY UI for the Vlarch installer (256-color SGR, pure bash).
# Sourced after log.sh. Progress state lives in /tmp/vlarch-ui.state for subprocesses.

VLARCH_UI="${VLARCH_UI:-0}"
VLARCH_UI_STATE="${VLARCH_UI_STATE:-/tmp/vlarch-ui.state}"

# Nord palette (256-color indices)
VLARCH_ESC_RESET=$'\033[0m'
VLARCH_NORD_BG=$'\033[48;5;236m'
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
  [01_preflight]="Live environment checks"
  [02_collect_input]="Configuration"
  [03_partition]="Partition and encrypt disk"
  [04_pacstrap]="Install base system"
  [05_chroot_system]="Configure system locale"
  [06_chroot_users]="Create users"
  [07_chroot_boot]="Install bootloader"
  [08_chroot_aur]="Bootstrap yay"
  [09_dotfiles]="Install tty1 first-boot hooks (.zprofile, .zshrc)"
  [10_finalize]="Finalize installation"
)

vlarch_ui_enabled() {
  ((VLARCH_UI)) && !((VLARCH_VERBOSE))
}

vlarch_ui_disable() {
  VLARCH_UI=0
  export VLARCH_UI
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
  local runs chroots steps total
  runs=$(grep -rhE '^\s*vlarch_run ' "${VLARCH_SCRIPT_DIR}/install" 2>/dev/null | wc -l | tr -d ' ')
  chroots=$(grep -rh 'vlarch_chroot_run' "${VLARCH_SCRIPT_DIR}/install/steps" 2>/dev/null | wc -l | tr -d ' ')
  steps=${#VLARCH_STEPS[@]}
  ((steps < 1)) && steps=10
  total=$((runs + chroots + 1 + steps))
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
  local logo="${VLARCH_ASSETS_DIR:-}/ansi_logo.txt"
  if [[ -f "$logo" ]]; then
    printf '%b' "${VLARCH_NORD_BG}"
    cat "$logo"
    printf '%b\n' "${VLARCH_ESC_RESET}"
    return 0
  fi
  return 1
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
  local current total op_label width
  current=$(vlarch_ui_state_read current 0)
  total=$(vlarch_ui_state_read total 1)
  op_label=$(vlarch_ui_state_read op_label "")
  width=$(vlarch_ui_bar_width)

  if [[ -t 1 ]]; then
    clear || true
  fi
  vlarch_ui_print_logo || true
  printf '\n'
  vlarch_ui_say "${VLARCH_NORD_FG}" "Vlarch ${VLARCH_VERSION:-}"
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

vlarch_ui_tick_step_boundary() {
  vlarch_ui_enabled || return 0
  vlarch_ui_tick "starting step"
}
