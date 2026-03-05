------------------------------------- BLINK.CMP AUTOCOMPLETION -------------------------------------

--- Show completion window if the character preceding the cursor is a keyword
--- @return boolean
local function show_if_preceding_is_keyword(cmp)
    local col = vim.api.nvim_win_get_cursor(0)[2]
    if (col == 0 or vim.api.nvim_get_current_line():sub(col, col):match '%s') then
        return false
    end
    return cmp.show()
end

local kind_map = {
    Class = 'CLS',
    Color = 'CLR',
    Constant = 'CON',
    Constructor = 'CTR',
    Enum = 'ENM',
    EnumMember = 'ENM',
    Event = 'EVT',
    Field = 'FLD',
    File = 'FIL',
    Folder = 'FOL',
    Function = 'FUN',
    Interface = 'INT',
    Keyword = 'KEY',
    Method = 'MTH',
    Module = 'MOD',
    Operator = 'OPR',
    Property = 'PRP',
    Reference = 'REF',
    Snippet = 'SNP',
    Struct = 'STR',
    Text = 'TXT',
    TypeParameter = 'TYP',
    Unit = 'UNT',
    Value = 'VAL',
    Variable = 'VAR',
}

return {
    'saghen/blink.cmp',
    version = '1.*',
    opts = {
        keymap = {
            preset = 'none',
            ['<Tab>'] = { 'accept', 'fallback' },
            ['<C-E>'] = { show_if_preceding_is_keyword, 'cancel', 'fallback' },
            ['<C-N>'] = { 'select_next', 'fallback_to_mappings' },
            ['<C-P>'] = { 'select_prev', 'fallback_to_mappings' },
            ['<C-U>'] = { 'scroll_documentation_up', 'fallback' },
            ['<C-D>'] = { 'scroll_documentation_down', 'fallback' },
            ['<C-F>'] = { 'snippet_forward', 'fallback' },
            ['<C-B>'] = { 'snippet_backward', 'fallback' },
        },
        completion = {
            trigger = {
                show_on_backspace_in_keyword = true,
                show_on_blocked_trigger_characters = function () return { ' ', '\n', '\t' } end,
                show_on_x_blocked_trigger_characters = function () return { '"', "'", '(' } end,
            },
            list = { max_items = 50, selection = { preselect = false } },
            menu = {
                min_width = 25,
                border = 'rounded',
                winblend = 20,
                winhighlight = 'Search:None',
                draw = {
                    gap = 2,
                    snippet_indicator = '',
                    treesitter = { 'lsp' },
                    columns = { { 'kind' }, { 'label' }, { 'label_description' } },
                    components = {
                        kind = {
                            width = { min = 3, max = 3 },
                            text = function (ctx) return kind_map[ctx.kind] end,
                        },
                        label = {
                            text = function (ctx)
                                if #ctx.label_detail > 0 then
                                    return ('%s (%s)'):format(ctx.label, ctx.label_detail)
                                end
                                return ctx.label
                            end,
                        },
                    },
                },
            },
            documentation = {
                auto_show = true,
                auto_show_delay_ms = 100,
                window = {
                    min_width = 25,
                    border = 'rounded',
                    winblend = 20,
                    winhighlight = 'Search:None',
                },
            },
        },
        signature = {
            enabled = true,
            window = {
                min_width = 25,
                max_width = 80,
                max_height = 15,
                border = 'rounded',
                winblend = 20,
                winhighlight = 'Search:None',
                scrollbar = true,
            },
        },
        sources = {  -- TODO: add community sources (after built-in is configured)
            default = { 'lsp', 'path', 'snippets', 'buffer' },
            min_keyword_length = 2,
            providers = {
                lsp = { score_offset = 5 },
                path = { opts = { show_hidden_files_by_default = true } },
                snippets = { score_offset = 10 },
            },
        },
        cmdline = {
            keymap = {
                preset = 'inherit',
                ['<C-N>'] = { 'select_next', 'fallback' },
                ['<C-P>'] = { 'select_prev', 'fallback' },
            },
            completion = {
                list = { selection = { preselect = false } },
                menu = { auto_show = true },
            },
        },
        -- NOTE: not very useful, and buggy in TUI apps since cursor does not define typing position
        -- term = {
        --     enabled = true,
        --     keymap = {
        --         ['<C-N>'] = { 'select_next', 'fallback' },
        --         ['<C-P>'] = { 'select_prev', 'fallback' },
        --     },
        --     sources = { 'buffer', 'path' },
        --     completion = {
        --         list = { selection = { preselect = false, auto_insert = true } },
        --         menu = { auto_show = true },
        --         -- ghost_text = { enabled = true }, -- XXX: cannot cycle through items as of now.
        --     },
        -- },
    },
    opts_extend = { 'source.default' },
}
