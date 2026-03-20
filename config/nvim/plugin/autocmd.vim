"-------------------------------------- GENERAL AUTO-COMMANDS -------------------------------------"

" Trim all trailing whitespace characters in the active file
const s:trim_exclude_ft = ['gitcommit', 'markdown']
function! s:trim_trailing_whitespace()
    if s:trim_exclude_ft->index(&l:filetype) >= 0 | return | endif

    let view = winsaveview()
    %substitute:\s\+$::e
    call winrestview(view)
endfunction

" Toggle cursorline locally based on argument
const s:cursorline_exclude = []
function! s:toggle_cursorline(enable)
    if s:cursorline_exclude->index(&l:filetype) >= 0 | return | endif

    if a:enable | setlocal cursorline | else | setlocal nocursorline | endif
endfunction

" Enable treesitter in buffer if filetype is supported
const s:allowed_treesitter_ft = ['sh', 'jsonc']
function! s:enable_treesitter(ft)
    if !v:lua.vim.treesitter.language.add(a:ft) && s:allowed_treesitter_ft->index(a:ft) < 0
        return
    endif

    lua vim.treesitter.start()
    setlocal foldmethod=expr
    setlocal indentexpr=v:lua.require('nvim-treesitter').indentexpr()
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
