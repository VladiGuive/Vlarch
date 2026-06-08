#!/usr/bin/env python3
"""Generate Nord-themed dotfiles from dotfiles/theme/nord.json."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent.parent
NORD_JSON = ROOT / "dotfiles" / "theme" / "nord.json"
DOTFILES = ROOT / "dotfiles" / ".config"

GENERATED = (
    "Generated from dotfiles/theme/nord.json — do not edit; run: vlarch-theme-generate"
)


def load_theme() -> dict[str, Any]:
    with NORD_JSON.open(encoding="utf-8") as fh:
        return json.load(fh)


def color(theme: dict[str, Any], key: str) -> str:
    palette = theme["palette"]
    if key.startswith("#"):
        return key.upper()
    try:
        return palette[key].upper()
    except KeyError as exc:
        raise KeyError(f"unknown palette key: {key}") from exc


def rgba_hex(hex_color: str, alpha: str = "ee") -> str:
    return f"rgba({hex_color[1:].lower()}{alpha})"


def rgba_hex_alpha(hex_color: str, alpha: str = "cc") -> str:
    return f"rgba({hex_color[1:].lower()}{alpha})"


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    print(f"wrote {path.relative_to(ROOT)}")


def header_comment(prefix: str = "", suffix: str = "") -> str:
    return f"{prefix}{GENERATED}{suffix}\n"


def css_header(*extra_lines: str) -> str:
    lines = [f"/* {GENERATED} */"]
    lines.extend(f"/* {line} */" for line in extra_lines)
    return "\n".join(lines) + "\n"


def generate_kitty(theme: dict[str, Any]) -> None:
    p = theme["palette"]
    opacity = theme["background_opacity"]
    c = color

    content = f"""{header_comment("# ")}# VLARCH_BG_OPACITY={opacity}

# The basic colors
foreground              {c(theme, "nord4")}
background              {c(theme, "nord0")}
selection_foreground    {c(theme, "nord4")}
selection_background    {c(theme, "nord3")}

# Cursor colors
cursor                  {c(theme, "nord4")}
cursor_text_color       {c(theme, "nord0")}

# URL underline color when hovering with mouse
url_color               {c(theme, "nord8")}

# Kitty window border colors
active_border_color     {c(theme, "nord8")}
inactive_border_color   {c(theme, "nord3")}
bell_border_color       {c(theme, "nord13")}

# OS Window titlebar colors
wayland_titlebar_color system
macos_titlebar_color system

# Tab bar colors
active_tab_foreground   {c(theme, "nord6")}
active_tab_background   {c(theme, "nord10")}
inactive_tab_foreground {c(theme, "nord4")}
inactive_tab_background {c(theme, "nord1")}
tab_bar_background      {c(theme, "nord0")}

# Colors for marks (marked text in the terminal)
mark1_foreground {c(theme, "nord0")}
mark1_background {c(theme, "nord10")}
mark2_foreground {c(theme, "nord0")}
mark2_background {c(theme, "nord9")}
mark3_foreground {c(theme, "nord0")}
mark3_background {c(theme, "nord8")}

# The 16 terminal colors

# black
color0 {c(theme, "nord1")}
color8 {c(theme, "nord3")}

# red
color1 {c(theme, "nord11")}
color9 {c(theme, "nord11")}

# green
color2  {c(theme, "nord14")}
color10 {c(theme, "nord14")}

# yellow
color3  {c(theme, "nord13")}
color11 {c(theme, "nord13")}

# blue
color4  {c(theme, "nord9")}
color12 {c(theme, "nord9")}

# magenta
color5  {c(theme, "nord15")}
color13 {c(theme, "nord15")}

# cyan
color6  {c(theme, "nord8")}
color14 {c(theme, "nord7")}

# white
color7  {c(theme, "nord5")}
color15 {c(theme, "nord6")}

background_opacity {opacity}
"""
    write(DOTFILES / "kitty" / "theme.conf", content)


def generate_waybar(theme: dict[str, Any]) -> None:
    wb = theme["waybar"]
    opacity = theme["background_opacity"]
    lines = [
        css_header(f"VLARCH_BG_OPACITY={opacity} in kitty/walker").rstrip(),
        "",
    ]
    for name, key in wb.items():
        lines.append(f"@define-color {name} {color(theme, key)};")
    lines.extend(
        [
            "@define-color update_bg alpha(@sapphire, 0.42);",
            "@define-color update_border alpha(@sky, 0.55);",
            "",
        ]
    )
    write(DOTFILES / "waybar" / "colors.css", "\n".join(lines))


def generate_walker_colors(theme: dict[str, Any]) -> None:
    wk = theme["walker"]
    opacity = theme["background_opacity"]
    lines = [
        css_header(
            f"VLARCH_BG_OPACITY={opacity} — keep in sync with kitty/theme.conf"
        ).rstrip(),
        "",
        f"@define-color window_bg_color {color(theme, wk['window_bg'])};",
        f"@define-color window_bg_alpha alpha(@window_bg_color, {opacity});",
    ]
    mapping = {
        "accent_bg_color": "accent_bg",
        "theme_fg_color": "theme_fg",
        "theme_fg_bright": "theme_fg_bright",
        "accent_color": "accent",
        "accent_color_alt": "accent_alt",
        "border_color": "border",
        "input_bg_color": "input_bg",
        "selection_bg_color": "selection_bg",
        "error_bg_color": "error_bg",
        "error_fg_color": "error_fg",
    }
    for css_name, json_key in mapping.items():
        lines.append(f"@define-color {css_name} {color(theme, wk[json_key])};")
    lines.append("")
    write(DOTFILES / "walker" / "themes" / "vlarch-nord" / "colors.css", "\n".join(lines))


def generate_ohmyposh(theme: dict[str, Any]) -> None:
    op = theme["ohmyposh"]
    c = lambda k: color(theme, op[k])

    content = f"""{header_comment("# ")}console_title_template = '{{{{ .Shell }}}} in {{{{ .Folder }}}}'
version = 3
final_space = true

[secondary_prompt]
  template = '❯❯ '
  foreground = '{c("secondary_prompt")}'
  background = 'transparent'

[transient_prompt]
  template = '❯ '
  background = 'transparent'
  foreground_templates = ['{{{{if gt .Code 0}}}}{c("error_prompt")}{{{{end}}}}', '{{{{if eq .Code 0}}}}{c("success_prompt")}{{{{end}}}}']

[[blocks]]
  type = 'prompt'
  alignment = 'left'
  newline = true

  [[blocks.segments]]
    template = '{{{{ .Path }}}}'
    foreground = '{c("path")}'
    background = 'transparent'
    type = 'path'
    style = 'plain'

    [blocks.segments.properties]
      cache_duration = 'none'
      style = 'full'

  [[blocks.segments]]
    template = ' {{{{ .HEAD }}}}{{{{ if or (.Working.Changed) (.Staging.Changed) }}}}*{{{{ end }}}} <{c("git_status")}>{{{{ if gt .Behind 0 }}}}⇣{{{{ end }}}}{{{{ if gt .Ahead 0 }}}}⇡{{{{ end }}}}</>'
    foreground = '{c("git")}'
    background = 'transparent'
    type = 'git'
    style = 'plain'

    [blocks.segments.properties]
      branch_icon = ''
      cache_duration = 'none'
      commit_icon = '@'
      fetch_status = true

[[blocks]]
  type = 'rprompt'
  overflow = 'hidden'

  [[blocks.segments]]
    template = '{{{{ .FormattedMs }}}}'
    foreground = '{c("execution_time")}'
    background = 'transparent'
    type = 'executiontime'
    style = 'plain'

    [blocks.segments.properties]
      cache_duration = 'none'
      threshold = 5000

[[blocks]]
  type = 'prompt'
  alignment = 'left'
  newline = true

  [[blocks.segments]]
    template = '❯'
    background = 'transparent'
    type = 'text'
    style = 'plain'
    foreground_templates = ['{{{{if gt .Code 0}}}}{c("error_prompt")}{{{{end}}}}', '{{{{if eq .Code 0}}}}{c("success_prompt")}{{{{end}}}}']

    [blocks.segments.properties]
      cache_duration = 'none'
"""
    write(DOTFILES / "ohmyposh" / "conf.toml", content)


def generate_hypr_colors(theme: dict[str, Any]) -> None:
    hypr = theme["hypr"]
    active = [color(theme, k) for k in hypr["active_border"]]
    inactive = color(theme, hypr["inactive_border"])
    shadow = color(theme, hypr["shadow"])

    content = f"""{header_comment("# ")}general {{
    col.active_border = {rgba_hex(active[0])} {rgba_hex(active[1])} 45deg
    col.inactive_border = {rgba_hex_alpha(inactive)}
}}

decoration {{
    shadow {{
        color = {rgba_hex(shadow)}
    }}
}}
"""
    write(DOTFILES / "hypr" / "nord-colors.conf", content)


def generate_nvim_palette(theme: dict[str, Any]) -> None:
    lines = [
        f"-- {GENERATED}",
        "return {",
    ]
    for name, value in theme["palette"].items():
        lines.append(f'  {name} = "{value.upper()}",')
    lines.extend(["}", ""])
    write(DOTFILES / "nvim" / "lua" / "config" / "nord-palette.lua", "\n".join(lines))


def main() -> int:
    if not NORD_JSON.is_file():
        print(f"error: missing {NORD_JSON}", file=sys.stderr)
        return 1

    theme = load_theme()
    generate_kitty(theme)
    generate_waybar(theme)
    generate_walker_colors(theme)
    generate_ohmyposh(theme)
    generate_hypr_colors(theme)
    generate_nvim_palette(theme)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
