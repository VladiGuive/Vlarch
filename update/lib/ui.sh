#!/usr/bin/env bash
# Nord-themed TTY UI for the Vlarch updater (256-color SGR, pure bash).
# Fixed quiet-mode frame: 10 lines x 50 columns.

VLARCH_UI="${VLARCH_UI:-0}"
VLARCH_UI_STATE="${VLARCH_UI_STATE:-/tmp/vlarch-update-ui.state}"
VLARCH_UI_WIDTH=50

VLARCH_ESC_RESET=$'\033[0m'
VLARCH_NORD_BG=$'\033[48;5;236m'
VLARCH_NORD_FG=$'\033[38;5;253m'
VLARCH_NORD_PCT_FILL=$'\033[38;5;236;48;5;109m'
VLARCH_NORD_PCT_EMPTY=$'\033[38;5;253;48;5;236m'
VLARCH_NORD_DIM=$'\033[38;5;245m'
VLARCH_NORD_RED=$'\033[38;5;174m'
VLARCH_NORD_GREEN=$'\033[38;5;150m'
VLARCH_NORD_YELLOW=$'\033[38;5;221m'
VLARCH_NORD_BLUE=$'\033[38;5;109m'
VLARCH_NORD_CYAN=$'\033[38;5;109m'
VLARCH_NORD_MAGENTA=$'\033[38;5;176m'
VLARCH_NORD_WHITE=$'\033[38;5;255m'

VLARCH_TERM_MAGENTA=$'\033[35m'
VLARCH_TERM_GREEN=$'\033[32m'
VLARCH_TERM_BRIGHT_GREEN=$'\033[92m'
VLARCH_TERM_BRIGHT_BLACK=$'\033[90m'

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
  printf '%s' "$VLARCH_UI_WIDTH"
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
  vlarch_ui_state_write last_log_line ""
}

vlarch_ui_print_logo() {
  local assets="${VLARCH_ASSETS_DIR:-${VLARCH_SCRIPT_DIR}/install/assets}"
  local plain="${assets}/logo.txt"

  if [[ -f "$plain" ]]; then
    printf '%b' "${VLARCH_NORD_CYAN}"
    cat "$plain"
    printf '%b' "${VLARCH_ESC_RESET}"
    return 0
  fi

  printf '%b' "${VLARCH_NORD_CYAN}"
  cat <<'LOGO'
 _   ____             __
| | / / /__ _________/ /
| |/ / / _ `/ __/ __/ _ \
|___/_/\_,_/_/  \__/_//_/
LOGO
  printf '%b' "${VLARCH_ESC_RESET}"
  return 0
}

vlarch_ui_say() {
  local color="$1"; shift
  printf '%b%b%b\n' "$color" "$*" "${VLARCH_ESC_RESET}"
}

# Truncate string to max visible characters (ellipsis if shortened).
vlarch_ui_truncate() {
  local s="$1" max="$2"
  if ((${#s} <= max)); then
    printf '%s' "$s"
    return 0
  fi
  if ((max < 4)); then
    printf '%s' "${s:0:max}"
    return 0
  fi
  printf '%s...' "${s:0:max-3}"
}

# Left text padded so right suffix ends at column width (both sides colored).
vlarch_ui_row_lr() {
  local left="$1" right="$2" width="$3" color="$4"
  local pad=$((width - ${#right}))
  ((pad < 1)) && pad=1
  if ((${#left} > pad)); then
    left="$(vlarch_ui_truncate "$left" "$pad")"
  fi
  printf '%b%-*s%s%b\n' "$color" "$pad" "$left" "$right" "${VLARCH_ESC_RESET}"
}

vlarch_ui_draw_bar() {
  local pct="$1"
  local width pct_str pct_len track filled i j c pos
  width=$(vlarch_ui_bar_width)
  pct_str=$(printf '%d%%' "$pct")
  pct_len=${#pct_str}
  track=$((width - pct_len))
  ((track < 1)) && track=1
  filled=$((pct * width / 100))
  ((filled > width)) && filled=$width

  for ((i = 0; i < track; i++)); do
    if ((i < filled)); then
      printf '%b█' "${VLARCH_NORD_CYAN}"
    else
      printf '%b░' "${VLARCH_NORD_DIM}"
    fi
  done

  for ((j = 0; j < pct_len; j++)); do
    c="${pct_str:j:1}"
    pos=$((track + j))
    if ((pos < filled)); then
      printf '%b%b%c' "${VLARCH_NORD_PCT_FILL}" "${VLARCH_ESC_RESET}" "$c"
    else
      printf '%b%b%c' "${VLARCH_NORD_PCT_EMPTY}" "${VLARCH_ESC_RESET}" "$c"
    fi
  done
  printf '%b' "${VLARCH_ESC_RESET}"
}

vlarch_ui_render_frame() {
  local step_idx="$1" step_total="$2" title="$3" macro_pct="$4"
  local current total op_label width to_ver last_log ver_line
  current=$(vlarch_ui_state_read current 0)
  total=$(vlarch_ui_state_read total 1)
  op_label=$(vlarch_ui_state_read op_label "")
  to_ver=$(vlarch_ui_state_read to_version "${VLARCH_VERSION:-}")
  last_log=$(vlarch_ui_state_read last_log_line "")
  width=$VLARCH_UI_WIDTH

  if [[ -t 1 ]]; then
    clear || true
  fi

  # Lines 1-4: logo
  vlarch_ui_print_logo || true

  # Line 5: target version
  ver_line=" → ${to_ver:-${VLARCH_VERSION:-update}}"
  vlarch_ui_say "${VLARCH_TERM_MAGENTA}" "$ver_line"

  # Line 6: blank
  printf '\n'

  # Line 7: step
  vlarch_ui_row_lr "$title" "Step ${step_idx}/${step_total}" "$width" "${VLARCH_TERM_GREEN}"

  # Line 8: substep (blank when no op_label)
  if [[ -n "$op_label" ]]; then
    vlarch_ui_row_lr "▸ ${op_label}" "${current}/${total}" "$width" "${VLARCH_TERM_BRIGHT_GREEN}"
  else
    printf '\n'
  fi

  # Line 9: last log line
  if [[ -n "$last_log" ]]; then
    vlarch_ui_say "${VLARCH_TERM_BRIGHT_BLACK}" "$(vlarch_ui_truncate "$last_log" "$width")"
  else
    printf '\n'
  fi

  # Line 10: progress bar (no trailing newline; frame ends at 50 cols)
  vlarch_ui_draw_bar "$macro_pct"
  printf '\n'
}

vlarch_ui_rerender() {
  local step_idx step_total title macro_pct
  step_idx=$(vlarch_ui_state_read step_index 1)
  step_total=$(vlarch_ui_state_read step_total 1)
  title=$(vlarch_ui_state_read step_title "Working")
  macro_pct=$((step_idx * 100 / step_total))
  ((macro_pct > 100)) && macro_pct=100
  vlarch_ui_render_frame "$step_idx" "$step_total" "$title" "$macro_pct"
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
  vlarch_ui_state_write last_log_line ""
  vlarch_ui_render_frame "$step_idx" "$step_total" "$title" "$macro_pct"
}

vlarch_ui_set_op_label() {
  local label="$1"
  vlarch_ui_enabled || return 0
  vlarch_ui_state_write op_label "$label"
  vlarch_ui_rerender
}

vlarch_ui_set_last_log() {
  local line="$1"
  vlarch_ui_enabled || return 0
  [[ -n "$line" ]] || return 0
  vlarch_ui_state_write last_log_line "$line"
  vlarch_ui_rerender
}

vlarch_ui_tick() {
  local label="$1"
  local current
  vlarch_ui_enabled || return 0
  current=$(vlarch_ui_state_read current 0)
  current=$((current + 1))
  vlarch_ui_state_write current "$current"
  vlarch_ui_state_write op_label "$label"
  vlarch_ui_rerender
}

vlarch_ui_set_versions() {
  local from="$1" to="$2"
  vlarch_ui_state_write from_version "$from"
  vlarch_ui_state_write to_version "$to"
}

vlarch_ui_show_complete() {
  local ver_line
  if [[ -t 1 ]]; then
    clear || true
  fi
  vlarch_ui_print_logo || true
  ver_line=" → ${VLARCH_VERSION:-}"
  vlarch_ui_say "${VLARCH_TERM_MAGENTA}" "$ver_line"
  printf '\n'
  vlarch_ui_say "${VLARCH_TERM_GREEN}" "Update complete"
  printf '\n'
  printf '\n'
  vlarch_ui_draw_bar 100
  printf '\n'
}
