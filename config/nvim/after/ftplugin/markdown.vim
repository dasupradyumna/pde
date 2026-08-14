"---------------------------------------- MARKDOWN FTPLUGIN ---------------------------------------"
" Script guard
if exists('b:user_ftplugin') | finish | endif
let b:user_ftplugin = 1

" Undo built-in filetype plugin logic
execute b:undo_ftplugin
unlet b:did_ftplugin

" Enable HTML support
runtime! ftplugin/html.vim

" Support auto-extending quote blocks
setlocal comments=n:>

" Configure render and indent options
setlocal conceallevel=3 concealcursor=c " For pretty visual formatting
setlocal shiftwidth=2 softtabstop=-1 " Reduce indent to 2 spaces

"---------------------------- TEXT FORMATTING ----------------------------"
" TODO: use surround plugin for this
" FIX: preserve cursor position
" nnoremap <buffer> <M-b> bi**<Esc>ea**<Esc>
" nnoremap <buffer> <M-i> bi*<Esc>ea*<Esc>
" nnoremap <buffer> <M-e> bi`<Esc>ea`<Esc>
" nnoremap <buffer> <M-s> bi~<Esc>ea~<Esc>
" " nnoremap <buffer> <LocalLeader>i

"---------------------------- HEADING TOGGLER ----------------------------"

function! s:toggle_heading(level) abort
    let line = getline('.')
    let current_level = strlen(matchstr(line, '^#*'))
    if a:level == 0 || current_level == a:level
        " If desired level is 0 or current line heading matches desired level, remove the heading
        let line = substitute(line, '^#\+ ', '', '')
    elseif current_level == 0
        " If there's no heading, add one with the desired level
        let line = repeat('#', a:level) .. ' ' .. line
    else
        " If there's a heading but different level, update it
        let line = substitute(line, '^#\+', repeat('#', a:level), '')
    endif
    call setline('.', line)
endfunction

nnoremap <buffer> <C-`> <Cmd>call <SID>toggle_heading(0)<CR>
nnoremap <buffer> <C-1> <Cmd>call <SID>toggle_heading(1)<CR>
nnoremap <buffer> <C-2> <Cmd>call <SID>toggle_heading(2)<CR>
nnoremap <buffer> <C-3> <Cmd>call <SID>toggle_heading(3)<CR>
nnoremap <buffer> <C-4> <Cmd>call <SID>toggle_heading(4)<CR>
