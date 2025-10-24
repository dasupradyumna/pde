------------------------------------ CONSTRUCT EXECUTION DOMAINS -----------------------------------

local wezterm = require 'wezterm'
local utils = require 'utils'

local docker = {}

---Return a list of docker container names
---@return table
function docker.container_list()
  -- TODO: check if docker is installed, config throws an error if not
  local docker_cmd = { 'docker', 'ps', '--all', '--format', '{{.Names}}' }
  local ok, stdout, error = wezterm.run_child_process(docker_cmd)
  if not ok then
    wezterm.log_error('exec_domains:: Failed to get docker container list\n', error)
    return {}
  end

  local list = {}
  for _, name in ipairs(wezterm.split_by_newlines(stdout)) do
    table.insert(list, name)
  end
  utils.log_debug('exec_domains:: Found containers', list)
  return list
end

---Returns a wrapper that starts a docker container (if needed) and executes a command inside it
---@param name string Target docker container name
---@return function
function docker.wrap_exec(name)
  return function(cmd)
    local exec_script = wezterm.config_dir .. '/exec-in-docker.sh'
    cmd.args = { exec_script, name }
    utils.log_debug('exec_domains:: Executing command:', cmd)
    return cmd
  end
end

---Returns a list of execution domains for docker containers
---@return table
function docker.exec_domains()
  local exec_domains = {}
  for _, name in ipairs(docker.container_list()) do
    table.insert(exec_domains, wezterm.exec_domain('  ' .. name, docker.wrap_exec(name)))
  end
  utils.log_debug('exec_domains:: Constructed exec domains', exec_domains)
  return exec_domains
end

return {
  docker = docker.exec_domains,
}
