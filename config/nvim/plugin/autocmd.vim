"-------------------------------------- GENERAL AUTO-COMMANDS -------------------------------------"

" Trim all trailing whitespace characters in the active file
const s:trim_exclude = ['gitcommit', 'markdown']
function! s:trim_trailing_whitespace()
    if s:trim_exclude->index(&l:filetype) >= 0 | return | endif

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

augroup __user__
    autocmd!

    " Trim trailing whitespace just before saving
    autocmd BufWritePre * call s:trim_trailing_whitespace()

    " Enable cursorline only in current window
    autocmd VimEnter,WinEnter * call s:toggle_cursorline(v:true)
    autocmd WinLeave * call s:toggle_cursorline(v:false)

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
