-- Vlarch: theme picker — lists ~/.config/.themes/*.json and runs vlarch-theme-generate.
local L = dofile(os.getenv("HOME") .. "/.config/elephant/utils/locale.lua")

Name = "themes"
NamePretty = L.t("Themes", "Temas")
Icon = "preferences-desktop-theme"
FixedOrder = true
Action = "lua:Activate"

local THEMES_DIR = os.getenv("HOME") .. "/.config/.themes"
local ACTIVE_FILE = os.getenv("HOME") .. "/.config/vlarch/active-theme"

local function shell_quote(value)
	return "'" .. string.gsub(value, "'", "'\\''") .. "'"
end

local function resolve_generate()
	local handle = io.popen("command -v vlarch-theme-generate 2>/dev/null")
	if not handle then
		return nil
	end
	local path = handle:read("*l")
	handle:close()
	if path and path ~= "" then
		return path
	end
	return nil
end

local function read_active_theme()
	local handle = io.open(ACTIVE_FILE, "r")
	if not handle then
		return nil
	end
	local path = handle:read("*l")
	handle:close()
	if path and path ~= "" then
		return path
	end
	return nil
end

local function theme_label(path)
	local name = path:match("([^/]+)$") or path
	return name:gsub("%.json$", "")
end

local function theme_title(data, fallback)
	if type(data) == "table" and type(data.name) == "string" and data.name ~= "" then
		return data.name
	end
	return fallback
end

local function read_theme_name(path)
	local handle = io.open(path, "r")
	if not handle then
		return nil
	end
	local raw = handle:read("*a") or ""
	handle:close()
	if jsonDecode then
		local ok, data = pcall(jsonDecode, raw)
		if ok and type(data) == "table" then
			return theme_title(data, theme_label(path))
		end
	end
	return theme_label(path)
end

local function list_theme_files()
	local files = {}
	local handle = io.popen(
		"find "
			.. shell_quote(THEMES_DIR)
			.. " -maxdepth 1 -type f -name '*.json' -printf '%f\\n' 2>/dev/null | sort"
	)
	if not handle then
		return files
	end
	for line in handle:lines() do
		if line ~= "" then
			table.insert(files, THEMES_DIR .. "/" .. line)
		end
	end
	handle:close()
	return files
end

local function info_entry(text, subtext, value, icon)
	return {
		Text = text,
		Subtext = subtext,
		Value = value,
		Icon = icon,
	}
end

function Activate(value, args, query)
	if value == nil or value == "" then
		return
	end
	if string.sub(value, 1, 7) == "__info:" then
		return
	end

	local generate = resolve_generate()
	if not generate then
		return
	end

	os.execute(generate .. " " .. shell_quote(value))
end

function GetEntries()
	local entries = {}
	local active = read_active_theme()
	local files = list_theme_files()

	if #files == 0 then
		table.insert(
			entries,
			info_entry(
				L.t("No themes found", "No se encontraron temas"),
				L.t("Add *.json files to ~/.config/.themes/", "Añade archivos *.json en ~/.config/.themes/"),
				"__info:no_themes__",
				"dialog-warning"
			)
		)
		return entries
	end

	for _, path in ipairs(files) do
		local title = read_theme_name(path)
		local subtext = path:match("([^/]+)$") or path
		if active == path then
			subtext = subtext .. " · " .. L.t("Active", "Activo")
		end
		table.insert(entries, {
			Text = title,
			Subtext = subtext,
			Value = path,
			Icon = active == path and "emblem-default" or "color-picker",
			Keywords = "theme colors palette tema colores " .. title .. " " .. subtext,
		})
	end

	return entries
end
