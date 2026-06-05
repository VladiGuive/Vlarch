-- Vlarch: searchable Hyprland keybind reference (view-only).
local json = dofile(os.getenv("HOME") .. "/.config/elephant/utils/json.lua")

Name = "keybinds"
NamePretty = "Keybinds"
Icon = "preferences-desktop-keyboard-shortcuts"
Cache = false
Action = "true"
SearchName = true

local KEY_DISPLAY = {
	left = "←",
	right = "→",
	up = "↑",
	down = "↓",
	SPACE = "Space",
	RETURN = "Enter",
	Print = "Print",
}

local function label_keys(keys)
	return keys
end

local GROUP_INFO = {
	workspace_goto = {
		priority = 40,
		description = "Switch current workspace on the focused monitor",
		format_keys = function(mods, _)
			return label_keys(mods .. " + 1…0")
		end,
	},
	workspace_move = {
		priority = 55,
		description = "Move window to workspace on the focused monitor",
		format_keys = function(mods, _)
			return label_keys(mods .. " + 1…0")
		end,
	},
	movefocus = {
		priority = 30,
		description = "Change focus between windows (arrow keys)",
		format_keys = function(mods, _)
			return label_keys(mods .. " + ↑ ↓ ← →")
		end,
	},
	workspace_scroll = {
		priority = 51,
		description = "Cycle workspace on the focused monitor",
		format_keys = function(mods, _)
			return label_keys(mods .. " + scroll ↑↓")
		end,
	},
	mouse_move = {
		priority = 48,
		description = "Move window by dragging",
		format_keys = function(mods, _)
			return label_keys(mods .. " + left click")
		end,
	},
	mouse_resize = {
		priority = 49,
		description = "Resize window by dragging",
		format_keys = function(mods, _)
			return label_keys(mods .. " + right click")
		end,
	},
}

local BIND_PRIORITY = {
	["exec:walker"] = 1,
	["exec:walker -m menus:keybinds"] = 2,
	["exec:kitty"] = 3,
	screenshot_full = 10,
	screenshot_region = 11,
	killactive = 20,
	togglefloating = 45,
	fullscreen = 46,
	workspace_scroll = 51,
	mouse_move = 48,
	mouse_resize = 49,
}

local BIND_DESCRIPTIONS = {
	["exec:walker"] = "Open application launcher",
	["exec:walker -m menus:keybinds"] = "Open keybind reference",
	["exec:walker -m menus:keybinds -p \"Keybinds...\""] = "Open keybind reference",
	["exec:kitty"] = "Open terminal",
	["exec:kitty -e tmux"] = "Open terminal",
	killactive = "Close focused window",
	togglefloating = "Toggle floating on focused window",
	fullscreen = "Toggle fullscreen on focused window",
	screenshot_full = "Take a full-screen screenshot to clipboard",
	screenshot_region = "Take a region screenshot to clipboard",
	mouse_movewindow = "Move window by dragging",
	mouse_resizewindow = "Resize window by dragging",
}

local function get_mods(modmask)
	modmask = modmask or 0
	local mods = {}
	if math.floor(modmask / 64) % 2 >= 1 then
		table.insert(mods, "Super")
	end
	if math.floor(modmask / 8) % 2 >= 1 then
		table.insert(mods, "Alt")
	end
	if math.floor(modmask / 4) % 2 >= 1 then
		table.insert(mods, "Ctrl")
	end
	if math.floor(modmask / 1) % 2 >= 1 then
		table.insert(mods, "Shift")
	end
	return mods
end

local function display_key(key)
	if not key or key == "" then
		return ""
	end
	return KEY_DISPLAY[key] or KEY_DISPLAY[key:upper()] or key
end

local MOUSE_KEY_LABEL = {
	["mouse:272"] = "left click",
	["mouse:273"] = "right click",
	mouse_down = "scroll down",
	mouse_up = "scroll up",
}

local function is_media_key_bind(bind)
	local key = bind.key or ""
	return key:find("^XF86") ~= nil
end

local function format_keys(bind)
	local key = bind.key or ""
	if key == "" and bind.keycode and bind.keycode > 0 then
		key = "#" .. tostring(bind.keycode)
	end
	if key == "" then
		return ""
	end

	local mods = get_mods(bind.modmask)
	local parts = {}
	for _, mod in ipairs(mods) do
		table.insert(parts, mod)
	end
	local key_label = MOUSE_KEY_LABEL[key] or display_key(key)
	table.insert(parts, key_label)
	return table.concat(parts, " + ")
end

local function bind_signature(bind)
	local dispatcher = bind.dispatcher or ""
	local arg = bind.arg or ""
	if arg ~= "" then
		return dispatcher .. ":" .. arg
	end
	return dispatcher
end

local function get_group_id(bind)
	local dispatcher = bind.dispatcher or ""
	local arg = bind.arg or ""
	local key = bind.key or ""

	if dispatcher == "exec" and arg:match("^vlarch%-workspace goto ") then
		return "workspace_goto"
	end
	if dispatcher == "exec" and arg:match("^vlarch%-workspace move ") then
		return "workspace_move"
	end
	if dispatcher == "movefocus" then
		return "movefocus"
	end
	if dispatcher == "exec" and arg:find("grim") and arg:find("wl%-copy") and not arg:find("slurp") then
		return "screenshot_full"
	end
	if dispatcher == "exec" and arg:find("slurp") and arg:find("grim") then
		return "screenshot_region"
	end
	if key == "mouse_down" or key == "mouse_up" then
		if dispatcher == "exec" and (arg:match("^vlarch%-workspace next") or arg:match("^vlarch%-workspace prev")) then
			return "workspace_scroll"
		end
	end
	if bind.mouse then
		if arg == "movewindow" or dispatcher == "movewindow" then
			return "mouse_move"
		end
		if arg == "resizewindow" or dispatcher == "resizewindow" then
			return "mouse_resize"
		end
	end
	return nil
end

local function describe_bind(bind)
	if bind.description and bind.description ~= "" then
		return bind.description
	end

	local group_id = get_group_id(bind)
	if group_id == "screenshot_full" then
		return BIND_DESCRIPTIONS.screenshot_full
	end
	if group_id == "screenshot_region" then
		return BIND_DESCRIPTIONS.screenshot_region
	end
	if group_id and GROUP_INFO[group_id] then
		return GROUP_INFO[group_id].description
	end

	local dispatcher = bind.dispatcher or ""
	local arg = bind.arg or ""
	if dispatcher == "exec" and arg:find("^walker") and not arg:find("menus:keybinds") then
		return BIND_DESCRIPTIONS["exec:walker"]
	end
	if dispatcher == "exec" and arg:find("menus:keybinds") then
		return BIND_DESCRIPTIONS["exec:walker -m menus:keybinds"]
	end
	if dispatcher == "exec" and arg:find("kitty") then
		return BIND_DESCRIPTIONS["exec:kitty -e tmux"]
	end

	if dispatcher == "fullscreen" then
		return BIND_DESCRIPTIONS.fullscreen
	end

	local sig = bind_signature(bind)
	if BIND_DESCRIPTIONS[sig] then
		return BIND_DESCRIPTIONS[sig]
	end

	if bind.mouse then
		if arg == "movewindow" then
			return BIND_DESCRIPTIONS.mouse_movewindow
		end
		if arg == "resizewindow" then
			return BIND_DESCRIPTIONS.mouse_resizewindow
		end
	end

	return format_action_raw(bind)
end

local function format_action_raw(bind)
	local dispatcher = bind.dispatcher or ""
	local arg = bind.arg or ""
	if dispatcher == "" and arg == "" then
		return "Hyprland action"
	end
	if arg ~= "" then
		return dispatcher .. " " .. arg
	end
	return dispatcher
end

local function bind_priority(bind, group_id)
	if group_id and GROUP_INFO[group_id] then
		return GROUP_INFO[group_id].priority
	end

	local gid = get_group_id(bind)
	if gid == "screenshot_full" then
		return BIND_PRIORITY.screenshot_full
	end
	if gid == "screenshot_region" then
		return BIND_PRIORITY.screenshot_region
	end

	local dispatcher = bind.dispatcher or ""
	local arg = bind.arg or ""
	if dispatcher == "exec" and arg:find("^walker") and not arg:find("menus:keybinds") then
		return BIND_PRIORITY["exec:walker"]
	end
	if dispatcher == "exec" and arg:find("menus:keybinds") then
		return BIND_PRIORITY["exec:walker -m menus:keybinds"]
	end
	if dispatcher == "exec" and arg:find("kitty") then
		return BIND_PRIORITY["exec:kitty"]
	end

	if dispatcher == "fullscreen" then
		return BIND_PRIORITY.fullscreen
	end

	if gid and BIND_PRIORITY[gid] then
		return BIND_PRIORITY[gid]
	end

	local sig = bind_signature(bind)
	if BIND_PRIORITY[sig] then
		return BIND_PRIORITY[sig]
	end

	return 80
end

local function should_include(bind)
	if is_media_key_bind(bind) then
		return false
	end
	if bind.submap and bind.submap ~= "" then
		return false
	end
	if get_group_id(bind) then
		return true
	end
	return format_keys(bind) ~= ""
end

local function mods_prefix(bind)
	return table.concat(get_mods(bind.modmask), " + ")
end

local function add_entry(entries, seen, text, subtext, value, priority)
	local dedupe = text .. "\0" .. subtext
	if seen[dedupe] then
		return
	end
	seen[dedupe] = true
	table.insert(entries, {
		Text = text,
		Subtext = subtext,
		Value = value or text,
		Icon = "preferences-desktop-keyboard-shortcuts",
		_priority = priority or 99,
	})
end

function GetEntries()
	local handle = io.popen("hyprctl binds -j 2>/dev/null")
	if not handle then
		return {
			{ Text = "error", Subtext = "Hyprland is not running", Value = "error" },
		}
	end

	local output = handle:read("*a")
	handle:close()

	if not output or output == "" then
		return {
			{ Text = "empty", Subtext = "hyprctl binds -j returned no data", Value = "empty" },
		}
	end

	local ok, data = pcall(json.decode, output)
	if not ok then
		return {
			{ Text = "error", Subtext = tostring(data), Value = "error" },
		}
	end

	if type(data) ~= "table" then
		return {
			{ Text = "error", Subtext = "Expected a JSON array from hyprctl", Value = "error" },
		}
	end

	local entries = {}
	local seen = {}
	local groups = {}

	for _, bind in ipairs(data) do
		if should_include(bind) then
			local group_id = get_group_id(bind)
			if group_id and GROUP_INFO[group_id] then
				local info = GROUP_INFO[group_id]
				groups[group_id] = groups[group_id] or {
					bind = bind,
					description = info.description,
				}
			else
				local keys = format_keys(bind)
				local description = describe_bind(bind)
				local priority = bind_priority(bind, nil)
				add_entry(entries, seen, label_keys(keys), description, keys, priority)
			end
		end
	end

	for group_id, group in pairs(groups) do
		local info = GROUP_INFO[group_id]
		local mods = mods_prefix(group.bind)
		local text = info.format_keys(mods, group.bind)
		add_entry(entries, seen, text, group.description, group_id, info.priority)
	end

	table.sort(entries, function(a, b)
		if a._priority ~= b._priority then
			return a._priority < b._priority
		end
		if a.Subtext == b.Subtext then
			return a.Text < b.Text
		end
		return (a.Subtext or "") < (b.Subtext or "")
	end)

	for _, entry in ipairs(entries) do
		entry._priority = nil
	end

	if #entries == 0 then
		table.insert(entries, {
			Text = "none",
			Subtext = "No keybinds found in hyprland.conf",
			Value = "none",
		})
	end

	return entries
end
