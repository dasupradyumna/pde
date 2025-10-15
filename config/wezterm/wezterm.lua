--------------------------------------- WEZTERM CONFIGURATION --------------------------------------
--- TODO:
--- 1. CharSelect key map
--- 2. Hyperlink rules
--- 3. IME pre-editing
--- 4. Launch menu
--- 5. Multiplexing - SSH and Domains
--- 6. Pane selection mode
--- 7. Quick select mode
--- 8. Key bindings and key tables
--- 9. Events
---   - gui-startup: setup workspaces
---   - augment-command-palette: add custom commands

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
config.switch_to_last_active_tab_when_closing_tab = true

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
config.font_locator = 'ConfigDirsOnly'
config.font_dirs = { 'fonts' }
config.font = wezterm.font_with_fallback { 'Hermit', 'Noto Sans Symbols', 'Noto Sans Symbols 2' }
config.font_size = 11
config.strikethrough_position = '0.5cell'
config.underline_position = '-0.2cell'

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
config.window_padding = { left = '0.8cell', right = '0.8cell', top = '0.4cell', bottom = '0.4cell' }

-- Tab bar
config.show_new_tab_button_in_tab_bar = false
config.tab_max_width = 25
config.use_fancy_tab_bar = false
wezterm.on('update-status', function(window) -- window: GuiWin
  local palette = window:effective_config().resolved_palette

  window:set_left_status(wezterm.format {
    { Attribute = { Intensity = 'Bold' } },
    { Foreground = { Color = palette.tab_bar.active_tab.fg_color } },
    { Background = { Color = palette.tab_bar.active_tab.bg_color } },
    { Text = ('  %s '):format(wezterm.hostname():upper()) },
  })

  window:set_right_status(wezterm.format {
    { Foreground = { Color = palette.ansi[5] } },
    { Text = ('%s '):format(wezterm.strftime '%H:%M:%S %a %d %b %Y') },
  })
end)
wezterm.on('format-tab-title', function(tab)
  -- DEBUG(
  --   ('tab_title:[%s] is_active:[%s] pane_title:[%s] foreground_process_name:[%s] cwd:[%s] domain_name:[%s]'):format(
  --     tab.tab_title,
  --     tab.is_active,
  --     tab.active_pane.title,
  --     tab.active_pane.foreground_process_name,
  --     tab.active_pane.current_working_dir,
  --     tab.active_pane.domain_name
  --   )
  -- )

  local title = tab.tab_title
  if #title == 0 then
    title = tab.active_pane.domain_name
    title = title ~= 'local' and title or tab.active_pane.title
  end
  local title_format = tab.is_active and ' %s ' or '  %s  '
  return title_format:format(title)
end)

----------------------------------- BINDINGS -----------------------------------

-- CHECK: custom bindings
-- config.disable_default_mouse_bindings = true

return config
