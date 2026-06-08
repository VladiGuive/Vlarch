#!/usr/bin/env bats

load test_helper

setup() {
  source_overrides_lib
  root="${BATS_TMPDIR}/vlarch-home"
  overrides_dir="${root}/.overrides"
  rm -rf "$root"
  mkdir -p "$overrides_dir"
}

@test "vlarch_override_parse_sections: ignores preamble and splits replace/append" {
  local override_file="${BATS_TMPDIR}/override.conf"
  cat >"$override_file" <<'EOF'
# comment — ignored
!!!
    kb_layout = latam
@@@
exec-once = my-script.sh
EOF
  local replace_lines=() append_lines=()
  vlarch_override_parse_sections "$override_file" replace_lines append_lines
  [ "${#replace_lines[@]}" -eq 1 ]
  [ "${replace_lines[0]}" == '    kb_layout = latam' ]
  [ "${#append_lines[@]}" -eq 1 ]
  [ "${append_lines[0]}" == 'exec-once = my-script.sh' ]
}

@test "vlarch_override_apply_replace: key-only replaces unique key" {
  local target="${BATS_TMPDIR}/hyprland.conf"
  cat >"$target" <<'EOF'
general {
    kb_layout = us
}
EOF
  local replace_lines=('    kb_layout = latam')
  vlarch_override_apply_replace "$target" replace_lines
  grep -q 'kb_layout = latam' "$target"
  ! grep -q 'kb_layout = us' "$target"
}

@test "vlarch_override_apply_replace: explicit rule replaces exact line only" {
  local target="${BATS_TMPDIR}/hyprland.conf"
  cat >"$target" <<'EOF'
bindd = , Print, old action, exec, grim
bindd = , A, other bind, exec, true
EOF
  local replace_lines=(
    'bindd = , Print, old action, exec, grim -> bindd = , Print, new action, exec, wl-copy'
  )
  vlarch_override_apply_replace "$target" replace_lines
  grep -q 'bindd = , Print, new action, exec, wl-copy' "$target"
  grep -q 'bindd = , A, other bind, exec, true' "$target"
  ! grep -q 'old action' "$target"
}

@test "vlarch_override_apply_replace: ambiguous key warns and does not replace" {
  local target="${BATS_TMPDIR}/hyprland.conf"
  cat >"$target" <<'EOF'
bindd = , Print, first, exec, grim
bindd = , A, second, exec, true
EOF
  local replace_lines=('bindd = , Print, replacement, exec, wl-copy')
  vlarch_override_apply_replace "$target" replace_lines
  warnings_contain 'ambiguous'
  grep -q 'bindd = , Print, first, exec, grim' "$target"
  grep -q 'bindd = , A, second, exec, true' "$target"
}

@test "vlarch_override_apply_replace: no match for key warns" {
  local target="${BATS_TMPDIR}/hyprland.conf"
  printf 'kb_layout = us\n' >"$target"
  local replace_lines=('kb_variant = latam')
  vlarch_override_apply_replace "$target" replace_lines
  warnings_contain 'no match for key'
  grep -q 'kb_layout = us' "$target"
}

@test "vlarch_override_apply_replace: unmatched explicit rule warns" {
  local target="${BATS_TMPDIR}/hyprland.conf"
  printf 'kb_layout = us\n' >"$target"
  local replace_lines=('kb_layout = de -> kb_layout = latam')
  vlarch_override_apply_replace "$target" replace_lines
  warnings_contain 'no exact match'
  grep -q 'kb_layout = us' "$target"
}

@test "vlarch_override_apply_replace: line without = is silently skipped" {
  local target="${BATS_TMPDIR}/hyprland.conf"
  printf 'kb_layout = us\n' >"$target"
  local replace_lines=('just a comment line')
  vlarch_override_apply_replace "$target" replace_lines
  [ "${#VLARCH_TEST_WARNINGS[@]}" -eq 0 ]
  grep -q 'kb_layout = us' "$target"
}

@test "vlarch_override_apply_append: appends managed block" {
  local target="${BATS_TMPDIR}/hyprland.conf"
  printf 'general {\n}\n' >"$target"
  local append_lines=('exec-once = my-script.sh')
  vlarch_override_apply_append "$target" append_lines
  grep -q '# vlarch:overrides:append' "$target"
  grep -q 'exec-once = my-script.sh' "$target"
  grep -q '# vlarch:overrides:end' "$target"
}

@test "vlarch_override_apply_append: re-apply is idempotent" {
  local target="${BATS_TMPDIR}/hyprland.conf"
  printf 'general {\n}\n' >"$target"
  local first=('exec-once = first.sh')
  vlarch_override_apply_append "$target" first
  local second=('exec-once = second.sh')
  vlarch_override_apply_append "$target" second
  ! grep -q 'exec-once = first.sh' "$target"
  grep -q 'exec-once = second.sh' "$target"
  [ "$(grep -c '# vlarch:overrides:append' "$target")" -eq 1 ]
}

@test "vlarch_override_apply_append: adds newline before block when target lacks trailing newline" {
  local target="${BATS_TMPDIR}/hyprland.conf"
  printf 'general {' >"$target"
  local append_lines=('exec-once = my-script.sh')
  vlarch_override_apply_append "$target" append_lines
  [ "$(sed -n '1p' "$target")" == 'general {' ]
  [ "$(sed -n '2p' "$target")" == '# vlarch:overrides:append' ]
}

@test "vlarch_override_apply_one_at: full pipeline with replace and append sections" {
  mkdir -p "${root}/.config/hypr" "${overrides_dir}/.config/hypr"
  local target="${root}/.config/hypr/hyprland.conf"
  local override_file="${overrides_dir}/.config/hypr/hyprland.conf"
  cat >"$target" <<'EOF'
general {
    kb_layout = us
}
EOF
  cat >"$override_file" <<'EOF'
!!!
    kb_layout = latam
@@@
exec-once = my-script.sh
EOF
  vlarch_override_apply_one_at "$root" "$overrides_dir" "$override_file"
  grep -q 'kb_layout = latam' "$target"
  grep -q 'exec-once = my-script.sh' "$target"
}
