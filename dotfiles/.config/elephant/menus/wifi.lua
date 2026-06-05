-- Vlarch: WiFi network picker (NetworkManager via vlarch-wifi).
Name = "wifi"
NamePretty = "WiFi"
Icon = "network-wireless"
FixedOrder = true
Action = "lua:Activate"

local VLARCH_WIFI = "/usr/local/bin/vlarch-wifi"

local function shell_quote(value)
	return "'" .. string.gsub(value, "'", "'\\''") .. "'"
end

local function read_wifi_data()
	local handle = io.popen(VLARCH_WIFI .. " --list-json 2>/dev/null")
	if not handle then
		return nil, "could not run vlarch-wifi"
	end
	local raw = handle:read("*a") or ""
	handle:close()
	raw = raw:match("^%s*(.-)%s*$")
	if raw == "" then
		return nil, "vlarch-wifi returned no data"
	end
	if jsonDecode then
		local ok, data = pcall(jsonDecode, raw)
		if ok and type(data) == "table" then
			return data, nil
		end
	end
	if raw:find('"available"%s*:%s*true') then
		return { available = true, parse_error = true, raw = raw }, nil
	end
	if raw:find('"available"%s*:%s*false') then
		return { available = false }, nil
	end
	return nil, "invalid wifi data"
end

local function info_entry(text, subtext, value, icon)
	return {
		Text = text,
		Subtext = subtext,
		Value = value,
		Icon = icon,
	}
end

local function signal_icon(signal)
	signal = tonumber(signal) or 0
	if signal < 25 then
		return "network-wireless-signal-none"
	elseif signal < 50 then
		return "network-wireless-signal-weak"
	elseif signal < 75 then
		return "network-wireless-signal-good"
	end
	return "network-wireless-signal-excellent"
end

local function network_value(ssid, bssid, security)
	return ssid .. string.char(31) .. (bssid or "") .. string.char(31) .. (security or "")
end

function Activate(value, args, query)
	if value == nil or value == "" then
		return
	end
	if string.sub(value, 1, 7) == "__info:" then
		return
	end
	os.execute(VLARCH_WIFI .. " connect " .. shell_quote(value))
end

function GetEntries()
	local entries = {}
	local data, err = read_wifi_data()

	if not data then
		table.insert(entries, info_entry(
			"WiFi unavailable",
			err or "Unknown error",
			"__info:error__",
			"dialog-error"
		))
		return entries
	end

	if not data.available then
		table.insert(entries, info_entry(
			"No WiFi adapter",
			"This machine has no wireless interface",
			"__info:no_adapter__",
			"network-wireless-disabled"
		))
		return entries
	end

	if data.parse_error then
		table.insert(entries, info_entry(
			"WiFi data error",
			"Could not parse network list; try rescan",
			"__info:parse_error__",
			"dialog-warning"
		))
		table.insert(entries, {
			Text = "Rescan networks",
			Subtext = "Refresh nearby access points",
			Value = "__rescan__",
			Icon = "view-refresh",
		})
		return entries
	end

	if data.radio then
		table.insert(entries, {
			Text = "Turn WiFi off",
			Subtext = "Disable the wireless radio",
			Value = "__toggle_radio__",
			Icon = "network-wireless-disabled",
			Keywords = "wifi radio off disable",
		})
	else
		table.insert(entries, {
			Text = "Turn WiFi on",
			Subtext = "Enable the wireless radio",
			Value = "__toggle_radio__",
			Icon = "network-wireless",
			Keywords = "wifi radio on enable",
		})
		return entries
	end

	if data.connected and data.connected.ssid then
		local connected = data.connected
		table.insert(entries, {
			Text = "Disconnect",
			Subtext = connected.ssid .. " (" .. tostring(connected.signal or 0) .. "%)",
			Value = "__disconnect__",
			Icon = "network-wireless-connected",
			Keywords = "wifi disconnect leave " .. connected.ssid,
		})
	end

	table.insert(entries, {
		Text = "Rescan networks",
		Subtext = "Refresh nearby access points",
		Value = "__rescan__",
		Icon = "view-refresh",
		Keywords = "wifi rescan refresh scan",
	})

	local seen = {}
	if data.networks then
		for _, net in ipairs(data.networks) do
			local ssid = net.ssid
			if ssid and ssid ~= "" and not seen[ssid] then
				seen[ssid] = true
				local subtext = tostring(net.signal or 0) .. "%"
				if net.security and net.security ~= "" and net.security ~= "--" then
					subtext = subtext .. " · " .. net.security
				else
					subtext = subtext .. " · Open"
				end
				if net.in_use then
					subtext = subtext .. " · Connected"
				end
				table.insert(entries, {
					Text = ssid,
					Subtext = subtext,
					Value = network_value(ssid, net.bssid, net.security),
					Icon = signal_icon(net.signal),
					Keywords = "wifi network wlan " .. ssid,
				})
			end
		end
	end

	if #entries <= 2 then
		table.insert(entries, info_entry(
			"No networks found",
			"Try rescanning or move closer to an access point",
			"__info:no_networks__",
			"network-wireless-offline"
		))
	end

	return entries
end
