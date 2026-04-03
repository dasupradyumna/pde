----------------------------------------- DIAGNOSTICS SETUP ----------------------------------------
--- Refer :h diagnostic.txt

local pretty_source = {
    ['Lua Diagnostics.'] = 'lua_ls',
    ['Lua Syntax Check.'] = 'lua_ls',
}

vim.diagnostic.config {
    virtual_text = { spacing = 2, prefix = ' ', format = function () return '' end },
    virtual_lines = { current_line = true, format = function (diag) return diag.message end },
    signs = false,
    float = {
        severity_sort = true,
        header = '',
        prefix = ' ',
        suffix = ' ',
        border = 'rounded',
        format = function (diag)
            return ('%s: %s%s'):format(
                pretty_source[diag.source] or diag.source,
                diag.message,
                diag.code and (' [' .. diag.code .. ']') or ''
            )
        end,
    },
    update_in_insert = true,
    severity_sort = true,
}
