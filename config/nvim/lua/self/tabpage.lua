------------------------------------------ TABPAGE MANAGER -----------------------------------------

local tabpage = {}

---Get the name of a tabpage
---@param tabid integer Tabpage ID
---@param default? string Default tabpage name
---@return string # Tabpage name
function tabpage.get_name(tabid, default)
    default = default or ''
    local ok, name = pcall(vim.api.nvim_tabpage_get_var, tabid, 'tabpage_name')
    return ok and name or default
end

---Set the name of a tabpage
---@param tabid integer Tabpage ID
---@param name string New tabpage name
function tabpage.set_name(tabid, name) vim.api.nvim_tabpage_set_var(tabid, 'tabpage_name', name) end

--- Prompt the user to set the name of a tabpage
---@param tabid integer Tabpage ID
---@param curr_name? string Current tabpage name
---@return boolean # True if the name was successfully set
local function prompt_and_set_name(tabid, curr_name)
    -- Create a list of existing tabpage names
    local existing_names = vim.iter(vim.api.nvim_list_tabpages()):fold({}, function (dict, t)
        if t ~= tabid then dict[tabpage.get_name(t, 'NO_NAME')] = true end
        return dict
    end)

    local MAX_LEN_NAME = 15
    local msg = ''
    while #msg ~= 4 do  -- break on 'pass' or 'fail'
        vim.cmd 'redraw'
        vim.api.nvim_echo({ { msg, 'WarningMsg' } }, false, {})

        -- Synchronous user input
        vim.ui.input(
            {
                ---Callback for dynamic prompt highlighting
                ---@param name string String from prompt
                ---@return table # Highlight table
                highlight = function (name)
                    -- Error highlight characters beyond max length
                    if #name > MAX_LEN_NAME then return { { MAX_LEN_NAME, #name, 'ErrorMsg' } } end
                    -- Error highlight for conflict with existing or reserved names
                    if existing_names[name] or name == 'NO_NAME' then
                        return { { 0, #name, 'ErrorMsg' } }
                    end
                    return {}
                end,
                prompt = ' Set tabpage name: ',
                default = curr_name or '',
            },
            ---Callback for user input processing
            ---@param name? string String from prompt (if any)
            function (name)
                name = name or curr_name
                if not name then                  -- Exit: cancelled prompt
                    msg = 'fail'
                elseif name == '' then            -- Check: name empty
                    msg = ' Name cannot be empty.'
                elseif name == 'NO_NAME' then     -- Check: reserved name
                    msg = ' "NO_NAME" is reserved.'
                elseif existing_names[name] then  -- Check: name already taken
                    msg = (' Name "%s" is already taken.'):format(name)
                elseif #name > MAX_LEN_NAME then  -- Check: name too long
                    msg = (' Name "%s" is too long.'):format(name)
                else                              -- Exit: set name success
                    msg = 'pass'
                    tabpage.set_name(tabid, name)
                    vim.cmd 'redrawtabline'
                end
            end
        )
    end

    return msg == 'pass'
end

---Update the internal tabpage name list
function tabpage.update_name_list()
    tabpage.names = vim.iter(vim.api.nvim_list_tabpages()):map(function (tabid)
        return tabpage.get_name(tabid, 'NO_NAME')
    end):totable()
end

---Create a new tabpage with a user-chosen name
function tabpage.create()
    vim.cmd 'tabnew'
    local ret = prompt_and_set_name(vim.api.nvim_get_current_tabpage())
    if not ret then vim.cmd 'tabclose' end  -- Close created tabpage if cancelled
    tabpage.update_name_list()
end

---Rename the current tabpage
function tabpage.rename()
    local tabid = vim.api.nvim_get_current_tabpage()
    prompt_and_set_name(tabid, tabpage.get_name(tabid))
    tabpage.update_name_list()
end

---Move the current tabpage left or right
---@param dir '+' | '-' Move direction
function tabpage.move(dir)
    local curr = vim.fn.tabpagenr()
    local last = vim.fn.tabpagenr '$'
    -- Prevent moving left from first tab or right from last tab
    if (dir == '-' and curr == 1) or (dir == '+' and curr == last) then return end

    vim.cmd('tabmove' .. dir)
    tabpage.update_name_list()
end

---Save tabpage names to a global variable
function tabpage.save_to_global() vim.g.TabpageNames = vim.json.encode(tabpage.names) end

---Load tabpage names from a global variable
function tabpage.load_from_global()
    local ok, names_to_load = pcall(vim.json.decode, vim.g.TabpageNames)
    if not ok then
        require('self.notify').error('Failed to parse JSON: ' .. vim.inspect(vim.g.TabpageNames))
        return
    end
    vim.g.TabpageNames = nil
    tabpage.names = names_to_load
    vim.iter(ipairs(tabpage.names)):each(tabpage.set_name)
end

return tabpage
