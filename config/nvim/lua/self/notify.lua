--------------------------------------- NOTIFICATION MANAGER ---------------------------------------

local M = {}

--- Helper function to notify with a specific log level and prefix
--- @param level number The vim.log.levels value
--- @param prefix string The prefix to add to the message
--- @param message string The message to display
local function notify_with_level(level, prefix, message) vim.notify(prefix .. message, level) end

--- Display an info notification
--- @param message string The message to display
function M.info(message) notify_with_level(vim.log.levels.INFO, '[INFO] ', message) end

--- Display a warn notification
--- @param message string The message to display
function M.warn(message) notify_with_level(vim.log.levels.WARN, '[WARN] ', message) end

--- Display an error notification
--- @param message string The message to display
function M.error(message) notify_with_level(vim.log.levels.ERROR, '[ERROR] ', message) end

return M
