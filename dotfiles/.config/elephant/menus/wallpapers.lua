-- Vlarch: wallpaper picker — lists wallpapers from Pictures/Wallpapers/,
-- Descargas/, and /usr/share/vlarch/wallpapers/. Pick one to apply instantly.
local L = dofile(os.getenv("HOME") .. "/.config/elephant/utils/locale.lua")

Name = "wallpapers"
NamePretty = L.t("Wallpapers", "Fondos de pantalla")
Icon = "preferences-desktop-wallpaper"
FixedOrder = true
Action = "lua:Activate"

local VLARCH_WALLPAPER = "/usr/local/bin/vlarch-wallpaper"
local HOME = os.getenv("HOME")

local WALLPAPER_DIRS = {
    HOME .. "/Pictures/Wallpapers",
    HOME .. "/Descargas",
    "/usr/share/vlarch/wallpapers",
}

local ACTIVE_FILE = HOME .. "/.local/share/vlarch/wallpaper"

local function shell_quote(value)
    return "'" .. string.gsub(value, "'", "'\\''") .. "'"
end

local function read_active_wallpaper()
    local handle = io.open(ACTIVE_FILE, "r")
    if not handle then
        return nil
    end
    -- It's a binary image, not a text file — check by stat instead
    handle:close()
    local attr = os.stat(ACTIVE_FILE)
    if attr and attr.type == "file" then
        return ACTIVE_FILE
    end
    return nil
end

local function description(path)
    -- Show folder-relative path as description
    for _, dir in ipairs(WALLPAPER_DIRS) do
        local prefix = dir .. "/"
        if string.sub(path, 1, #prefix) == prefix then
            local rel = string.sub(path, #prefix + 1)
            local label = ""
            if dir == (HOME .. "/Pictures/Wallpapers") then
                label = L.t("Wallpapers", "Fondos")
            elseif dir == (HOME .. "/Descargas") then
                label = L.t("Downloads", "Descargas")
            else
                label = L.t("Defaults", "Defecto")
            end
            return label .. " · " .. rel
        end
    end
    return path:match("([^/]+)$") or path
end

local function image_label(path)
    local name = path:match("([^/]+)$") or path
    -- Strip extension for display
    local label = name:gsub("%.[^.]+$", "")
    -- Clean up common naming artifacts
    label = label:gsub("[_]", " "):gsub("[-]", " ")
    -- Title-case first letter
    label = label:gsub("^%l", string.upper)
    return label
end

local function collect_images()
    local images = {}
    for _, dir in ipairs(WALLPAPER_DIRS) do
        local handle = io.popen(
            "find " .. shell_quote(dir) .. " -maxdepth 1 -type f \\(" ..
            " -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o" ..
            " -iname '*.webp' -o -iname '*.bmp' -o -iname '*.gif'" ..
            " \\) 2>/dev/null | sort"
        )
        if handle then
            for line in handle:lines() do
                if line ~= "" then
                    table.insert(images, line)
                end
            end
            handle:close()
        end
    end
    return images
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
    if value == "__pick__" then
        os.execute(VLARCH_WALLPAPER .. " pick &")
        return
    end

    os.execute(VLARCH_WALLPAPER .. " set " .. shell_quote(value))
end

function GetEntries()
    local entries = {}
    local images = collect_images()

    if #images == 0 then
        table.insert(entries, info_entry(
            L.t("No wallpapers found", "No se encontraron fondos"),
            L.t("Add images to ~/Pictures/Wallpapers/", "Añade imágenes en ~/Pictures/Wallpapers/"),
            "__info:no_wallpapers__",
            "dialog-warning"
        ))
        table.insert(entries, {
            Text = L.t("Browse...", "Examinar..."),
            Subtext = L.t("Pick a file with the file chooser", "Elegir un archivo con el selector"),
            Value = "__pick__",
            Icon = "document-open",
            Keywords = "browse open file choose examinar abrir elegir archivo",
        })
        return entries
    end

    local active = read_active_wallpaper()

    for _, path in ipairs(images) do
        local title = image_label(path)
        local subtext = description(path)
        local is_active = active and active == ACTIVE_FILE
            and os.stat(ACTIVE_FILE) and os.stat(path)
            and os.stat(ACTIVE_FILE).modification == os.stat(path).modification

        local icon
        if active then
            -- Compare by stat: if the active wallpaper has the same inode or
            -- modification time as this entry, it's the active one.
            local active_stat = os.stat(ACTIVE_FILE)
            local img_stat = os.stat(path)
            if active_stat and img_stat
                and active_stat.ino == img_stat.ino then
                is_active = true
            end
        end

        -- Use the file path as icon for a thumbnail preview
        icon = is_active and "emblem-default" or path

        if is_active then
            subtext = subtext .. " · " .. L.t("Active", "Activo")
        end

        table.insert(entries, {
            Text = title,
            Subtext = subtext,
            Value = path,
            Icon = icon,
            Keywords = "wallpaper fondo pantalla " .. title .. " " .. path:match("([^/]+)$"),
        })
    end

    -- Add "Browse..." at the bottom
    table.insert(entries, {
        Text = L.t("Browse...", "Examinar..."),
        Subtext = L.t("Pick any image file", "Elegir cualquier archivo de imagen"),
        Value = "__pick__",
        Icon = "document-open",
        Keywords = "browse open file choose examinar abrir elegir archivo",
    })

    return entries
end
