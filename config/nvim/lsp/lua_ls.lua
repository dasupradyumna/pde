----------------------------------------- LUA-LS LSP CONFIG ----------------------------------------
--- TODO: move formatting and style checking configs to a project root file like .luarc.json ?

---@type vim.lsp.Config
return {
    cmd = { 'lua-language-server' },
    filetypes = { 'lua' },
    root_markers = {
        { '.git' },
        { '.emmyrc.json', '.luarc.json',  '.luarc.jsonc' },
        { '.luacheckrc',  '.stylua.toml', 'stylua.toml', 'selene.toml', 'selene.yml' },
    },
    -- Refer: https://luals.github.io/wiki/settings
    settings = {
        Lua = {
            addonManager = { enable = false },
            codeLens = { enable = true },
            completion = { callSnippet = 'Replace', keywordSnippet = 'Replace' },
            diagnostics = {
                -- Refer: https://luals.github.io/wiki/diagnostics
                neededFileStatus = {
                    ['lowercase-global'] = 'None',
                    -- Enable style checking
                    ['codestyle-check'] = 'Opened',
                    ['name-style-check'] = 'Opened',
                },
                unusedLocalExclude = { '_', '__', '___' },
                workspaceEvent = 'OnChange',
            },
            -- doc = {}, -- TODO: revisit when developing a plugin
            format = {
                -- Refer: https://github.com/CppCXY/EmmyLuaCodeStyle/blob/master/docs/format_config_EN.md
                defaultConfig = {
                    indent_style = 'space',
                    indent_size = '4',
                    quote_style = 'single',
                    call_arg_parentheses = 'remove_table_only',
                    continuation_indent = '8',
                    max_line_length = '100',
                    trailing_table_separator = 'smart',
                    space_before_closure_open_parenthesis = 'true',
                    space_before_inline_comment = '2',
                    never_indent_comment_on_if_branch = 'true',
                    break_all_list_when_line_exceed = 'true',
                },
            },
            hint = { enable = true, setType = true },
            hover = { enumsLimit = 10 },
            nameStyle = {
                -- Refer: https://github.com/CppCXY/EmmyLuaCodeStyle/blob/master/docs/name_style_EN.md
                config = {
                    local_name_style = { 'snake_case', 'upper_snake_case' },
                    function_param_name_style = {
                        'snake_case',
                        { type = 'ignore', param = { '_' } },
                    },
                    table_field_name_style = { 'snake_case', 'camel_case', 'pascal_case' },
                    global_variable_name_style = { 'upper_snake_case' },
                    class_name_style = { 'pascal_case' },
                },
            },
            runtime = {
                path = { 'lua/?.lua', 'lua/?/init.lua' },
                pathStrict = true,
                version = 'LuaJIT',
            },
            workspace = {
                checkThirdParty = 'Disable',
                -- Refer: https://github.com/neovim/nvim-lspconfig/issues/3189
                -- TODO: This may need to be updated when working on a plugin
                library = vim.tbl_filter(function (path)
                        local config_path = vim.fn.stdpath('config')
                        return path ~= config_path and path ~= (config_path .. '/after')
                    end,
                    vim.api.nvim_get_runtime_file('', true)),
            },
        },
    },
}
