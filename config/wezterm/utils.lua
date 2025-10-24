----------------------------------------- UTILITY FUNCTIONS ----------------------------------------

local M = {}

--- Debug logging for wezterm
function M.log_debug(...)
  if ENABLE_DEBUG_LOGGING then require('wezterm').log_info(...) end
end

--- Extends t1 with t2, overwriting existing values in t1
--- @param t1 table
--- @param t2 table
function M.tbl_extend(t1, t2)
  for k, v in pairs(t2) do
    t1[k] = v
  end
end

return M
