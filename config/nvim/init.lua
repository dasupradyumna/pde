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
vim.cmd.colorscheme 'retrobox'

------------------ REMOVE IN V0.12 : LAZY.NVIM BOOTSTRAP ------------------
local data_path = vim.fn.stdpath 'data'
local lazypath = data_path .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    vim.fn.mkdir(data_path .. "/lazy", "p")
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    local out = vim.fn.system({
        "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath
    })
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
            { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
            { out, "WarningMsg" },
            { "\nPress any key to exit..." },
        }, true, {})
        vim.fn.getchar()
        os.exit(1)
    end
end
vim.opt.rtp:prepend(lazypath)
require('lazy').setup('pack', {
    defaults = { cond = not vim.g.user.neovim_git_mode },
    lockfile = data_path .. '/lazy-lock.json',
    dev = { path = '~/neovim_plugins', patterns = { 'dasupradyumna' }, fallback = true },
    install = { colorscheme = { 'retrobox' } },
    ui = { size = { width = 0.999, height = 0.95 }, border = 'rounded' },
})
