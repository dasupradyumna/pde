------------------------------------------- KEY BINDINGS -------------------------------------------
--- TODO: list of unbound actions
--- Mouse-related keybindings
--- EmitEvent for custom events (wezterm.emit)
--- ShowLauncher(Args)
--- SpawnCommandInNewTab
--- NOTE:
--- Clipboard is explicit, but primary selection is implicit (only with mouse)

local wezterm = require 'wezterm'
local wezact = wezterm.action
local useract = require 'actions'

local M = {}

--- Creates a KeyAssignment object for WezTerm
local function key_assignment(spec)
  local key, act, mod = table.unpack(spec)
  return { key = key, mods = mod, action = act }
end

-- M.disable_default_mouse_bindings = true
M.disable_default_key_bindings = true
M.leader = { key = 'Space', mods = 'CTRL', timeout_milliseconds = 1000 }
M.keys = {}
M.key_tables = {}

-- Global keybindings
local keys = {
  { ';', wezact.ActivateCommandPalette, 'LEADER' },
  { 'c', wezact.ActivateCopyMode, 'LEADER' },
  { 't', wezact.ActivateKeyTable { name = 'tab_mode', prevent_fallback = true }, 'LEADER' },
  { 'p', wezact.ActivateKeyTable { name = 'pane_mode', prevent_fallback = true }, 'LEADER' },
  { 'Tab', wezact.ActivateTabRelative(-1), 'CTRL|SHIFT' },
  { 'Tab', wezact.ActivateTabRelative(1), 'CTRL' },
  { 'e', wezact.CharSelect {}, 'LEADER' },
  { 'y', wezact.CopyTo 'ClipboardAndPrimarySelection', 'LEADER' },
  { '-', wezact.DecreaseFontSize, 'CTRL' },
  { 'q', wezact.DetachDomain 'CurrentPaneDomain', 'LEADER' },
  { '=', wezact.IncreaseFontSize, 'CTRL' },
  { 'h', wezact.MoveTabRelative(-1), 'CTRL|SHIFT' },
  { 'l', wezact.MoveTabRelative(1), 'CTRL|SHIFT' },
  {
    'l',
    wezact.Multiple {
      wezact.ClearScrollback 'ScrollbackOnly', -- Clears terminal scrollback
      wezact.SendKey { key = 'l', mods = 'CTRL' }, -- Clears current viewport
    },
    'CTRL',
  },
  { 'v', wezact.PasteFrom 'Clipboard', 'LEADER' },
  { 'V', wezact.PasteFrom 'PrimarySelection', 'LEADER' },
  { 'Q', wezact.QuickSelect, 'LEADER' }, -- CHECK: QuickSelectArgs
  { '0', wezact.ResetFontSize, 'CTRL' },
  { '/', wezact.Search 'CurrentSelectionOrEmptyString', 'LEADER' },
  { 'l', wezact.ShowDebugOverlay, 'LEADER' },
  { 'n', wezact.SpawnWindow, 'LEADER' },
  { 'd', useract.SwitchDomain, 'LEADER' },
  { 'z', wezact.TogglePaneZoomState, 'LEADER' },
}
for _, spec in ipairs(keys) do
  table.insert(M.keys, key_assignment(spec))
end

-- Key table definitions
local key_tables = {
  copy_mode = {
    -- Disable global keybindings that conflict with copy mode
    { 'e', wezact.DisableDefaultAssignment, 'LEADER' },
    { '/', wezact.DisableDefaultAssignment, 'LEADER' },
    { 'q', wezact.DisableDefaultAssignment, 'LEADER' },
    { 'y', wezact.DisableDefaultAssignment, 'LEADER' },
    -- Copy mode keybindings
    { 'c', wezact.CopyMode 'ClearSelectionMode', 'CTRL' },
    { '/', wezact.Search 'CurrentSelectionOrEmptyString' },
    { 'i', wezact.CopyMode 'EditPattern' },
    { ';', wezact.CopyMode 'JumpAgain' },
    { ',', wezact.CopyMode 'JumpReverse' },
    { 'F', wezact.CopyMode { JumpBackward = { prev_char = false } } },
    { 'T', wezact.CopyMode { JumpBackward = { prev_char = true } } },
    { 'f', wezact.CopyMode { JumpForward = { prev_char = false } } },
    { 't', wezact.CopyMode { JumpForward = { prev_char = true } } },
    { 'b', wezact.CopyMode 'MoveBackwardWord' },
    { 'u', wezact.CopyMode { MoveByPage = -0.5 }, 'CTRL' },
    { 'd', wezact.CopyMode { MoveByPage = 0.5 }, 'CTRL' },
    { 'j', wezact.CopyMode 'MoveDown' },
    { 'w', wezact.CopyMode 'MoveForwardWord' },
    { 'e', wezact.CopyMode 'MoveForwardWordEnd' },
    { 'h', wezact.CopyMode 'MoveLeft' },
    { 'l', wezact.CopyMode 'MoveRight' },
    { '$', wezact.CopyMode 'MoveToEndOfLineContent' }, -- BUG: does not work
    { 'G', wezact.CopyMode 'MoveToScrollbackBottom' },
    { 'g', wezact.CopyMode 'MoveToScrollbackTop' },
    { 's', wezact.CopyMode 'MoveToSelectionOtherEnd' },
    { '^', wezact.CopyMode 'MoveToStartOfLine' },
    { '0', wezact.CopyMode 'MoveToStartOfLineContent' },
    { 'J', wezact.CopyMode 'MoveToViewportBottom' },
    { 'K', wezact.CopyMode 'MoveToViewportTop' },
    { 'k', wezact.CopyMode 'MoveUp' },
    { 'v', wezact.CopyMode { SetSelectionMode = 'Cell' } },
    { 'V', wezact.CopyMode { SetSelectionMode = 'Line' } },
    { 'v', wezact.CopyMode { SetSelectionMode = 'Block' }, 'CTRL' },
    {
      'y',
      wezact.Multiple {
        wezact.CopyTo 'ClipboardAndPrimarySelection',
        wezact.CopyMode 'ClearSelectionMode',
      },
    },
    { 'n', wezact.Multiple { wezact.CopyMode 'NextMatch', wezact.CopyMode 'ClearSelectionMode' } },
    { 'N', wezact.Multiple { wezact.CopyMode 'PriorMatch', wezact.CopyMode 'ClearSelectionMode' } },
    { 'g', wezact.Multiple { wezact.ScrollToBottom, wezact.CopyMode 'Close' }, 'CTRL' },
  },
  search_mode = {
    -- Disable global keybindings that conflict with search mode
    { 'c', wezact.DisableDefaultAssignment, 'LEADER' },
    { 'e', wezact.DisableDefaultAssignment, 'LEADER' },
    { 'q', wezact.DisableDefaultAssignment, 'LEADER' },
    { 'y', wezact.DisableDefaultAssignment, 'LEADER' },
    -- Search mode keybindings
    {
      'c',
      wezact.Multiple { wezact.CopyMode 'AcceptPattern', wezact.CopyMode 'ClearSelectionMode' },
      'CTRL',
    },
    { 'u', wezact.CopyMode 'ClearPattern', 'CTRL' },
    { 'g', wezact.Multiple { wezact.ScrollToBottom, wezact.CopyMode 'Close' }, 'CTRL' },
    { 'm', wezact.CopyMode 'CycleMatchType', 'CTRL' },
  },
  tab_mode = {
    { 'p', wezact.ActivateLastTab },
    { '1', wezact.ActivateTab(0) },
    { '2', wezact.ActivateTab(1) },
    { '3', wezact.ActivateTab(2) },
    { '4', wezact.ActivateTab(3) },
    { '5', wezact.ActivateTab(4) },
    { '6', wezact.ActivateTab(5) },
    { '7', wezact.ActivateTab(6) },
    { '8', wezact.ActivateTab(7) },
    { '9', wezact.ActivateTab(8) },
    { 'r', useract.ChangeTabTitle },
    { 'q', wezact.CloseCurrentTab { confirm = true } },
    { 'n', wezact.SpawnTab 'CurrentPaneDomain' },
    { 'c', wezact.PopKeyTable, 'CTRL' },
  },
  pane_mode = {
    { 'q', wezact.CloseCurrentPane { confirm = true } },
    { 'a', wezact.PaneSelect { mode = 'Activate' } },
    { 's', wezact.PaneSelect { mode = 'SwapWithActiveKeepFocus' } },
    { 't', wezact.PaneSelect { mode = 'MoveToNewTab' } },
    { 'v', wezact.SplitHorizontal { domain = 'CurrentPaneDomain' } },
    { 'h', wezact.SplitVertical { domain = 'CurrentPaneDomain' } },
    { 'c', wezact.PopKeyTable, 'CTRL' },
  },
}
for name, tbl in pairs(key_tables) do
  M.key_tables[name] = {}
  for _, spec in ipairs(tbl) do
    table.insert(M.key_tables[name], key_assignment(spec))
  end
end

return M
