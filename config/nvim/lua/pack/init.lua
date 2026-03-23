------------------------------------- SIMPLE PLUGINS -----------------------------------------------

return {
    {
        'nvim-treesitter/nvim-treesitter',
        lazy = false,
        build = ':TSUpdate',
        config = function ()
            local treesitter = require('nvim-treesitter')
            treesitter.setup()
            treesitter.install {
                'bash', 'lua', 'python', 'vim',           -- Scripting languages
                'markdown', 'markdown_inline', 'vimdoc',  -- Documentation
                'c', 'cpp', 'cuda', 'rust',               -- Low-level languages
                'cmake', 'make',                          -- Build tools
                'json', 'toml', 'xml', 'yaml',            -- Configuration
            }
        end,
    },
    {
        'lewis6991/gitsigns.nvim',
        opts = {
            attach_to_untracked = true,
            current_line_blame = true,
            current_line_blame_opts = { delay = 250, virt_text_pos = 'right_align' },
            current_line_blame_formatter = '<author> (<author_time>) :: <summary>',
            current_line_blame_formatter_nc = '[ not committed ]',
            numhl = true,
            signcolumn = false,

            on_attach = function (bufnr)
                local function nnoremap(k, cb, ...)
                    local args = { ... }
                    local cb_ = #args > 0 and function () cb(unpack(args)) end or cb
                    vim.keymap.set('n', k, cb_, { buffer = bufnr })
                end
                local gs = require 'gitsigns'
                nnoremap('<Leader>gl', gs.toggle_current_line_blame)
                nnoremap('<Leader>gp', gs.preview_hunk_inline)
                nnoremap('<Leader>gn', gs.nav_hunk, 'next')
                nnoremap('<Leader>gN', gs.nav_hunk, 'prev')
                nnoremap('<Leader>gs', gs.stage_hunk)
                nnoremap('<Leader>gr', gs.reset_hunk)
                -- Hunk text object for operator and visual modes
                vim.keymap.set({ 'o', 'x' }, 'ih', gs.select_hunk)
            end,
        },
    },
}
