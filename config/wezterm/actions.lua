------------------------------------------ CUSTOM ACTIONS ------------------------------------------

local utils = require 'utils'
local wezterm = require 'wezterm'
local action = wezterm.action
local mux = wezterm.mux

local M = {}

M.ChangeTabTitle = action.PromptInputLine {
  description = 'Change Active Tab Title',
  action = wezterm.action_callback(function(window, _, title)
    if title then window:active_tab():set_title(title) end
  end),
  prompt = 'New title: ',
}

------------------------------------ DOMAINS -----------------------------------

DOMAINS = {
  -- Use the unix domain socket by default; configure for tmux-like behavior
  unix = { { name = 'mux:local' } },
  -- SSH domains built from ~/.ssh/config
  ssh = { ['blr-dev-sn4'] = true },
}

-- CHECK: New Attach requests sometimes replace existing session
-- - VPN disconnection, logout did not affect the session
-- - Just a factor of time between logins?
for host in pairs(wezterm.enumerate_ssh_hosts()) do
  if host == 'blr-dev-sn' or host == 'sjc-dev-sn' or host == 'sjc-stage-sn' then goto continue end
  local host_has_wezterm = DOMAINS.ssh[host]
  local domain = { name = host, remote_address = host, multiplexing = 'None' }
  if host_has_wezterm then
    DOMAINS.ssh[host] = nil
    domain.multiplexing = 'WezTerm'
  end
  table.insert(DOMAINS.ssh, domain)
  ::continue::
end

M.SwitchDomain = action.InputSelector {
  title = 'Domain Switcher',
  choices = utils.list_extend(
    utils.tbl_transform(DOMAINS.unix, function(_, v) return nil, { label = v.name } end),
    utils.tbl_transform(DOMAINS.ssh, function(_, v)
      if v.multiplexing == 'None' then return nil end
      return nil, { label = v.name }
    end)
  ),
  action = wezterm.action_callback(function(_, pane, _, target_domain)
    if not target_domain then return end
    local current_domain = pane:get_domain_name()
    if current_domain == target_domain then return end
    mux.get_domain(target_domain):attach()
    mux.get_domain(current_domain):detach()
  end),
  fuzzy = true,
  fuzzy_description = 'Select target domain: ',
}

---------------------------------- WORKSPACES ----------------------------------

WORKSPACES = {
}

local function get_all_workspaces()
  local ws_list = mux.get_workspace_names()
  for ws in pairs(WORKSPACES) do
    if not utils.list_contains(ws_list, ws) then table.insert(ws_list, ws) end
  end
  return ws_list
end

local function workspace_name_prompt(callback)
  return wezterm.action_callback(function(window, pane, new_name)
    if not new_name then return end
    if not utils.list_contains(get_all_workspaces(), new_name) then
      callback(new_name)
    else
      window:perform_action(
        action.PromptInputLine {
          description = ('Workspace Named "%s" Already Exists!'):format(new_name),
          action = workspace_name_prompt(callback),
          prompt = 'New name: ',
        },
        pane
      )
    end
  end)
end

M.CreateWorkspace = action.PromptInputLine {
  description = 'Create New Workspace',
  action = workspace_name_prompt(function(name)
    mux.spawn_window { workspace = name }
    mux.set_active_workspace(name)
  end),
  prompt = 'New Name: ',
}

M.RenameWorkspace = wezterm.action_callback(function(window, pane)
  local current = window:active_workspace()
  local prompt_action = {
    description = 'Change Active Workspace Name',
    action = workspace_name_prompt(function(name) mux.rename_workspace(current, name) end),
    prompt = 'New name: ',
  }
  for ws in pairs(WORKSPACES) do
    if ws == current then
      prompt_action = {
        description = 'Pre-defined Workspace - Rename Not Allowed!',
        action = wezterm.action_callback(function() end),
        prompt = 'PROMPT WILL BE IGNORED: ',
      }
      break
    end
  end

  window:perform_action(action.PromptInputLine(prompt_action), pane)
end)

M.SwitchWorkspace = wezterm.action_callback(function(window, pane)
  local choices = utils.tbl_transform(
    get_all_workspaces(),
    function(_, v) return nil, { label = v } end
  )

  window:perform_action(
    action.InputSelector {
      title = 'Workspace Switcher',
      choices = choices,
      action = wezterm.action_callback(function(_, _, _, target_workspace)
        if not target_workspace then return end
        local current_workspace = window:active_workspace()
        if current_workspace == target_workspace then return end
        if not utils.list_contains(mux.get_workspace_names(), target_workspace) then
          WORKSPACES[target_workspace]()
        end
        mux.set_active_workspace(target_workspace)
      end),
      fuzzy = true,
      fuzzy_description = 'Select target workspace: ',
    },
    pane
  )
end)

return M
