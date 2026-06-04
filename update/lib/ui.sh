#!/usr/bin/env bash
# Nord-themed TTY UI for the Vlarch updater (256-color SGR, pure bash).
# Fixed quiet-mode frame: 10 lines x 50 columns.

VLARCH_UI="${VLARCH_UI:-0}"
VLARCH_UI_STATE="${VLARCH_UI_STATE:-/tmp/vlarch-update-ui.state}"
VLARCH_UI_WIDTH=50
VLARCH_UI_LINES=10

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
VLARCH_ESC_HIDE_CURSOR=$'\033[?25l'
VLARCH_ESC_SHOW_CURSOR=$'\033[?25h'

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

# Resize TTY / terminal window to the fixed UI grid (50 cols x 10 rows).
vlarch_ui_tty_resize() {
  [[ -t 1 ]] || return 0
  stty cols "$VLARCH_UI_WIDTH" rows "$VLARCH_UI_LINES" 2>/dev/null || true
  printf '\033[8;%d;%dt' "$VLARCH_UI_LINES" "$VLARCH_UI_WIDTH"
}

# Right-aligned counter (e.g. " 4/33") with stable width for the step digits.
vlarch_ui_format_ratio() {
  local cur="$1" tot="$2"
  printf '%*d/%d' "${#tot}" "$cur" "$tot"
}

# Width of the "cur/tot" field (e.g. " 4/7" or "11/33").
vlarch_ui_frac_field_width() {
  local tot="$1"
  printf '%s' $(( ${#tot} * 2 + 1 ))
}

# Suffix width for step/substep rows ("Step " + cur/tot field).
vlarch_ui_suffix_width() {
  local run_total="$1" step_total="$2"
  local fw_run fw_step fw
  fw_run=$(vlarch_ui_frac_field_width "$run_total")
  fw_step=$(vlarch_ui_frac_field_width "$step_total")
  fw=$fw_run
  ((fw_step > fw)) && fw=$fw_step
  printf '%s' $((5 + fw))
}

vlarch_ui_step_suffix() {
  local step_idx="$1" step_total="$2" frac_w="$3"
  local frac
  frac="$(vlarch_ui_format_ratio "$step_idx" "$step_total")"
  printf 'Step %*s' "$frac_w" "$frac"
}

vlarch_ui_run_suffix() {
  local current="$1" run_total="$2" frac_w="$3"
  local frac
  frac="$(vlarch_ui_format_ratio "$current" "$run_total")"
  # Five spaces under "Step "; %5s '' does not pad in bash.
  printf '%*s%*s' 5 '' "$frac_w" "$frac"
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
  vlarch_ui_tty_resize
  rm -f "$VLARCH_UI_STATE"
  vlarch_ui_state_write frac_field_width "$(vlarch_ui_frac_field_width "$total")"
  vlarch_ui_state_write suffix_width "$(vlarch_ui_suffix_width "$total" "$steps")"
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

# Left text + right suffix in a fixed-width right column (both sides colored).
vlarch_ui_row_lr() {
  local left="$1" right="$2" width="$3" color="$4"
  local suffix_w="${5:-$(vlarch_ui_state_read suffix_width 8)}"
  local left_w right_pad
  left_w=$((width - suffix_w))
  ((left_w < 1)) && left_w=1
  if ((${#left} > left_w)); then
    left="$(vlarch_ui_truncate "$left" "$left_w")"
  fi
  printf -v right_pad '%*s' "$suffix_w" "$right"
  printf '%b%-*s%s%b\n' "$color" "$left_w" "$left" "$right_pad" "${VLARCH_ESC_RESET}"
}

# Substep row: ▸ is one terminal column but three bytes — add two pad spaces for full width.
vlarch_ui_row_lr_sub() {
  local left="$1" right="$2" width="$3" color="$4" suffix_w="$5"
  local left_w right_pad
  left_w=$((width - suffix_w + 2))
  ((left_w < 1)) && left_w=1
  if ((${#left} > left_w)); then
    left="$(vlarch_ui_truncate "$left" "$left_w")"
  fi
  printf -v right_pad '%*s' "$suffix_w" "$right"
  printf '%b%-*s%s%b\n' "$color" "$left_w" "$left" "$right_pad" "${VLARCH_ESC_RESET}"
}

# End of 10-line frame: hide cursor on last line (no extra row below).
vlarch_ui_finish_frame() {
  [[ -t 1 ]] || return 0
  printf '%b\033[%d;1H' "${VLARCH_ESC_HIDE_CURSOR}" "$VLARCH_UI_LINES"
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
    vlarch_ui_tty_resize
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
  local frac_w suffix_w
  frac_w=$(vlarch_ui_state_read frac_field_width 5)
  suffix_w=$(vlarch_ui_state_read suffix_width 8)
  vlarch_ui_row_lr "$title" "$(vlarch_ui_step_suffix "$step_idx" "$step_total" "$frac_w")" "$width" "${VLARCH_TERM_GREEN}" "$suffix_w"

  # Line 8: substep (blank when no op_label); cur/tot aligns under step fraction
  if [[ -n "$op_label" ]]; then
    vlarch_ui_row_lr_sub "▸ ${op_label}" "$(vlarch_ui_run_suffix "$current" "$total" "$frac_w")" "$width" "${VLARCH_TERM_BRIGHT_GREEN}" "$suffix_w"
  else
    printf '\n'
  fi

  # Line 9: last log line
  if [[ -n "$last_log" ]]; then
    vlarch_ui_say "${VLARCH_TERM_BRIGHT_BLACK}" "$(vlarch_ui_truncate "$last_log" "$width")"
  else
    printf '\n'
  fi

  # Line 10: progress bar (full width; cursor hidden on this line)
  vlarch_ui_draw_bar "$macro_pct"
  vlarch_ui_finish_frame
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
    vlarch_ui_tty_resize
    clear || true
  fi
  vlarch_ui_print_logo || true
  ver_line=" → ${VLARCH_VERSION:-}"
  vlarch_ui_say "${VLARCH_TERM_MAGENTA}" "$ver_line"
  printf '\n'
  vlarch_ui_say "${VLARCH_TERM_GREEN}" "Update complete"
  printf '%bEnter%b → reboot.\n' "${VLARCH_TERM_BRIGHT_GREEN}" "${VLARCH_ESC_RESET}"
  printf '%bEsc%b → close.\n' "${VLARCH_TERM_BRIGHT_GREEN}" "${VLARCH_ESC_RESET}"
  vlarch_ui_draw_bar 100
  vlarch_ui_finish_frame
}

