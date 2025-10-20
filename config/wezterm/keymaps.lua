------------------------------------------- KEY BINDINGS -------------------------------------------
--- TODO: list of unbound actions
--- AttachDomain | DetachDomain
--- Confirmation + InputSelector + PromptInputLine = custom menus?
--- EmitEvent for custom events (wezterm.emit)
--- OpenLinkAtMouseCursor
--- ShowLauncher
--- SpawnCommandInNewTab
--- SwitchToWorkspace
--- NOTE:
--- Clipboard is explicit, but primary selection is implicit with the mouse (only)

local M = {}

local action = require('wezterm').action

--- Creates a KeyAssignment object for WezTerm
local function key_assignment(spec)
  local key, act, mod = table.unpack(spec)
  return { key = key, mods = mod, action = act }
end

-- M.disable_default_mouse_bindings = true
M.disable_default_key_bindings = true
M.leader = { key = 'Space', mods = 'CTRL', timeout_milliseconds = 500 }
M.keys = {}
M.key_tables = {}

-- Global keybindings
local keys = {
  { ';', action.ActivateCommandPalette, 'LEADER' },
  { 'c', action.ActivateCopyMode, 'LEADER' },
  { 't', action.ActivateKeyTable { name = 'tab_mode', prevent_fallback = true }, 'LEADER' },
  { 'p', action.ActivateKeyTable { name = 'pane_mode', prevent_fallback = true }, 'LEADER' },
  { 'e', action.CharSelect {}, 'LEADER' },
  { 'y', action.CopyTo 'ClipboardAndPrimarySelection', 'LEADER' },
  { '-', action.DecreaseFontSize, 'CTRL' },
  { '=', action.IncreaseFontSize, 'CTRL' },
  { 'h', action.MoveTabRelative(-1), 'CTRL|SHIFT' },
  { 'l', action.MoveTabRelative(1), 'CTRL|SHIFT' },
  {
    'l',
    action.Multiple {
      action.ClearScrollback 'ScrollbackOnly', -- Clears terminal scrollback
      action.SendKey { key = 'l', mods = 'CTRL' }, -- Clears current viewport
    },
    'CTRL',
  },
  { 'v', action.PasteFrom 'Clipboard', 'LEADER' },
  { 'V', action.PasteFrom 'PrimarySelection', 'LEADER' },
  { 'q', action.QuickSelect, 'LEADER' }, -- CHECK: QuickSelectArgs
  { '0', action.ResetFontSize, 'CTRL' },
  { '/', action.Search 'CurrentSelectionOrEmptyString', 'LEADER' },
  { 'd', action.ShowDebugOverlay, 'LEADER' },
  { 'n', action.SpawnWindow, 'LEADER' },
  { 'z', action.TogglePaneZoomState, 'LEADER' },
}
for _, spec in ipairs(keys) do
  table.insert(M.keys, key_assignment(spec))
end

-- Key table definitions
local key_tables = {
  copy_mode = {
    -- Disable global keybindings that conflict with copy mode
    { 'e', action.DisableDefaultAssignment, 'LEADER' },
    { '/', action.DisableDefaultAssignment, 'LEADER' },
    { 'q', action.DisableDefaultAssignment, 'LEADER' },
    { 'y', action.DisableDefaultAssignment, 'LEADER' },
    -- Copy mode keybindings
    { 'c', action.CopyMode 'ClearSelectionMode', 'CTRL' },
    { '/', action.Search 'CurrentSelectionOrEmptyString' },
    { 'i', action.CopyMode 'EditPattern' },
    { ';', action.CopyMode 'JumpAgain' },
    { ',', action.CopyMode 'JumpReverse' },
    { 'F', action.CopyMode { JumpBackward = { prev_char = false } } },
    { 'T', action.CopyMode { JumpBackward = { prev_char = true } } },
    { 'f', action.CopyMode { JumpForward = { prev_char = false } } },
    { 't', action.CopyMode { JumpForward = { prev_char = true } } },
    { 'b', action.CopyMode 'MoveBackwardWord' },
    { 'u', action.CopyMode { MoveByPage = -0.5 }, 'CTRL' },
    { 'd', action.CopyMode { MoveByPage = 0.5 }, 'CTRL' },
    { 'j', action.CopyMode 'MoveDown' },
    { 'w', action.CopyMode 'MoveForwardWord' },
    { 'e', action.CopyMode 'MoveForwardWordEnd' },
    { 'h', action.CopyMode 'MoveLeft' },
    { 'l', action.CopyMode 'MoveRight' },
    { '$', action.CopyMode 'MoveToEndOfLineContent' },
    { 'G', action.CopyMode 'MoveToScrollbackBottom' },
    { 'g', action.CopyMode 'MoveToScrollbackTop' },
    { 's', action.CopyMode 'MoveToSelectionOtherEnd' },
    { '^', action.CopyMode 'MoveToStartOfLine' },
    { '0', action.CopyMode 'MoveToStartOfLineContent' },
    { 'J', action.CopyMode 'MoveToViewportBottom' },
    { 'K', action.CopyMode 'MoveToViewportTop' },
    { 'k', action.CopyMode 'MoveUp' },
    { 'v', action.CopyMode { SetSelectionMode = 'Cell' } },
    { 'V', action.CopyMode { SetSelectionMode = 'Line' } },
    { 'v', action.CopyMode { SetSelectionMode = 'Block' }, 'CTRL' },
    { 'y', action.CopyTo 'ClipboardAndPrimarySelection' },
    { 'n', action.Multiple { action.CopyMode 'NextMatch', action.CopyMode 'ClearSelectionMode' } },
    { 'N', action.Multiple { action.CopyMode 'PriorMatch', action.CopyMode 'ClearSelectionMode' } },
    { 'g', action.Multiple { action.ScrollToBottom, action.CopyMode 'Close' }, 'CTRL' },
  },
  search_mode = {
    -- Disable global keybindings that conflict with search mode
    { 'c', action.DisableDefaultAssignment, 'LEADER' },
    { 'e', action.DisableDefaultAssignment, 'LEADER' },
    { 'q', action.DisableDefaultAssignment, 'LEADER' },
    { 'y', action.DisableDefaultAssignment, 'LEADER' },
    -- Search mode keybindings
    {
      'c',
      action.Multiple { action.CopyMode 'AcceptPattern', action.CopyMode 'ClearSelectionMode' },
      'CTRL',
    },
    { 'u', action.CopyMode 'ClearPattern', 'CTRL' },
    { 'g', action.Multiple { action.ScrollToBottom, action.CopyMode 'Close' }, 'CTRL' },
    { 'm', action.CopyMode 'CycleMatchType', 'CTRL' },
  },
  tab_mode = {
    { 'p', action.ActivateLastTab },
    { '1', action.ActivateTab(0) },
    { '2', action.ActivateTab(1) },
    { '3', action.ActivateTab(2) },
    { '4', action.ActivateTab(3) },
    { '5', action.ActivateTab(4) },
    { '6', action.ActivateTab(5) },
    { '7', action.ActivateTab(6) },
    { '8', action.ActivateTab(7) },
    { '9', action.ActivateTab(8) },
    { 'h', action.ActivateTabRelative(-1) },
    { 'l', action.ActivateTabRelative(1) },
    { 'q', action.CloseCurrentTab { confirm = true } },
    { 'n', action.SpawnTab 'CurrentPaneDomain' },
    { 'c', action.PopKeyTable, 'CTRL' },
  },
  pane_mode = {
    { 'q', action.CloseCurrentPane { confirm = true } },
    { 'a', action.PaneSelect { mode = 'Activate' } },
    { 's', action.PaneSelect { mode = 'SwapWithActiveKeepFocus' } },
    { 't', action.PaneSelect { mode = 'MoveToNewTab' } },
    { 'h', action.SplitHorizontal { domain = 'CurrentPaneDomain' } },
    { 'v', action.SplitVertical { domain = 'CurrentPaneDomain' } },
    { 'c', action.PopKeyTable, 'CTRL' },
  },
}
for name, tbl in pairs(key_tables) do
  M.key_tables[name] = {}
  for _, spec in ipairs(tbl) do
    table.insert(M.key_tables[name], key_assignment(spec))
  end
end

return M
