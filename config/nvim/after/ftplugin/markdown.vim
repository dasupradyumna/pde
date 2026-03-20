"---------------------------------------- MARKDOWN FTPLUGIN ---------------------------------------"
" Script guard
if exists('b:user_ftplugin') | finish | endif
let b:user_ftplugin = 1

setlocal conceallevel=3 concealcursor=c " For pretty visual formatting
setlocal shiftwidth=2 softtabstop=-1 " Reduce indent to 2 spaces

" Keymaps for text formatting
" FIX: preserve cursor position
nnoremap <buffer> <M-b> bi**<Esc>ea**<Esc>
nnoremap <buffer> <M-i> bi*<Esc>ea*<Esc>
nnoremap <buffer> <M-e> bi`<Esc>ea`<Esc>
nnoremap <buffer> <M-s> bi~<Esc>ea~<Esc>
" nnoremap <buffer> <LocalLeader>i
