"-------------------------------------- GENERAL AUTO-COMMANDS -------------------------------------"

" Trim all trailing whitespace characters in the active file
const s:trim_deny_filetypes = ['gitcommit', 'markdown']
function! s:trim_trailing_whitespace() abort
    if s:trim_deny_filetypes->index(&l:filetype) >= 0 | return | endif

    let view = winsaveview()
    %substitute:\s\+$::e
    call winrestview(view)
endfunction

" Toggle cursorline locally based on argument
const s:cursorline_exclude = ['qf']
function! s:toggle_cursorline(enable) abort
    if s:cursorline_exclude->index(&l:filetype) >= 0 | return | endif

    if a:enable | setlocal cursorline | else | setlocal nocursorline | endif
endfunction

" Enable treesitter in buffer if filetype is supported
const s:treesitter_allow_filetypes = ['sh', 'jsonc']
function! s:enable_treesitter(ft) abort
    if !v:lua.vim.treesitter.language.add(a:ft) && s:treesitter_allow_filetypes->index(a:ft) < 0
        return
    endif

    lua vim.treesitter.start()
    setlocal foldmethod=expr
    if a:ft != 'vim'  " NOTE: Treesitter indenting for Vimscript is terrible
        setlocal indentexpr=v:lua.require('nvim-treesitter').indentexpr()
    endif
endfunction

" Enable winbar in normal and help buffers
const s:winbar_allow_buftypes = ['', 'help']
function! s:enable_winbar() abort
    if nvim_win_get_config(0).relative != '' | return | endif
    if exists('w:contained_bufnr') && w:contained_bufnr == bufnr() | return | endif

    let w:contained_bufnr = bufnr()
    if s:winbar_allow_buftypes->index(&l:buftype) >= 0 | setlocal winbar=%{%ui#winbar()%} | endif
endfunction

augroup __self__general__
    autocmd!

    " Auto-read external updates into a buffer
    autocmd WinEnter * checktime %

    " Trim trailing whitespace just before saving
    autocmd BufWritePre * call s:trim_trailing_whitespace()

    " Enable cursorline only in current window
    autocmd VimEnter,WinEnter * call s:toggle_cursorline(v:true)
    autocmd WinLeave * call s:toggle_cursorline(v:false)

    " Try to enable treesitter on filetype
    autocmd FileType * call s:enable_treesitter(expand('<amatch>'))

    " Configure winbar in desired windows / buffers
    autocmd BufEnter * call s:enable_winbar()
    autocmd TermOpen * setlocal winbar=  " NOTE: Ensure that terminal buffers do not have winbar

"----------------------------------- TABPAGE ----------------------------------"

    " Update tabpage name list when a tabpage is closed
    autocmd TabClosed * lua require('self.tabpage').update_name_list()

    " Set default tabpage name if no session is loaded
    autocmd VimEnter *
                \ if !exists('g:SessionLoad') && !v:lua.require('self.tabpage').has_name(0) |
                \     call v:lua.require('self.tabpage').set_name(0, 'main') |
                \     call v:lua.require('self.tabpage').update_name_list() |
                \ endif

augroup END
