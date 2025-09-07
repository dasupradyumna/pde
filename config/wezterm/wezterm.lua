--------------------------------------- WEZTERM CONFIGURATION --------------------------------------
--- TODO:
--- 1. CharSelect key map
--- 2. Customize font and freetype
--- 3. Hyperlink rules
--- 4. IME pre-editing
--- 5. Launch menu
--- 6. Multiplexing - SSH and Domains
--- 7. Pane selection mode
--- 8. Quick select mode
--- 9. Key bindings and key tables

local wezterm = require 'wezterm'

local config = wezterm.config_builder()

----------------------------------- BEHAVIOR -----------------------------------

config.enable_wayland = false
config.log_unknown_escape_sequences = true
-- config.mux_enable_ssh_agent = ...
config.quote_dropped_files = 'WindowsAlwaysQuoted'
config.scrollback_lines = 10000

-- Tab Bar
config.mouse_wheel_scrolls_tabs = false
config.show_new_tab_button_in_tab_bar = false
config.switch_to_last_active_tab_when_closing_tab = true
config.tab_max_width = 25
config.use_fancy_tab_bar = false

-- Disable update check
config.check_for_updates = false
config.check_for_updates_interval_seconds = 0

-- Shell exit code handling
config.clean_exit_codes = { 0, 1, 130 }
config.exit_behavior = 'CloseOnCleanExit'
config.exit_behavior_messaging = 'Terse'

---------------------------------- APPEARANCE ----------------------------------

-- Cursor
config.animation_fps = 1
config.cursor_blink_rate = 400
config.force_reverse_video_cursor = true
config.hide_mouse_cursor_when_typing = true

-- Font
config.font_dirs = { 'fonts' }
config.font_locator = 'ConfigDirsOnly'
-- config.cell_width = ...
-- config.line_height = ...
config.strikethrough_position = '0.5cell'
config.underline_position = -3

-- Colors
config.bold_brightens_ansi_colors = 'No' -- CHECK: if any software assuming this to be true breaks
config.color_scheme_dirs = { 'colors' }
config.color_scheme = 'Midnight'

-- Command Palette
config.command_palette_bg_color = '#1a1c1f'
config.command_palette_fg_color = '#878d96'
config.command_palette_font = wezterm.font 'Hermit'
config.command_palette_font_size = 11
config.command_palette_rows = 20
config.ui_key_cap_rendering = 'Emacs'

-- Window
config.adjust_window_size_when_changing_font_size = false
config.initial_rows = 40
config.initial_cols = 160
config.window_content_alignment = { horizontal = 'Center', vertical = 'Center' }
config.window_decorations = 'NONE'
config.window_padding = { left = '0.5cell', right = '0.5cell', top = 0, bottom = 0 }

----------------------------------- BINDINGS -----------------------------------

-- CHECK: custom bindings
-- config.disable_default_mouse_bindings = true

return config
