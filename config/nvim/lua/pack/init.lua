------------------------------------- SIMPLE PLUGINS -----------------------------------------------

return {
    {
        'nvim-treesitter/nvim-treesitter',
        lazy = false,
        build = ':TSUpdate',
        config = function()
            local treesitter = require('nvim-treesitter')
            treesitter.setup()
            treesitter.install {
                'bash', 'lua', 'python', 'vim', -- Scripting languages
                'markdown', 'markdown_inline', 'vimdoc', -- Documentation
                'c', 'cpp', 'cuda', 'rust', -- Low-level languages
                'cmake', 'make', -- Build tools
                'json', 'toml', 'xml', 'yaml', -- Configuration
            }
        end,
    },
}
