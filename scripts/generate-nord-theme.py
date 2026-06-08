#!/usr/bin/env python3
"""Generate themed dotfiles from a ~/.config/themes/*.json palette file."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

THEMES_DIR_NAME = "themes"
ACTIVE_THEME_FILE = "vlarch/active-theme"

# Vlarch decides which semantic palette role each app uses.
KITTY = {
    "foreground": "snow_storm_0",
    "background": "polar_night_0",
    "selection_foreground": "snow_storm_0",
    "selection_background": "polar_night_3",
    "cursor": "snow_storm_0",
    "cursor_text": "polar_night_0",
    "url": "frost_1",
    "active_border": "frost_1",
    "inactive_border": "polar_night_3",
    "bell_border": "aurora_yellow",
    "active_tab_foreground": "snow_storm_2",
    "active_tab_background": "frost_3",
    "inactive_tab_foreground": "snow_storm_0",
    "inactive_tab_background": "polar_night_1",
    "tab_bar_background": "polar_night_0",
    "mark1_background": "frost_3",
    "mark2_background": "frost_2",
    "mark3_background": "frost_1",
    "color0": "polar_night_1",
    "color8": "polar_night_3",
    "color1": "aurora_red",
    "color9": "aurora_red",
    "color2": "aurora_green",
    "color10": "aurora_green",
    "color3": "aurora_yellow",
    "color11": "aurora_yellow",
    "color4": "frost_2",
    "color12": "frost_2",
    "color5": "aurora_purple",
    "color13": "aurora_purple",
    "color6": "frost_1",
    "color14": "frost_0",
    "color7": "snow_storm_1",
    "color15": "snow_storm_2",
}

HYPR = {
    "active_border": ["frost_1", "frost_2"],
    "inactive_border": "polar_night_3",
    "shadow": "polar_night_0",
}

WAYBAR = {
    "base": "polar_night_0",
    "surface0": "polar_night_1",
    "surface1": "polar_night_2",
    "surface2": "polar_night_3",
    "text": "snow_storm_0",
    "subtext1": "snow_storm_1",
    "subtext0": "snow_storm_2",
    "lavender": "aurora_purple",
    "blue": "frost_2",
    "sky": "frost_1",
    "sapphire": "frost_3",
    "green": "aurora_green",
    "yellow": "aurora_yellow",
    "red": "aurora_red",
    "maroon": "aurora_purple",
    "pink": "aurora_purple",
    "mauve": "aurora_purple",
}

WALKER = {
    "window_bg": "polar_night_0",
    "accent_bg": "polar_night_2",
    "theme_fg": "snow_storm_0",
    "theme_fg_bright": "snow_storm_2",
    "accent": "frost_1",
    "accent_alt": "frost_2",
    "border": "polar_night_3",
    "input_bg": "polar_night_1",
    "selection_bg": "polar_night_2",
    "error_bg": "aurora_red",
    "error_fg": "snow_storm_2",
}

OHMYPOSH = {
    "secondary_prompt": "aurora_purple",
    "success_prompt": "aurora_purple",
    "error_prompt": "aurora_red",
    "path": "frost_2",
    "git": "polar_night_3",
    "git_status": "frost_0",
    "execution_time": "aurora_yellow",
}

NVIM_DOTFILE = "frost_0"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--theme",
        type=Path,
        help="Theme JSON (default: ~/.config/vlarch/active-theme or ~/.config/themes/nord.json)",
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="Write generated files under this .config root",
    )
    return parser.parse_args()


def themes_dir(home: Path) -> Path:
    return home / ".config" / THEMES_DIR_NAME


def active_theme_file(home: Path) -> Path:
    return home / ".config" / ACTIVE_THEME_FILE


def resolve_theme_path(theme_arg: Path | None) -> Path:
    home = Path.home()
    if theme_arg is not None:
        return theme_arg.expanduser().resolve()

    active = active_theme_file(home)
    if active.is_file():
        path = Path(active.read_text(encoding="utf-8").strip()).expanduser()
        if path.is_file():
            return path.resolve()

    default = themes_dir(home) / "nord.json"
    if default.is_file():
        return default.resolve()

    repo_default = (
        Path(__file__).resolve().parent.parent
        / "dotfiles/.config/themes/nord.json"
    )
    if repo_default.is_file():
        return repo_default.resolve()

    raise FileNotFoundError(
        "no theme file found; pass --theme or add ~/.config/themes/nord.json"
    )


def resolve_output_dir(output_arg: Path | None) -> Path:
    if output_arg is not None:
        return output_arg.expanduser().resolve()

    share_script = Path("/usr/local/share/vlarch/generate-nord-theme.py")
    if share_script.is_file():
        return (Path.home() / ".config").resolve()

    repo_output = Path(__file__).resolve().parent.parent / "dotfiles/.config"
    if repo_output.is_dir():
        return repo_output.resolve()

    return (Path.home() / ".config").resolve()


def load_theme(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as fh:
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


def persist_active_theme(theme_path: Path) -> None:
    active = active_theme_file(Path.home())
    active.parent.mkdir(parents=True, exist_ok=True)
    active.write_text(f"{theme_path}\n", encoding="utf-8")


class ThemeGenerator:
    def __init__(self, theme_path: Path, output_root: Path) -> None:
        self.theme_path = theme_path
        self.output_root = output_root
        self.theme = load_theme(theme_path)
        self.source_label = f"~/.config/themes/{theme_path.name}"
        self.generated = (
            f"Generated from {self.source_label} — do not edit; run: vlarch-theme-generate"
        )

    def c(self, key: str) -> str:
        return color(self.theme, key)

    def write(self, rel_path: str, content: str) -> None:
        path = self.output_root / rel_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        print(f"wrote {path}")

    def header_comment(self, prefix: str = "", suffix: str = "") -> str:
        return f"{prefix}{self.generated}{suffix}\n"

    def css_header(self, *extra_lines: str) -> str:
        lines = [f"/* {self.generated} */"]
        lines.extend(f"/* {line} */" for line in extra_lines)
        return "\n".join(lines) + "\n"

    def generate_kitty(self) -> None:
        k = KITTY
        opacity = self.theme["background_opacity"]
        mark_fg = self.c("polar_night_0")

        content = f"""{self.header_comment("# ")}# VLARCH_BG_OPACITY={opacity}

# The basic colors
foreground              {self.c(k["foreground"])}
background              {self.c(k["background"])}
selection_foreground    {self.c(k["selection_foreground"])}
selection_background    {self.c(k["selection_background"])}

# Cursor colors
cursor                  {self.c(k["cursor"])}
cursor_text_color       {self.c(k["cursor_text"])}

# URL underline color when hovering with mouse
url_color               {self.c(k["url"])}

# Kitty window border colors
active_border_color     {self.c(k["active_border"])}
inactive_border_color   {self.c(k["inactive_border"])}
bell_border_color       {self.c(k["bell_border"])}

# OS Window titlebar colors
wayland_titlebar_color system
macos_titlebar_color system

# Tab bar colors
active_tab_foreground   {self.c(k["active_tab_foreground"])}
active_tab_background   {self.c(k["active_tab_background"])}
inactive_tab_foreground {self.c(k["inactive_tab_foreground"])}
inactive_tab_background {self.c(k["inactive_tab_background"])}
tab_bar_background      {self.c(k["tab_bar_background"])}

# Colors for marks (marked text in the terminal)
mark1_foreground {mark_fg}
mark1_background {self.c(k["mark1_background"])}
mark2_foreground {mark_fg}
mark2_background {self.c(k["mark2_background"])}
mark3_foreground {mark_fg}
mark3_background {self.c(k["mark3_background"])}

# The 16 terminal colors

# black
color0 {self.c(k["color0"])}
color8 {self.c(k["color8"])}

# red
color1 {self.c(k["color1"])}
color9 {self.c(k["color9"])}

# green
color2  {self.c(k["color2"])}
color10 {self.c(k["color10"])}

# yellow
color3  {self.c(k["color3"])}
color11 {self.c(k["color11"])}

# blue
color4  {self.c(k["color4"])}
color12 {self.c(k["color12"])}

# magenta
color5  {self.c(k["color5"])}
color13 {self.c(k["color13"])}

# cyan
color6  {self.c(k["color6"])}
color14 {self.c(k["color14"])}

# white
color7  {self.c(k["color7"])}
color15 {self.c(k["color15"])}

background_opacity {opacity}
"""
        self.write("kitty/theme.conf", content)

    def generate_waybar(self) -> None:
        opacity = self.theme["background_opacity"]
        lines = [
            self.css_header(f"VLARCH_BG_OPACITY={opacity} in kitty/walker").rstrip(),
            "",
        ]
        for name, key in WAYBAR.items():
            lines.append(f"@define-color {name} {self.c(key)};")
        lines.extend(
            [
                "@define-color update_bg alpha(@sapphire, 0.42);",
                "@define-color update_border alpha(@sky, 0.55);",
                "",
            ]
        )
        self.write("waybar/colors.css", "\n".join(lines))

    def generate_walker_colors(self) -> None:
        opacity = self.theme["background_opacity"]
        lines = [
            self.css_header(
                f"VLARCH_BG_OPACITY={opacity} — keep in sync with kitty/theme.conf"
            ).rstrip(),
            "",
            f"@define-color window_bg_color {self.c(WALKER['window_bg'])};",
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
            lines.append(f"@define-color {css_name} {self.c(WALKER[json_key])};")
        lines.append("")
        self.write("walker/themes/vlarch-nord/colors.css", "\n".join(lines))

    def generate_ohmyposh(self) -> None:
        op = OHMYPOSH
        c = self.c

        content = f"""{self.header_comment("# ")}console_title_template = '{{{{ .Shell }}}} in {{{{ .Folder }}}}'
version = 3
final_space = true

[secondary_prompt]
  template = '❯❯ '
  foreground = '{c(op["secondary_prompt"])}'
  background = 'transparent'

[transient_prompt]
  template = '❯ '
  background = 'transparent'
  foreground_templates = ['{{{{if gt .Code 0}}}}{c(op["error_prompt"])}{{{{end}}}}', '{{{{if eq .Code 0}}}}{c(op["success_prompt"])}{{{{end}}}}']

[[blocks]]
  type = 'prompt'
  alignment = 'left'
  newline = true

  [[blocks.segments]]
    template = '{{{{ .Path }}}}'
    foreground = '{c(op["path"])}'
    background = 'transparent'
    type = 'path'
    style = 'plain'

    [blocks.segments.properties]
      cache_duration = 'none'
      style = 'full'

  [[blocks.segments]]
    template = ' {{{{ .HEAD }}}}{{{{ if or (.Working.Changed) (.Staging.Changed) }}}}*{{{{ end }}}} <{c(op["git_status"])}>{{{{ if gt .Behind 0 }}}}⇣{{{{ end }}}}{{{{ if gt .Ahead 0 }}}}⇡{{{{ end }}}}</>'
    foreground = '{c(op["git"])}'
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
    foreground = '{c(op["execution_time"])}'
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
    foreground_templates = ['{{{{if gt .Code 0}}}}{c(op["error_prompt"])}{{{{end}}}}', '{{{{if eq .Code 0}}}}{c(op["success_prompt"])}{{{{end}}}}']

    [blocks.segments.properties]
      cache_duration = 'none'
"""
        self.write("ohmyposh/conf.toml", content)

    def generate_hypr_colors(self) -> None:
        active = [self.c(k) for k in HYPR["active_border"]]
        inactive = self.c(HYPR["inactive_border"])
        shadow = self.c(HYPR["shadow"])

        content = f"""{self.header_comment("# ")}general {{
    col.active_border = {rgba_hex(active[0])} {rgba_hex(active[1])} 45deg
    col.inactive_border = {rgba_hex_alpha(inactive)}
}}

decoration {{
    shadow {{
        color = {rgba_hex(shadow)}
    }}
}}
"""
        self.write("hypr/nord-colors.conf", content)

    def generate_nvim_palette(self) -> None:
        lines = [
            f"-- {self.generated}",
            "return {",
            f'  dotfile = "{self.c(NVIM_DOTFILE)}",',
        ]
        for name, value in self.theme["palette"].items():
            lines.append(f'  {name} = "{value.upper()}",')
        lines.extend(["}", ""])
        self.write("nvim/lua/config/theme-palette.lua", "\n".join(lines))

    def run(self) -> None:
        self.generate_kitty()
        self.generate_waybar()
        self.generate_walker_colors()
        self.generate_ohmyposh()
        self.generate_hypr_colors()
        self.generate_nvim_palette()


def main() -> int:
    args = parse_args()
    try:
        theme_path = resolve_theme_path(args.theme)
        output_root = resolve_output_dir(args.output)
    except FileNotFoundError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    if not theme_path.is_file():
        print(f"error: theme file missing: {theme_path}", file=sys.stderr)
        return 1

    persist_active_theme(theme_path)
    ThemeGenerator(theme_path, output_root).run()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
