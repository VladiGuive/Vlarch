-- Vlarch: curated keybind reference (view-only). Edit here when hyprland.conf binds change.
Name = "keybinds"
NamePretty = "Keybinds"
Icon = "preferences-desktop-keyboard-shortcuts"
Cache = true
FixedOrder = true
Action = "true"
SearchName = true

-- Listed top-to-bottom (most important first). Elephant sorts alphabetically unless FixedOrder is set.
local BINDS = {
	{
		keys = "Super + Space",
		desc = "Open application launcher (Walker)",
		keywords = "walker launcher search run",
	},
	{
		keys = "Super + K",
		desc = "Open this keybind reference",
		keywords = "keybinds shortcuts help",
	},
	{
		keys = "Super + Enter",
		desc = "Open terminal",
		keywords = "kitty tmux shell",
	},
	{
		keys = "Print",
		desc = "Screenshot full screen to clipboard",
		keywords = "grim screenshot capture screen",
	},
	{
		keys = "Super + Shift + S",
		desc = "Screenshot region to clipboard",
		keywords = "grim slurp area select screenshot",
	},
	{
		keys = "Super + Q",
		desc = "Close focused window",
		keywords = "kill close quit",
	},
	{
		keys = "Super + ↑ ↓ ← →",
		desc = "Change focus between windows",
		keywords = "focus move arrow direction",
	},
	{
		keys = "Super + 1…0",
		desc = "Switch workspace on the focused monitor (0 = workspace 10)",
		keywords = "workspace desktop monitor goto",
	},
	{
		keys = "Super + V",
		desc = "Toggle floating on focused window",
		keywords = "float tile",
	},
	{
		keys = "Super + F",
		desc = "Fullscreen content inside the tile (keeps browser tabs and toolbar)",
		keywords = "fullscreen maximize video",
	},
	{
		keys = "Super + left click",
		desc = "Move window by dragging",
		keywords = "mouse drag move window",
	},
	{
		keys = "Super + right click",
		desc = "Resize window by dragging",
		keywords = "mouse drag resize",
	},
	{
		keys = "Super + scroll ↑↓",
		desc = "Cycle workspace on the focused monitor",
		keywords = "workspace next previous scroll wheel",
	},
	{
		keys = "Super + Shift + 1…0",
		desc = "Move window to workspace on the focused monitor (0 = workspace 10)",
		keywords = "workspace move window shift",
	},
}

function GetEntries()
	local entries = {}
	for _, bind in ipairs(BINDS) do
		table.insert(entries, {
			Text = bind.keys,
			Subtext = bind.desc,
			Value = bind.keys,
			Keywords = bind.keywords,
			Icon = "preferences-desktop-keyboard-shortcuts",
		})
	end
	return entries
end
