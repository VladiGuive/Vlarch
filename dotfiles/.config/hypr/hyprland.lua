---@module 'hl'

-- Frosted, clean Hyprland configuration.
-- Reload with: hyprctl reload

local mainMod = "SUPER"
local terminal = "kitty -e tmux"

hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = "auto",
})

hl.config({
    general = {
        gaps_in = 6,
        gaps_out = 12,
        border_size = 0,
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle",
    },

    decoration = {
        active_opacity = 0.94,
        inactive_opacity = 0.84,
        fullscreen_opacity = 1.0,

        rounding = 12,

        shadow = {
            enabled = false,
        },

        blur = {
            enabled = true,
            size = 8,
            passes = 3,
            vibrancy = 0.20,
            new_optimizations = true,
            xray = false,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
    },

    input = {
        kb_layout = "us",
        follow_mouse = 1,
        sensitivity = 0,
        scroll_method = "2fg",

        touchpad = {
            natural_scroll = false,
            scroll_factor = 1.0,
            disable_while_typing = true,
            tap_to_click = true,
            clickfinger_behavior = true,
        },
    },

    binds = {
        drag_threshold = 10,
    },
})

-- Applications
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + V", hl.dsp.window.float())
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
-- hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("vlarch-walker"))

-- Focus
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

-- Workspaces 1–10
for key, workspace in pairs({
    ["1"] = 1,
    ["2"] = 2,
    ["3"] = 3,
    ["4"] = 4,
    ["5"] = 5,
    ["6"] = 6,
    ["7"] = 7,
    ["8"] = 8,
    ["9"] = 9,
    ["0"] = 10,
}) do
    hl.bind(mainMod .. " + " .. key, hl.dsp.exec_cmd("vlarch-workspace goto " .. workspace))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.exec_cmd("vlarch-workspace move " .. workspace))
end

-- Move/resize windows with mainMod + LMB/RMB.
-- drag() and resize() are required here; move(nil)/resize(nil) is invalid.
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, drag = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, drag = true })

-- Multimedia keys
hl.bind(
    "XF86AudioRaiseVolume",
    hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
    { locked = true }
)
hl.bind(
    "XF86AudioLowerVolume",
    hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
    { locked = true }
)
hl.bind(
    "XF86AudioMute",
    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
    { locked = true }
)
hl.bind(
    "XF86AudioMicMute",
    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
    { locked = true }
)
hl.bind(
    "XF86MonBrightnessUp",
    hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),
    { locked = true }
)
hl.bind(
    "XF86MonBrightnessDown",
    hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),
    { locked = true }
)

-- Screenshots
-- hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(
--     "bash -c 'area=$(slurp) || exit 0; grim -g \"$area\" - | wl-copy'"
-- ))
-- hl.bind("SHIFT + Print", hl.dsp.exec_cmd("grim - | wl-copy"))
-- hl.bind(mainMod .. " + S", hl.dsp.exec_cmd(
--     "bash -c 'area=$(slurp) || exit 0; dir=\"$HOME/Pictures/Screenshots\"; mkdir -p \"$dir\"; grim -g \"$area\" \"$dir/$(date +%Y_%m_%d_%H_%M_%S).png\"'"
-- ))
-- hl.bind("Print", hl.dsp.exec_cmd(
--     "bash -c 'dir=\"$HOME/Pictures/Screenshots\"; mkdir -p \"$dir\"; grim \"$dir/$(date +%Y_%m_%d_%H_%M_%S).png\"'"
-- ))
