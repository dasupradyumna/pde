--------------------------------------- WEZTERM CONFIGURATION --------------------------------------
--- TODO:
--- 1. Hyperlink rules
--- 2. IME pre-editing
--- 3. Launch menu
--- 5. Events
---   - gui-startup: setup workspaces
---   - augment-command-palette: add custom commands

-- Log debug statements
ENABLE_DEBUG_LOGGING = false

require 'actions'  -- Defines global variables
local utils = require 'utils'
local wezterm = require 'wezterm'

local config = wezterm.config_builder()

----------------------------------- BEHAVIOR -----------------------------------

-- Ensure wezterm windows are launched in a maximized state
wezterm.on('window-focus-changed', function (window)
    local overrides = window:get_config_overrides() or {}
    if not overrides.is_maximized then
        window:maximize()
        overrides.is_maximized = true
        window:set_config_overrides(overrides)
    end
end)

-- General
config.check_for_updates = false
config.enable_wayland = false
config.log_unknown_escape_sequences = true
config.pane_select_font = wezterm.font 'Hermit'
config.quote_dropped_files = 'WindowsAlwaysQuoted'
config.scrollback_lines = 10000

-- Tab bar
config.mouse_wheel_scrolls_tabs = false
config.switch_to_last_active_tab_when_closing_tab = true

-- Shell exit code handling
config.clean_exit_codes = { 0, 1, 130 }
config.exit_behavior = 'CloseOnCleanExit'
config.exit_behavior_messaging = 'Terse'

-- Quick select mode
config.quick_select_alphabet = 'asdfghjklqwertyiuopzxcvmbn'
-- config.quick_select_patterns = {} -- TODO:

---------------------------------- APPEARANCE ----------------------------------

-- Background
config.background = {
    {
        -- source = { File = wezterm.config_dir .. '/colors/dusk-moon.jpg' },
        -- hsb = { saturation = 0.5, brightness = 0.3 },
        source = { File = wezterm.config_dir .. '/colors/aurora-horizon.jpg' },
        hsb = { saturation = 0.8, brightness = 0.1 },
        vertical_align = 'Bottom',
    },
}

-- Cursor
config.force_reverse_video_cursor = true
config.hide_mouse_cursor_when_typing = true

-- Font
config.font_locator = 'ConfigDirsOnly'
config.font_dirs = { 'fonts' }
config.font = wezterm.font_with_fallback { 'Hermit', 'Noto Sans Symbols', 'Noto Sans Symbols 2' }
config.font_size = 10
config.line_height = 1.1
config.strikethrough_position = '0.5cell'
config.underline_position = '-0.2cell'

-- Colors
config.bold_brightens_ansi_colors = 'No'
config.color_scheme_dirs = { 'colors' }
config.color_scheme = 'Midnight'

-- Character selection mode
config.char_select_bg_color = '#1a1c1f'
config.char_select_fg_color = '#878d96'
config.char_select_font = wezterm.font 'Hermit'
config.char_select_font_size = 11

-- Command palette
config.command_palette_bg_color = '#1a1c1f'
config.command_palette_fg_color = '#878d96'
config.command_palette_font = wezterm.font 'Hermit'
config.command_palette_font_size = 10
config.command_palette_rows = 20
config.ui_key_cap_rendering = 'Emacs'

-- Window
config.adjust_window_size_when_changing_font_size = false
-- config.initial_rows = 40 -- CHECK: if this can be made dynamic
-- config.initial_cols = 160
config.window_content_alignment = { horizontal = 'Center', vertical = 'Center' }
config.window_decorations = 'NONE'
config.window_padding = { left = '0.8cell', right = '0.8cell', top = '0.4cell', bottom = '0.4cell' }

-- Tab bar
config.show_new_tab_button_in_tab_bar = false
config.tab_max_width = 25
config.use_fancy_tab_bar = false
local key_table_labels = {
    copy_mode = 'COPY',
    search_mode = 'SEARCH',
    workspace_mode = 'WORKSPACE',
    tab_mode = 'TAB',
    pane_mode = 'PANE',
}
local battery_icons = {
    value = { '󰂎', '󰁺', '󰁻', '󰁼', '󰁽', '󰁾', '󰁿', '󰂀', '󰂁', '󰂂', '󰁹' },
    state = { Charging = '󱐋', Full = '󱐋', Discharging = ' ', Unknown = ' ' },
}
wezterm.on('update-status', function (window)
    local palette = window:effective_config().resolved_palette
    local pane = window:active_pane()
    if not pane then return end

    window:set_left_status(wezterm.format {
        { Attribute = { Intensity = 'Bold' } },
        { Foreground = { Color = palette.tab_bar.active_tab.fg_color } },
        { Background = { Color = palette.tab_bar.active_tab.bg_color } },
        { Text = ('  %s '):format(pane:get_domain_name():upper()) },
        { Text = (' %s '):format(window:active_workspace():upper()) },
    })

    local active_kt = key_table_labels[window:active_key_table()]
    local meta = pane:get_metadata() or {}
    local battery_info = wezterm.battery_info()[1]  -- NOTE: only one battery
    local battery_charge = battery_info.state_of_charge * 100
    local battery_color = battery_charge <= 20 and 2 or battery_charge <= 70 and 4 or 3
    local battery_value = battery_icons.value[math.floor(battery_charge / 10) + 1]
    local battery_state = battery_icons.state[battery_info.state]

    window:set_right_status(wezterm.format {
        { Attribute = { Intensity = 'Bold' } },
        { Foreground = { Color = palette.ansi[2] } },
        { Text = meta.is_tardy and ('󱑌  %.3fs '):format(meta.since_last_response_ms / 1000) or '' },
        { Foreground = { Color = palette.ansi[6] } },
        { Text = active_kt and ('[%s] '):format(active_kt) or '' },
        { Foreground = { Color = palette.ansi[5] } },
        { Text = ('%s '):format(wezterm.strftime '%H:%M:%S %a %d %b %Y') },
        { Foreground = { Color = palette.ansi[battery_color] } },
        { Text = ('%s%s '):format(battery_value, battery_state) },
    })
end)
wezterm.on('format-tab-title', function (tab)
    local title = tab.tab_title
    if #title == 0 then title = tab.active_pane.title end
    local title_format = tab.is_active and ' %s ' or '  %s  '
    return title_format:format(title)
end)

-- Pane
config.inactive_pane_hsb = { saturation = 0.8, brightness = 0.7 }

---------------------------------- SUB-MODULES ---------------------------------

-- Configure domains
-- config.unix_domains = DOMAINS.unix
-- config.ssh_domains = DOMAINS.ssh
-- config.default_domain = 'mux:local'
-- config.exec_domains = require('exec_domains').docker()

-- Configure keymaps
utils.dict_extend(config, require 'keymaps')

return config
