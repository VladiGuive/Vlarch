-- Vlarch: WiFi network picker (NetworkManager via vlarch-wifi).
Name = "wifi"
NamePretty = "WiFi"
Icon = "network-wireless"
SearchName = true
FixedOrder = true
Action = "vlarch-wifi connect %VALUE%"

local function read_wifi_data()
	local handle = io.popen("vlarch-wifi --list-json 2>/dev/null")
	if not handle then
		return nil
	end
	local raw = handle:read("*a") or ""
	handle:close()
	if raw == "" then
		return nil
	end
	if jsonDecode then
		local ok, data = pcall(jsonDecode, raw)
		if ok then
			return data
		end
	end
	return nil
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

function GetEntries()
	local entries = {}
	local data = read_wifi_data()

	if not data or not data.available then
		table.insert(entries, {
			Text = "No WiFi adapter",
			Subtext = "This machine has no wireless interface",
			Value = "",
			Icon = "network-wireless-disabled",
		})
		return entries
	end

	if data.radio then
		table.insert(entries, {
			Text = "Turn WiFi off",
			Subtext = "Disable the wireless radio",
			Value = "__toggle_radio__",
			Icon = "network-wireless-disabled",
		})
	else
		table.insert(entries, {
			Text = "Turn WiFi on",
			Subtext = "Enable the wireless radio",
			Value = "__toggle_radio__",
			Icon = "network-wireless",
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
		})
	end

	table.insert(entries, {
		Text = "Rescan networks",
		Subtext = "Refresh nearby access points",
		Value = "__rescan__",
		Icon = "view-refresh",
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
		table.insert(entries, {
			Text = "No networks found",
			Subtext = "Try rescanning or move closer to an access point",
			Value = "",
			Icon = "network-wireless-offline",
		})
	end

	return entries
end
