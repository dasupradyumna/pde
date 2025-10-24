---------------------------------------- MULTIPLEXER DOMAINS ---------------------------------------

local wezterm = require 'wezterm'

local M = {}

-- Use the unix domain socket by default; configure for tmux-like behavior
M.default_domain = 'mux'
M.unix_domains = { { name = 'mux' } }

-- SSH domains built from ~/.ssh/config
M.ssh_domains = {}
local hosts_with_wezterm = { ['blr-dev-sn4'] = true }
for host in pairs(wezterm.enumerate_ssh_hosts()) do
  if host == 'blr-dev-sn' or host == 'sjc-dev-sn' or host == 'sjc-stage-sn' then goto continue end
  local host_has_wezterm = hosts_with_wezterm[host]
  table.insert(M.ssh_domains, {
    name = host_has_wezterm and ('MUX:%s'):format(host) or host,
    remote_address = host,
    multiplexing = host_has_wezterm and 'WezTerm' or 'None',
  })
  ::continue::
end

return M
