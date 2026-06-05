-- Vlarch: curated keybind reference (view-only). Edit here when hyprland.conf binds change.
Name = "keybinds"
NamePretty = "Keybinds"
Icon = "preferences-desktop-keyboard-shortcuts"
Cache = true
Action = "true"
SearchName = true

-- Lower priority = listed first. Keywords help Walker search beyond the visible labels.
local BINDS = {
	{
		keys = "Super + Space",
		desc = "Open application launcher (Walker)",
		keywords = "walker launcher search run",
		priority = 1,
	},
	{
		keys = "Super + K",
		desc = "Open this keybind reference",
		keywords = "keybinds shortcuts help",
		priority = 2,
	},
	{
		keys = "Super + Enter",
		desc = "Open terminal",
		keywords = "kitty tmux shell",
		priority = 3,
	},
	{
		keys = "Print",
		desc = "Screenshot full screen to clipboard",
		keywords = "grim screenshot capture screen",
		priority = 10,
	},
	{
		keys = "Super + Shift + S",
		desc = "Screenshot region to clipboard",
		keywords = "grim slurp area select screenshot",
		priority = 11,
	},
	{
		keys = "Super + Q",
		desc = "Close focused window",
		keywords = "kill close quit",
		priority = 20,
	},
	{
		keys = "Super + ↑ ↓ ← →",
		desc = "Change focus between windows",
		keywords = "focus move arrow direction",
		priority = 30,
	},
	{
		keys = "Super + 1…0",
		desc = "Switch workspace on the focused monitor (0 = workspace 10)",
		keywords = "workspace desktop monitor goto",
		priority = 40,
	},
	{
		keys = "Super + scroll ↑↓",
		desc = "Cycle workspace on the focused monitor",
		keywords = "workspace next previous scroll wheel",
		priority = 51,
	},
	{
		keys = "Super + V",
		desc = "Toggle floating on focused window",
		keywords = "float tile",
		priority = 45,
	},
	{
		keys = "Super + F",
		desc = "Fullscreen content inside the tile (keeps browser tabs and toolbar)",
		keywords = "fullscreen maximize video",
		priority = 46,
	},
	{
		keys = "Super + left click",
		desc = "Move window by dragging",
		keywords = "mouse drag move window",
		priority = 48,
	},
	{
		keys = "Super + right click",
		desc = "Resize window by dragging",
		keywords = "mouse drag resize",
		priority = 49,
	},
	{
		keys = "Super + Shift + 1…0",
		desc = "Move window to workspace on the focused monitor (0 = workspace 10)",
		keywords = "workspace move window shift",
		priority = 55,
	},
}

local function entry_from_bind(bind)
	return {
		Text = bind.keys,
		Subtext = bind.desc,
		Value = bind.keys,
		Keywords = bind.keywords,
		Icon = "preferences-desktop-keyboard-shortcuts",
		_priority = bind.priority,
	}
end

function GetEntries()
	local entries = {}
	for _, bind in ipairs(BINDS) do
		table.insert(entries, entry_from_bind(bind))
	end

	table.sort(entries, function(a, b)
		if a._priority ~= b._priority then
			return a._priority < b._priority
		end
		return a.Text < b.Text
	end)

	for _, entry in ipairs(entries) do
		entry._priority = nil
	end

	return entries
end
