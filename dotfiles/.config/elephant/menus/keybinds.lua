-- Vlarch: searchable Hyprland keybind reference (view-only).
local json = dofile(os.getenv("HOME") .. "/.config/elephant/utils/json.lua")

Name = "keybinds"
NamePretty = "Keybinds"
Icon = "preferences-desktop-keyboard-shortcuts"
Cache = false
Action = "true"
SearchName = true

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

local function format_keys(bind)
	local key = bind.key or ""
	if key == "" and bind.keycode and bind.keycode > 0 then
		key = "#" .. tostring(bind.keycode)
	end
	if key == "" then
		return ""
	end

	local mods = get_mods(bind.modmask)
	if #mods > 0 then
		return table.concat(mods, " + ") .. " + " .. key
	end
	return key
end

local function format_action(bind)
	if bind.description and bind.description ~= "" then
		return bind.description
	end

	local dispatcher = bind.dispatcher or ""
	local arg = bind.arg or ""
	if dispatcher == "" and arg == "" then
		return "bind"
	end
	if arg ~= "" then
		return dispatcher .. " " .. arg
	end
	return dispatcher
end

local function should_include(bind)
	if bind.mouse then
		return false
	end
	if bind.locked then
		return false
	end
	if bind.submap and bind.submap ~= "" then
		return false
	end
	return format_keys(bind) ~= ""
end

function GetEntries()
	local handle = io.popen("hyprctl binds -j 2>/dev/null")
	if not handle then
		return {
			{ Text = "hyprctl unavailable", Subtext = "Hyprland is not running", Value = "error" },
		}
	end

	local output = handle:read("*a")
	handle:close()

	if not output or output == "" then
		return {
			{ Text = "No binds returned", Subtext = "hyprctl binds -j was empty", Value = "empty" },
		}
	end

	local ok, data = pcall(json.decode, output)
	if not ok then
		return {
			{ Text = "JSON parse error", Subtext = tostring(data), Value = "error" },
		}
	end

	if type(data) ~= "table" then
		return {
			{ Text = "Unexpected hyprctl output", Subtext = "expected a JSON array", Value = "error" },
		}
	end

	local entries = {}
	for _, bind in ipairs(data) do
		if should_include(bind) then
			local keys = format_keys(bind)
			local action = format_action(bind)
			table.insert(entries, {
				Text = keys,
				Subtext = action,
				Value = keys,
				Icon = "preferences-desktop-keyboard-shortcuts",
			})
		end
	end

	table.sort(entries, function(a, b)
		if a.Text == b.Text then
			return (a.Subtext or "") < (b.Subtext or "")
		end
		return a.Text < b.Text
	end)

	if #entries == 0 then
		table.insert(entries, {
			Text = "No keybinds found",
			Subtext = "Check hyprland.conf bind entries",
			Value = "none",
		})
	end

	return entries
end
