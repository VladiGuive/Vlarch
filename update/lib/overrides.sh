#!/usr/bin/env bash
# User dotfile overrides. Sourced - no set -e here.
# ~/.overrides mirrors $HOME paths and is applied after each dotfiles deploy.

VLARCH_OVERRIDE_APPEND_BEGIN='# vlarch:overrides:append'
VLARCH_OVERRIDE_APPEND_END='# vlarch:overrides:end'

# Overwrite in place so Hyprland's config watcher keeps the same inode (mv breaks reload).
vlarch_override_commit_file() {
  local target="$1" tmp="$2"
  cp -- "$tmp" "$target"
  rm -f "$tmp"
}

vlarch_override_normalize_line() {
  local line="$1"
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  printf '%s' "$line"
}

vlarch_override_line_key() {
  local line="$1" key
  line="$(vlarch_override_normalize_line "$line")"
  [[ "$line" == *"="* ]] || return 1
  key="${line%%=*}"
  key="${key%"${key##*[![:space:]]}"}"
  [[ -n "$key" ]] || return 1
  printf '%s' "$key"
}

# Returns 0 for explicit "old -> new" rules; 1 for key-only rules.
vlarch_override_parse_replace_rule() {
  local line="$1"
  local -n _old="$2"
  local -n _new="$3"
  local normalized

  normalized="$(vlarch_override_normalize_line "$line")"
  if [[ "$normalized" == *" -> "* ]]; then
    _old="${normalized%% -> *}"
    _old="${_old%"${_old##*[![:space:]]}"}"
    _new="${normalized#* -> }"
    _new="${_new#"${_new%%[![:space:]]*}"}"
    return 0
  fi

  _old=""
  _new="$line"
  return 1
}

vlarch_override_count_key_matches() {
  local target="$1" key="$2"
  local count=0 line k

  while IFS= read -r line || [[ -n "$line" ]]; do
    k="$(vlarch_override_line_key "$line")" || continue
    [[ "$k" == "$key" ]] && count=$((count + 1))
  done <"$target"
  printf '%s' "$count"
}

vlarch_override_bootstrap_dir() {
  local user="$1"
  local home="/home/${user}"
  local overrides_dir="${home}/.overrides"
  local readme="${overrides_dir}/README.md"

  if [[ ! -d "$overrides_dir" ]]; then
    install -d -m0755 -o "$user" -g "$user" "$overrides_dir"
  fi

  if [[ ! -f "$readme" ]]; then
    install -m0644 -o "$user" -g "$user" /dev/stdin "$readme" <<'README'
# Vlarch overrides

Files here patch managed dotfiles after each `vlarch update`. Paths mirror your home directory:

- `~/.overrides/.zshrc` → `~/.zshrc`
- `~/.overrides/.config/hypr/hyprland.conf` → `~/.config/hypr/hyprland.conf`

## Sections

**`!!!` — replace** lines in the target file.

Unique keys (text before `=`) can be replaced directly:

```
!!!
    kb_layout = latam
```

When several lines share the same key (e.g. many `bindd = …`), use an explicit
`old -> new` rule so only the intended line changes:

```
!!!
    bindd = , Print, Screenshot full screen to clipboard, exec, grim - | wl-copy -> bindd = , Print, Screenshot all screens to file, exec, bash -c 'dir="$HOME/Pictures/Screenshots"; mkdir -p "$dir"; grim "$dir/$(date +%Y_%m_%d_%H_%M_%S).png"'
```

**`@@@` — append** lines at the end inside a managed block (safe across updates):

```
@@@
exec-once = ~/.local/bin/my-startup.sh
```

## Example

`~/.overrides/.config/hypr/hyprland.conf` — keyboard, one keybind, and a personal startup script:

```
!!!
    kb_layout = latam
    bindd = , Print, Screenshot full screen to clipboard, exec, grim - | wl-copy -> bindd = , Print, Screenshot all screens to file, exec, bash -c 'dir="$HOME/Pictures/Screenshots"; mkdir -p "$dir"; grim "$dir/$(date +%Y_%m_%d_%H_%M_%S).png"'
@@@
exec-once = ~/.local/bin/my-startup.sh
```

`~/.overrides/.zshrc` — add aliases without touching the managed file:

```
@@@
alias gs='git status'
alias gc='git commit'
```

After saving, run `vlarch overrides` or `vlarch update` to apply. Hyprland
configs are reloaded automatically; if a stale error bar remains, run
`hyprctl seterror disable && hyprctl reload`.
README
  fi
}

vlarch_override_skip_file() {
  local rel="$1"
  case "$rel" in
    README|README.md) return 0 ;;
  esac
  return 1
}

vlarch_override_target_for() {
  local home="$1" overrides_dir="$2" override_file="$3"
  local rel="${override_file#"${overrides_dir}/"}"
  [[ -n "$rel" && "$rel" != "$override_file" ]] || return 1
  vlarch_override_skip_file "$rel" && return 1
  printf '%s/%s' "$home" "$rel"
}

vlarch_override_parse_sections() {
  local override_file="$1"
  local -n _replace="$2"
  local -n _append="$3"
  local mode="" line trimmed

  _replace=()
  _append=()

  while IFS= read -r line || [[ -n "$line" ]]; do
    trimmed="${line#"${line%%[![:space:]]*}"}"
    trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
    case "$trimmed" in
      '!!!') mode=replace; continue ;;
      '@@@') mode=append; continue ;;
    esac
    case "$mode" in
      replace) _replace+=("$line") ;;
      append) _append+=("$line") ;;
    esac
  done <"$override_file"
}

vlarch_override_apply_replace() {
  local target="$1"
  local -n _lines="$2"
  local -A key_replacements=()
  local -a explicit_old=() explicit_new=()
  local line old new key tmp normalized count matched

  (( ${#_lines[@]} > 0 )) || return 0

  for line in "${_lines[@]}"; do
    if vlarch_override_parse_replace_rule "$line" old new; then
      explicit_old+=("$old")
      explicit_new+=("$new")
      continue
    fi
    key="$(vlarch_override_line_key "$line")" || continue
    count="$(vlarch_override_count_key_matches "$target" "$key")"
    if ((count == 1)); then
      key_replacements["$key"]="$new"
    elif declare -F vlarch_warn >/dev/null 2>&1; then
      if ((count == 0)); then
        vlarch_warn "override replace: no match for key '${key}' in ${target}"
      else
        vlarch_warn "override replace: key '${key}' is ambiguous in ${target}; use 'old -> new'"
      fi
    fi
  done

  tmp="$(mktemp)"
  while IFS= read -r line || [[ -n "$line" ]]; do
    normalized="$(vlarch_override_normalize_line "$line")"
    matched=0

    for i in "${!explicit_old[@]}"; do
      [[ "${explicit_old[$i]}" == "$normalized" ]] || continue
      printf '%s\n' "${explicit_new[$i]}" >>"$tmp"
      unset 'explicit_old[$i]'
      matched=1
      break
    done
    ((matched)) && continue

    key="$(vlarch_override_line_key "$line")" || {
      printf '%s\n' "$line" >>"$tmp"
      continue
    }
    if [[ -n "${key_replacements[$key]+x}" ]]; then
      printf '%s\n' "${key_replacements[$key]}" >>"$tmp"
      unset 'key_replacements[$key]'
    else
      printf '%s\n' "$line" >>"$tmp"
    fi
  done <"$target"
  vlarch_override_commit_file "$target" "$tmp"

  if declare -F vlarch_warn >/dev/null 2>&1; then
    for key in "${!key_replacements[@]}"; do
      vlarch_warn "override replace: key '${key}' not applied in ${target}"
    done
    for i in "${!explicit_old[@]}"; do
      [[ -n "${explicit_old[$i]+x}" ]] \
        && vlarch_warn "override replace: no exact match for '${explicit_old[$i]}' in ${target}"
    done
  fi
}

vlarch_override_strip_append_block() {
  local target="$1"
  local tmp
  tmp="$(mktemp)"
  awk -v begin="$VLARCH_OVERRIDE_APPEND_BEGIN" -v end="$VLARCH_OVERRIDE_APPEND_END" '
    $0 == begin { skip = 1; next }
    $0 == end { skip = 0; next }
    !skip { print }
  ' "$target" >"$tmp"
  vlarch_override_commit_file "$target" "$tmp"
}

vlarch_override_apply_append() {
  local target="$1"
  local -n _lines="$2"
  local line

  vlarch_override_strip_append_block "$target"
  (( ${#_lines[@]} > 0 )) || return 0

  if [[ -s "$target" ]] && [[ -n "$(tail -c1 "$target" 2>/dev/null || true)" ]]; then
    printf '\n' >>"$target"
  fi
  {
    printf '%s\n' "$VLARCH_OVERRIDE_APPEND_BEGIN"
    for line in "${_lines[@]}"; do
      printf '%s\n' "$line"
    done
    printf '%s\n' "$VLARCH_OVERRIDE_APPEND_END"
  } >>"$target"
}

vlarch_override_apply_one_at() {
  local root="$1" overrides_dir="$2" override_file="$3" chown_user="${4:-}"
  local target replace_lines=() append_lines=()

  target="$(vlarch_override_target_for "$root" "$overrides_dir" "$override_file")" || return 1
  [[ -f "$target" ]] || {
    if declare -F vlarch_warn >/dev/null 2>&1; then
      vlarch_warn "override skipped (target missing): ${target}"
    fi
    return 1
  }

  vlarch_override_parse_sections "$override_file" replace_lines append_lines
  (( ${#replace_lines[@]} + ${#append_lines[@]} > 0 )) || return 1

  vlarch_override_apply_replace "$target" replace_lines
  vlarch_override_apply_append "$target" append_lines
  if [[ -n "$chown_user" ]]; then
    chown "$chown_user:$chown_user" "$target"
  fi
  return 0
}

vlarch_override_apply_one() {
  local user="$1" override_file="$2"
  local home="/home/${user}"
  local overrides_dir="${home}/.overrides"

  vlarch_override_apply_one_at "$home" "$overrides_dir" "$override_file" "$user"
}

vlarch_apply_overrides_at_root() {
  local user="$1" root="$2"
  local home overrides_dir file applied=0 chown_user=""

  [[ -n "$user" && -n "$root" ]] || return 1
  home="/home/${user}"
  overrides_dir="${home}/.overrides"
  [[ -d "$overrides_dir" ]] || return 0

  if [[ "$root" == "$home" ]]; then
    chown_user="$user"
    vlarch_override_bootstrap_dir "$user"
  fi

  while IFS= read -r -d '' file; do
    if vlarch_override_apply_one_at "$root" "$overrides_dir" "$file" "$chown_user"; then
      applied=$((applied + 1))
    fi
  done < <(find "$overrides_dir" -type f -print0)

  if declare -F vlarch_info >/dev/null 2>&1; then
    vlarch_info "overrides: applied ${applied} file(s) at ${root}"
  fi
  return 0
}

vlarch_overrides_reload_hyprland() {
  local user="$1" uid runtime

  command -v hyprctl >/dev/null 2>&1 || return 0
  id "$user" &>/dev/null || return 0
  uid="$(id -u "$user")"
  runtime="/run/user/${uid}"
  [[ -d "${runtime}/hypr" ]] || return 0

  if command -v runuser >/dev/null 2>&1; then
    runuser -u "$user" -- bash -lc \
      "export XDG_RUNTIME_DIR='${runtime}'; hyprctl seterror disable 2>/dev/null; hyprctl reload 2>/dev/null" \
      || true
    return 0
  fi

  if [[ "$(id -u)" -eq "$uid" ]]; then
    export XDG_RUNTIME_DIR="${runtime}"
    hyprctl seterror disable 2>/dev/null || true
    hyprctl reload 2>/dev/null || true
  fi
}

vlarch_apply_overrides() {
  local user="$1" home="/home/${user}" overrides_dir file target hypr_touched=0

  [[ -n "$user" ]] || return 1
  [[ -d "$home" ]] || return 1

  overrides_dir="${home}/.overrides"
  [[ -d "$overrides_dir" ]] || return 0

  vlarch_override_bootstrap_dir "$user"

  while IFS= read -r -d '' file; do
    target="$(vlarch_override_target_for "$home" "$overrides_dir" "$file" 2>/dev/null || true)"
    if vlarch_override_apply_one_at "$home" "$overrides_dir" "$file" "$user"; then
      [[ "$target" == "${home}/.config/hypr/"* ]] && hypr_touched=1
    fi
  done < <(find "$overrides_dir" -type f -print0)

  if ((hypr_touched)); then
    vlarch_overrides_reload_hyprland "$user"
  fi

  if declare -F vlarch_info >/dev/null 2>&1 && ((hypr_touched)); then
    vlarch_info "overrides: reloaded Hyprland config"
  fi
  return 0
}
