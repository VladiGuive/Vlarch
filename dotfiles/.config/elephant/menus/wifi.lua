-- Vlarch: WiFi network picker (NetworkManager via vlarch-wifi).
local L = dofile(os.getenv("HOME") .. "/.config/elephant/utils/locale.lua")

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
		return nil, L.t("could not run vlarch-wifi", "no se pudo ejecutar vlarch-wifi")
	end
	local raw = handle:read("*a") or ""
	handle:close()
	raw = raw:match("^%s*(.-)%s*$")
	if raw == "" then
		return nil, L.t("vlarch-wifi returned no data", "vlarch-wifi no devolvió datos")
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
	return nil, L.t("invalid wifi data", "datos de WiFi inválidos")
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

local function network_value(ssid)
	return ssid
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
	local ok, result = pcall(function()
		return build_entries()
	end)
	if ok and type(result) == "table" then
		return result
	end
	return {
		info_entry(
			L.t("WiFi menu error", "Error en el menú de WiFi"),
			tostring(result),
			"__info:error__",
			"dialog-error"
		),
	}
end

function build_entries()
	local entries = {}
	local data, err = read_wifi_data()

	if not data then
		table.insert(entries, info_entry(
			L.t("WiFi unavailable", "WiFi no disponible"),
			err or L.t("Unknown error", "Error desconocido"),
			"__info:error__",
			"dialog-error"
		))
		return entries
	end

	if not data.available then
		table.insert(entries, info_entry(
			L.t("No WiFi adapter", "Sin adaptador WiFi"),
			L.t("This machine has no wireless interface", "Este equipo no tiene interfaz inalámbrica"),
			"__info:no_adapter__",
			"network-wireless-disabled"
		))
		return entries
	end

	if data.parse_error then
		table.insert(entries, info_entry(
			L.t("WiFi data error", "Error en los datos de WiFi"),
			L.t("Could not parse network list; try rescan", "No se pudo leer la lista de redes; intenta reescanear"),
			"__info:parse_error__",
			"dialog-warning"
		))
		table.insert(entries, {
			Text = L.t("Rescan networks", "Reescanear redes"),
			Subtext = L.t("Refresh nearby access points", "Actualizar puntos de acceso cercanos"),
			Value = "__rescan__",
			Icon = "view-refresh",
		})
		return entries
	end

	if data.radio then
		table.insert(entries, {
			Text = L.t("Turn WiFi off", "Apagar WiFi"),
			Subtext = L.t("Disable the wireless radio", "Desactivar la radio inalámbrica"),
			Value = "__toggle_radio__",
			Icon = "network-wireless-disabled",
			Keywords = "wifi radio off disable apagar desactivar",
		})
	else
		table.insert(entries, {
			Text = L.t("Turn WiFi on", "Encender WiFi"),
			Subtext = L.t("Enable the wireless radio", "Activar la radio inalámbrica"),
			Value = "__toggle_radio__",
			Icon = "network-wireless",
			Keywords = "wifi radio on enable encender activar",
		})
		return entries
	end

	if data.connected and data.connected.ssid then
		local connected = data.connected
		table.insert(entries, {
			Text = L.t("Disconnect", "Desconectar"),
			Subtext = connected.ssid .. " (" .. tostring(connected.signal or 0) .. "%)",
			Value = "__disconnect__",
			Icon = "network-wireless-connected",
			Keywords = "wifi disconnect leave desconectar " .. connected.ssid,
		})
	end

	table.insert(entries, {
		Text = L.t("Rescan networks", "Reescanear redes"),
		Subtext = L.t("Refresh nearby access points", "Actualizar puntos de acceso cercanos"),
		Value = "__rescan__",
		Icon = "view-refresh",
		Keywords = "wifi rescan refresh scan reescanear actualizar",
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
					subtext = subtext .. " · " .. L.t("Open", "Abierta")
				end
				if net.in_use then
					subtext = subtext .. " · " .. L.t("Connected", "Conectada")
				end
				table.insert(entries, {
					Text = ssid,
					Subtext = subtext,
					Value = network_value(ssid),
					Icon = signal_icon(net.signal),
					Keywords = "wifi network wlan red " .. ssid,
				})
			end
		end
	end

	if #entries <= 2 then
		table.insert(entries, info_entry(
			L.t("No networks found", "No se encontraron redes"),
			L.t("Try rescanning or move closer to an access point", "Intenta reescanear o acércate a un punto de acceso"),
			"__info:no_networks__",
			"network-wireless-offline"
		))
	end

	return entries
end
