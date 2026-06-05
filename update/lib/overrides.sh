#!/usr/bin/env bash
# User dotfile overrides. Sourced - no set -e here.
# ~/.overrides mirrors $HOME paths and is applied after each dotfiles deploy.

VLARCH_OVERRIDE_APPEND_BEGIN='# vlarch:overrides:append'
VLARCH_OVERRIDE_APPEND_END='# vlarch:overrides:end'

vlarch_override_line_key() {
  local line="$1" key
  line="${line#"${line%%[![:space:]]*}"}"
  [[ "$line" == *"="* ]] || return 1
  key="${line%%=*}"
  key="${key%"${key##*[![:space:]]}"}"
  [[ -n "$key" ]] || return 1
  printf '%s' "$key"
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

**`!!!` — replace** lines by key (text before `=`):

```
!!!
    kb_layout = latam
```

Replaces `kb_layout = us` (or any `kb_layout = …`) in the target file.

**`@@@` — append** lines at the end inside a managed block (safe across updates):

```
@@@
exec-once = my-custom-command
```

## Example

`~/.overrides/.config/hypr/hyprland.conf`:

```
!!!
    kb_layout = latam
@@@
exec-once = my-custom-command
```
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
  local -A replacements=()
  local line key tmp

  (( ${#_lines[@]} > 0 )) || return 0

  for line in "${_lines[@]}"; do
    key="$(vlarch_override_line_key "$line")" || continue
    replacements["$key"]="$line"
  done

  (( ${#replacements[@]} > 0 )) || return 0

  tmp="$(mktemp)"
  while IFS= read -r line || [[ -n "$line" ]]; do
    key="$(vlarch_override_line_key "$line")" || {
      printf '%s\n' "$line" >>"$tmp"
      continue
    }
    if [[ -n "${replacements[$key]+x}" ]]; then
      printf '%s\n' "${replacements[$key]}" >>"$tmp"
      unset 'replacements[$key]'
    else
      printf '%s\n' "$line" >>"$tmp"
    fi
  done <"$target"
  mv -f "$tmp" "$target"

  if ((${#replacements[@]} > 0)) && declare -F vlarch_warn >/dev/null 2>&1; then
    for key in "${!replacements[@]}"; do
      vlarch_warn "override replace: no match for key '${key}' in ${target}"
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
  mv -f "$tmp" "$target"
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

vlarch_override_apply_one() {
  local user="$1" override_file="$2"
  local home="/home/${user}"
  local overrides_dir="${home}/.overrides"
  local target replace_lines=() append_lines=()

  target="$(vlarch_override_target_for "$home" "$overrides_dir" "$override_file")" || return 1
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
  chown "$user:$user" "$target"
  return 0
}

vlarch_apply_overrides() {
  local user="$1"
  local home="/home/${user}"
  local overrides_dir="${home}/.overrides"
  local file applied=0

  [[ -n "$user" ]] || return 1
  [[ -d "$home" ]] || return 1

  vlarch_override_bootstrap_dir "$user"

  while IFS= read -r -d '' file; do
    vlarch_override_apply_one "$user" "$file" && applied=$((applied + 1)) || true
  done < <(find "$overrides_dir" -type f -print0)

  if declare -F vlarch_info >/dev/null 2>&1; then
    vlarch_info "overrides: applied ${applied} file(s) from ${overrides_dir}"
  fi
  return 0
}
