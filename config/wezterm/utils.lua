----------------------------------------- UTILITY FUNCTIONS ----------------------------------------

local M = {}

--- Debug logging for wezterm
function M.log_debug(...)
  if ENABLE_DEBUG_LOGGING then require('wezterm').log_info(...) end
end

--- Transforms a table by transforming each key-value pair
--- If f returns nothing, the key-value pair is skipped
--- If f returns nil as new key, then new value is inserted into output table
--- @param t table
--- @param f fun(k,v):any,any
--- @return table
function M.tbl_transform(t, f)
  local out = {}
  for k, v in pairs(t) do
    k, v = f(k, v)
    if not v then goto continue end
    if k then
      out[k] = v
    else
      table.insert(out, v)
    end
    ::continue::
  end
  return out
end

--- Extends t1 with t2, overwriting existing values in t1
--- @param t1 table
--- @param t2 table
function M.dict_extend(t1, t2)
  for k, v in pairs(t2) do
    t1[k] = v
  end
  return t1
end

--- Returns the keys of a dictionary
--- @param t table<string, any>
--- @return string[]
function M.dict_keys(t)
  local keys = {}
  for k in pairs(t) do
    table.insert(keys, k)
  end
  return keys
end

--- Checks if an item is in a list
--- @param list any[]
--- @param item any
--- @return boolean
function M.list_contains(list, item)
  for _, v in ipairs(list) do
    if v == item then return true end
  end
  return false
end

--- Extends l1 with l2
--- @param l1 any[]
--- @param l2 any[]
--- @return any[]
function M.list_extend(l1, l2)
  for _, v in ipairs(l2) do
    table.insert(l1, v)
  end
  return l1
end

return M
