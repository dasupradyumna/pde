--------------------------------------- LANGUAGE SERVER SETUP --------------------------------------
--- Refer to https://github.com/neovim/nvim-lspconfig/tree/master/lsp for boilerplate

-- Global settings: applies to all clients
vim.lsp.config['*'] = {
    root_markers = { '.git' }
}

-- Set up keymaps in buffers with an attached language server
local group = vim.api.nvim_create_augroup('__self__lsp__', { clear = true })
-- local extra_trigger_characters = { cpp = { '(' } }
vim.api.nvim_create_autocmd('LspAttach', {
    group = '__self__lsp__',
    callback = function(trigger)
        local buffer = trigger.buf
        local client = assert(vim.lsp.get_client_by_id(trigger.data.client_id))

        -- Enabled inlay hints
        vim.lsp.inlay_hint.enable(true, { bufnr = buffer })

        -- Setup common buffer-local LSP keymaps
        local function nnoremap(k, cb, args)
            vim.keymap.set('n', k, args and function() cb(args) end or cb, { buffer = buffer })
        end
        nnoremap('gd', vim.lsp.buf.definition, { reuse_win = true })
        nnoremap('gD', vim.lsp.buf.declaration) -- XXX: is this worth having?
        nnoremap('gh', vim.lsp.buf.hover, { border = 'rounded' })
        nnoremap('gH', vim.lsp.buf.signature_help, { border = 'rounded' }) -- XXX: worth having?

        -- Enable automatic formatting using LSP formatter
        local group = vim.api.nvim_create_augroup('__self__lsp__', { clear = false })
        vim.api.nvim_clear_autocmds { event = 'BufWritePre', group = group, buffer = buffer }
        if client.server_capabilities.documentFormattingProvider then
            vim.api.nvim_create_autocmd('BufWritePre', {
                group = group,
                buffer = buffer,
                callback = function() vim.lsp.buf.format { buffer = buffer, id = client.id } end
            })
        end

        -- XXX: check if this is needed
        -- Extend trigger characters based on filetype
        -- vim.list_extend(
        --     client.server_capabilities.completionProvider.triggerCharacters,
        --     extra_trigger_characters[vim.bo[buffer].filetype] or {}
        -- )
    end
})

-- Enable all servers defined in LSP folder
for server in vim.fs.dir(vim.fs.joinpath(vim.fn.stdpath 'config', 'lsp')) do
    vim.lsp.enable(server:sub(0, -5))
end

---------------------------- DIAGNOSTICS CONFIG ---------------------------

local pretty_source = {
  ['Lua Diagnostics.'] = 'lua_ls',
  ['Lua Syntax Check.'] = 'lua_ls',
}

vim.diagnostic.config {
  virtual_text = {
    virt_text_pos = 'eol',
    prefix = '',
  },
  signs = false,
  float = {
    focusable = false,
    border = 'rounded',
    header = '',
    source = false,
    format = function(diag)
      return ('%s: %s [%s]'):format(
        pretty_source[diag.source] or diag.source,
        diag.message,
        diag.code
      )
    end,
    prefix = ' ',
    suffix = ' ',
  },
  update_in_insert = true,
  severity_sort = true,
}
