"-------------------------------------- GENERAL AUTO-COMMANDS -------------------------------------"

" Trim all trailing whitespace characters in the active file
const s:trim_exclude = ['gitcommit', 'markdown']
function! s:trim_trailing_whitespace()
    if s:trim_exclude->index(&l:filetype) >= 0 | return | endif

    let view = winsaveview()
    %substitute:\s\+$::e
    call winrestview(view)
endfunction

