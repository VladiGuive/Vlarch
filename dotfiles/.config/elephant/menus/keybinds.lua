-- Vlarch: curated keybind reference (view-only). Edit here when hyprland.conf binds change.
local L = dofile(os.getenv("HOME") .. "/.config/elephant/utils/locale.lua")

Name = "keybinds"
NamePretty = L.t("Keybinds", "Atajos de teclado")
Icon = "preferences-desktop-keyboard-shortcuts"
Cache = true
FixedOrder = true
Action = "true"
SearchName = true

-- Listed top-to-bottom (most important first). Elephant sorts alphabetically unless FixedOrder is set.
local BINDS = {
	{
		keys = "Super + Space",
		desc = L.t("Open application launcher (Walker)", "Abrir el lanzador de aplicaciones (Walker)"),
		keywords = "walker launcher search run lanzador buscar",
	},
	{
		keys = "Super + K",
		desc = L.t("Open this keybind reference", "Abrir esta referencia de atajos"),
		keywords = "keybinds shortcuts help atajos teclado ayuda",
	},
	{
		keys = "$",
		desc = L.t("Open theme picker in Walker (then pick a palette)", "Abrir selector de temas en Walker"),
		keywords = "theme colors palette walker temas colores",
	},
	{
		keys = "!",
		desc = L.t(
			"Open todos in Walker (type a task and press Enter to save)",
			"Abrir tareas en Walker (escribe una tarea y pulsa Enter para guardar)"
		),
		keywords = "todo task list walker tareas",
	},
	{
		keys = "Super + Enter",
		desc = L.t("Open terminal", "Abrir terminal"),
		keywords = "kitty tmux shell terminal",
	},
	{
		keys = "Print",
		desc = L.t(
			"Screenshot all screens to ~/Pictures/Screenshots/",
			"Captura de todas las pantallas en ~/Pictures/Screenshots/"
		),
		keywords = "grim screenshot capture screen file save captura pantalla guardar",
	},
	{
		keys = "Shift + Print",
		desc = L.t("Screenshot all screens to clipboard", "Captura de todas las pantallas al portapapeles"),
		keywords = "grim screenshot capture screen clipboard captura pantalla portapapeles",
	},
	{
		keys = "Super + S",
		desc = L.t(
			"Screenshot region to ~/Pictures/Screenshots/",
			"Captura de una región en ~/Pictures/Screenshots/"
		),
		keywords = "grim slurp area select screenshot file save captura region area guardar",
	},
	{
		keys = "Super + Shift + S",
		desc = L.t("Screenshot region to clipboard", "Captura de una región al portapapeles"),
		keywords = "grim slurp area select screenshot clipboard captura region portapapeles",
	},
	{
		keys = "Super + Q",
		desc = L.t("Close focused window", "Cerrar la ventana enfocada"),
		keywords = "kill close quit cerrar ventana",
	},
	{
		keys = "Super + ↑ ↓ ← →",
		desc = L.t("Change focus between windows", "Cambiar el foco entre ventanas"),
		keywords = "focus move arrow direction foco ventana flecha",
	},
	{
		keys = "Super + 1…0",
		desc = L.t(
			"Switch workspace on the focused monitor (0 = workspace 10)",
			"Cambiar de espacio de trabajo en el monitor enfocado (0 = espacio 10)"
		),
		keywords = "workspace desktop monitor goto escritorio espacio monitor",
	},
	{
		keys = "Super + V",
		desc = L.t("Toggle floating on focused window", "Alternar flotante en la ventana enfocada"),
		keywords = "float tile flotante ventana",
	},
	{
		keys = "Super + F",
		desc = L.t(
			"Fullscreen content inside the tile (keeps browser tabs and toolbar)",
			"Pantalla completa del contenido en el mosaico (mantiene pestañas y barra del navegador)"
		),
		keywords = "fullscreen maximize video pantalla completa maximizar",
	},
	{
		keys = "Super + left click",
		desc = L.t("Move window by dragging", "Mover ventana arrastrando"),
		keywords = "mouse drag move window raton arrastrar mover ventana",
	},
	{
		keys = "Super + right click",
		desc = L.t("Resize window by dragging", "Redimensionar ventana arrastrando"),
		keywords = "mouse drag resize raton arrastrar redimensionar ventana",
	},
	{
		keys = "Super + scroll ↑↓",
		desc = L.t("Cycle workspace on the focused monitor", "Recorrer espacios de trabajo en el monitor enfocado"),
		keywords = "workspace next previous scroll wheel escritorio siguiente anterior rueda",
	},
	{
		keys = "Super + Shift + 1…0",
		desc = L.t(
			"Move window to workspace on the focused monitor (0 = workspace 10)",
			"Mover ventana al espacio de trabajo en el monitor enfocado (0 = espacio 10)"
		),
		keywords = "workspace move window shift escritorio mover ventana",
	},
}

function GetEntries()
	local entries = {}
	for _, bind in ipairs(BINDS) do
		table.insert(entries, {
			Text = bind.keys,
			Subtext = bind.desc,
			Value = bind.keys,
			Keywords = bind.keywords,
			Icon = "preferences-desktop-keyboard-shortcuts",
		})
	end
	return entries
end
