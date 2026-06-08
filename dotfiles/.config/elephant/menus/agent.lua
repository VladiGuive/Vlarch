-- Vlarch: Walker fallback — ask Hermes when no app matches.
local L = dofile(os.getenv("HOME") .. "/.config/elephant/utils/locale.lua")

Name = "agent"
NamePretty = L.t("AI Agent", "Agente IA")
Icon = "dialog-question"
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
			Text = L.t("Ask AI", "Preguntar a la IA"),
			Subtext = query,
			Value = query,
			Icon = "dialog-question",
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
