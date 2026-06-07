-- Vlarch: pick English or Spanish strings from the session locale.
local M = {}

local function primary_lang()
	local raw = os.getenv("LC_MESSAGES") or os.getenv("LANG") or "en"
	return (raw:match("^([^%.@]+)") or raw):lower()
end

function M.is_spanish()
	return primary_lang():match("^es") ~= nil
end

function M.t(en, es)
	if M.is_spanish() then
		return es
	end
	return en
end

return M
