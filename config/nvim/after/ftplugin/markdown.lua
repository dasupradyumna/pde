----------------------------------------- MARKDOWN FTPLUGIN ----------------------------------------

-- FIX: indenting in ordered lists is uneven because of multi-character bullet
--      also, retroactive indenting, along with ordered number correction
-- TODO: Extend these insert-mode logic to `o` or `O` as well.
--       On <S-Enter>, new list items must not be inserted, but indent level must be preserved
--       Keymap to switch between the 3 kinds of bullet listing

-- List items (ordered, unordered and checkboxes) must be auto-inserted on <Enter> in insert mode
--
-- List type format:
-- - Unordered bullet: `- `, `* `, `+ `
-- - Ordered bullet: `1. `
--   These bullets must be retroactively re-aligned to the right in the keymap.
--   For example, if number of items exceeds 10 or 100.
-- - Checkbox bullet: (unchecked) `- [ ] `, `* [ ] `, `+ [ ] `, (checked) `- [x] `, `* [x] `, `+ [x] `

-- Each line is indent with bullet and content. L = I B C
-- A. C empty
--   a. B empty
--     1. I=0: [K] -> EXIT                                                              () done
--     2. I>0: clear line -> [K] -> EXIT                                                (i) done
--   b. B non-empty
--     1. I=0: clear line -> EXIT                                                       (b) done
--     2. I>0: clear line -> decrement I -> get B from prev lines -> [IB'] -> EXIT      (ib) done
-- B. C non-empty
--   a. B empty
--     1. I=0: [K] -> EXIT                                                              (c) done
--     2. I>0: get B from prev lines -> decrement I -> [KIB'] -> EXIT                   (ic) done
--   b. B non-empty
--     For all I: [KIB'] -> EXIT                                                        (bc|ibc) done
--
--  B' is (1) B for unordered (2) empty checkbox for checkbox (3) incremented B for ordered
--  K is the key that triggered the keymap

local bullet_patterns = {
    ordered = '^(%s*)(%d+%. )(.*)$',
    checkbox = '^(%s*)([%-%*%+] %[[ xX]] )(.*)$',
    unordered = '^(%s*)([%-%*%+] )(.*)$',
}

---Compute list information from a line
---@param line string Target line content
---@return string indent, string bullet, string content
local function compute_list_info(line)
    -- Check for different kinds of list bullets
    for _, bullet_type in ipairs { 'ordered', 'checkbox', 'unordered' } do
        local i, b, c = line:match(bullet_patterns[bullet_type])
        if i then return i, b, c end
    end

    -- No matches imply absence of list bullet
    local indent = line:match '^(%s*)'
    return indent, '', line:sub(#indent + 1)
end

---Get parent list bullet from previous lines
---@param indent string Whitespace indent
---@return string indent, string bullet
local function get_parent_bullet(indent)
    indent = indent:sub(vim.bo.shiftwidth + 1)
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    while lnum > 1 do
        lnum = lnum - 1
        local i, b, c = compute_list_info(vim.fn.getline(lnum))
        if #i == 0 and #b == 0 and #c == 0 then break end  -- Empty line
        if i == indent and #b > 0 then return i, b end
    end
    return '', ''  -- TODO: check if this return value works
end

-- TODO: implement this
local function increment_bullet(bullet)
    -- ordered: increase by one
    -- checkbox: set unchecked box
    -- unordered: no change
end

---@type table<string, fun(k:string,i:string,b:string):string>
local case_handler = { [''] = function (key) return key end }

function case_handler.i(key) return '<C-U>' .. key end

function case_handler.b() return '<C-U>' end

function case_handler.ib(_, indent, bullet)
    indent, bullet = get_parent_bullet(indent)
    return '<C-U><C-U>' .. indent .. bullet
end

case_handler.c = case_handler['']

function case_handler.ic(key, indent, bullet)
    indent, bullet = get_parent_bullet(indent)
    -- HACK: Need <C-U> to remove auto-indent
    return key .. '<C-U>' .. indent .. bullet
end

function case_handler.bc(key, indent, bullet) return key .. indent .. bullet end

-- HACK: Need <C-U> to remove auto-indent
function case_handler.ibc(key, indent, bullet) return key .. '<C-U>' .. indent .. bullet end

local function handle_list(key)
    local indent, bullet, content = compute_list_info(vim.api.nvim_get_current_line())

    -- Disable behavior if cursor is within indent-bullet region
    if vim.api.nvim_win_get_cursor(0)[2] + 1 <= #indent + #bullet then return key end

    local case = ''
    if #indent > 0 then case = case .. 'i' end
    if #bullet > 0 then case = case .. 'b' end
    if #content > 0 then case = case .. 'c' end

    local out = case_handler[case](key, indent, bullet)
    require('self.notify').warn(vim.inspect(out))

    return out
end

vim.keymap.set('i', '<CR>', function () return handle_list '<CR>' end, { buffer = 0, expr = true })
