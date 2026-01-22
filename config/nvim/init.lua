--------------------------------------- NEOVIM CONFIGURATION ---------------------------------------

-- global user data
vim.g.user = vim.g.user or vim.empty_dict()

-- Setting keymap leader before lazy.nvim setup
vim.g.mapleader = ' '
vim.g.maplocalleader = ':'

-- Custom filetypes
vim.filetype.add {
  filename = { ['docker.build-args'] = 'sh' },
  extension = { launch = 'xml' },
}

-- Temporary colorscheme
vim.cmd.colorscheme 'habamax'
