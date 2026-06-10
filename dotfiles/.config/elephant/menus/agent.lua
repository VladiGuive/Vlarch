-- Vlarch: Walker fallback — ask Hermes when no app matches.
local L = dofile(os.getenv("HOME") .. "/.config/elephant/utils/locale.lua")

Name = "agent"
NamePretty = L.t("Vlarch Agent", "Agente Vlarch")
Icon = "vlarch-agent"
Cache = false
FixedOrder = true
Action = "lua:Activate"

local VLARCH_AGENT = "/usr/local/bin/vlarch-agent"

local function shell_quote(value)
	return "'" .. string.gsub(value, "'", "'\\''") .. "'"
end

function GetEntries(query)
	query = (query or ""):match("^%s*(.-)%s*$") or ""
	if query == "" then
		return {}
	end
	return {
		{
			Text = query,
			Subtext = query,
			Value = query,
		},
	}
end

function Activate(value, args, query)
	local q = query or value or ""
	q = q:match("^%s*(.-)%s*$") or ""
	if q == "" then
		return
	end
	os.execute(VLARCH_AGENT .. " " .. shell_quote(q) .. " &")
end
