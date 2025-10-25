------------------------------------------ CUSTOM ACTIONS ------------------------------------------

local wezterm = require 'wezterm'

local M = {}

M.ChangeTabTitle = wezterm.action.PromptInputLine {
  description = 'New tab title',
  action = wezterm.action_callback(function(window, _, title)
    if title then window:active_tab():set_title(title) end
  end),
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

M.SwitchDomain = wezterm.action_callback(function(window, pane)
  local domains = {}
  for _, domain in ipairs(DOMAINS.ssh) do
    ---@diagnostic disable-next-line: undefined-field
    if domain.multiplexing == 'WezTerm' then table.insert(domains, { label = domain.name }) end
  end
  for _, domain in ipairs(DOMAINS.unix) do
    table.insert(domains, { label = domain.name })
  end

  local current_domain = pane:get_domain_name()
  window:perform_action(
    wezterm.action.InputSelector {
      title = 'Domain Switcher',
      choices = domains,
      action = wezterm.action_callback(function(_, _, _, target_domain)
        wezterm.mux.get_domain(target_domain):attach()
        wezterm.mux.get_domain(current_domain):detach()
      end),
      fuzzy = true,
      fuzzy_description = 'Select target domain: ',
    },
    pane
  )
end)

return M
