------------------------------------- SIMPLE PLUGINS -----------------------------------------------

return {
    {
        'dasupradyumna/aurorux.nvim',
        lazy = false,
        priority = 1000,
        config = function ()
            require('aurorux').setup { transparent = true }
            vim.api.nvim_command 'colorscheme aurorux'
        end,
    },
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
            current_line_blame_opts = { delay = 250 },
            current_line_blame_formatter = '   <author> (<author_time>) :: <summary>',
            current_line_blame_formatter_nc = '~ not committed ~',
            numhl = true,
            preview_config = { col = 25, border = 'rounded' },
            signcolumn = false,

            on_attach = function (bufnr)
                local function nnoremap(k, cb, ...)
                    local args = { ... }
                    local cb_ = #args > 0 and function () cb(unpack(args)) end or cb
                    vim.keymap.set('n', k, cb_, { buffer = bufnr })
                end
                local gs = require 'gitsigns'
                nnoremap('<Leader>gb', gs.blame)
                nnoremap('<Leader>gd', gs.diffthis)
                nnoremap('<Leader>gh', gs.preview_hunk)
                nnoremap('<Leader>gH', gs.preview_hunk_inline)
                nnoremap('<Leader>gn', gs.nav_hunk, 'next', { greedy = false })
                nnoremap('<Leader>gN', gs.nav_hunk, 'prev', { greedy = false })
                nnoremap('<Leader>gSn', gs.nav_hunk, 'next', { greedy = false, target = 'staged' })
                nnoremap('<Leader>gSN', gs.nav_hunk, 'prev', { greedy = false, target = 'staged' })
                nnoremap('<Leader>gs', gs.stage_hunk)
                nnoremap('<Leader>gr', gs.reset_hunk)
                -- Hunk text object for operator and visual modes
                vim.keymap.set({ 'o', 'x' }, 'ih', gs.select_hunk)
            end,
        },
    },
}
