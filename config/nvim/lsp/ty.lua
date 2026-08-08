------------------------------------------- TY LSP CONFIG ------------------------------------------

---@type vim.lsp.Config
return {
    cmd = { 'ty', 'server' },
    filetypes = { 'python' },
    root_markers = { '.git', 'requirements.txt', 'ty.toml', 'pyproject.toml', 'setup.py' },
    settings = {
        ty = {
            -- configuration = {},
            completions = { completeFunctionParentheses = true },
        },
    },
    -- init_options = {
    --     logFile = vim.fs.joinpath(vim.fn.stdpath 'state', 'ty.log'),
    --     logLevel = 'trace',
    -- },
}
