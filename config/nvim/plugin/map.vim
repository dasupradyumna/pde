"----------------------------------------- CUSTOM KEYMAPS -----------------------------------------"

" Disable <Space> and <BS> outside insertion
map <Space> <NOP>
map <BS> <NOP>

" Easier command mode
noremap ; :
noremap : ;

" Swap marks (line and character) only in normal, visual, and operator modes
nnoremap ' `
nnoremap ` '
xnoremap ' `
xnoremap ` '
onoremap ' `
onoremap ` '

" Replace <Esc> with <C-;> - more uniform across modes
noremap <C-;> <Esc>
noremap! <C-;> <Esc>
tnoremap <C-;> <C-\><C-n>
map <Esc> <NOP>
map! <Esc> <NOP>

" Clear search highlight
nnoremap <Leader>/ <Cmd>nohlsearch<CR>

" Close window convenience
nnoremap <C-Q> <C-W>q
nnoremap <Leader>q <Cmd>qall<CR>

" Rotate windows
nnoremap <C-R> <C-W>r

" Wipe buffers
nnoremap <Leader>bw <Cmd>bwipeout<CR>
nnoremap <Leader>bW <Cmd>%bwipeout<CR>

" Save buffers
nnoremap <Leader>bs <Cmd>write<CR>
nnoremap <Leader>bS <Cmd>wall<CR>

" Rename file in buffer
function! s:rename_buffer()
    let src = expand('%:p')
    let dst = input('Rename src: ', src)
    " Skip if target is empty or same as current file
    if dst->empty() || src == dst | return | endif
    " Handle error when rename fails
    if rename(src, dst) | call notify#error('Rename failed: %s -> %s', src, dst) | endif
    " Replace file and buffer in current window
    silent exe 'write' src '| edit' dst '| bwipeout!' src
    " Delete older file (rename does not, for some reason)
    if delete(src) | call notify#error('Delete failed: %s', src) | endif
endfunction
nnoremap <Leader>br <Cmd>call <SID>rename_buffer()<CR>

"--------------------------------- NAVIGATION ---------------------------------"

" Swap start-of-line and first-character
nnoremap 0 ^
nnoremap ^ 0
xnoremap 0 ^
xnoremap 0 ^
onoremap ^ 0
onoremap ^ 0

" Swap end-of-line and last-character
nnoremap $ g_
nnoremap g_ $
xnoremap $ g_
xnoremap g_ $
onoremap $ g_
onoremap g_ $

" Horizontal scrolling
nnoremap H 5zh
nnoremap L 5zl

" Centered vertical scrolling
nnoremap <C-U> <C-U>zz
nnoremap <C-D> <C-D>zz

" Centered search results
nnoremap n nzz
nnoremap N Nzz

" Window navigation
nnoremap <C-H> <C-W>h
nnoremap <C-J> <C-W>j
nnoremap <C-K> <C-W>k
nnoremap <C-L> <C-W>l

"----------------------------------- EDITING ----------------------------------"

" Split line at cursor
nnoremap K i<CR><Esc>

" Preserve :help map
nnoremap gd K

" Cleaner undo-redo flow (remove undo-line)
nnoremap U <C-R>

" Cursor movement in insert mode
imap <C-H> <Left>
imap <C-J> <Down>
imap <C-K> <Up>
imap <C-L> <Right>
" - Preserve digraph symbol support
inoremap <C-S> <C-K>
" - <C-G>U prevents undo block creation on line breaks
inoremap <Left> <C-G>U<Left>
inoremap <Right> <C-G>U<Right>
" - Ensure <Up> and <Down> works in command-line too
cmap <C-H> <Left>
cmap <C-J> <Down>
cmap <C-K> <Up>
cmap <C-L> <Right>

" System clipboard helpers
nnoremap <Leader>cc "+y
nnoremap <Leader>cx "+d
" nnoremap <Leader>cp "+p
" nnoremap <Leader>cP "+P
xnoremap <Leader>cc "+y
xnoremap <Leader>cx "+d
" xnoremap <Leader>cp "+p
" xnoremap <Leader>cP "+P

"----------------------------------- TABPAGE ----------------------------------"

nnoremap <Leader>tc <Cmd>lua require('self.tabpage').create()<CR>
nnoremap <Leader>tC <C-W>T<Cmd>lua require('self.tabpage').rename()<CR>
nnoremap <Leader>tr <Cmd>lua require('self.tabpage').rename()<CR>
nnoremap <Leader>tq <Cmd>tabclose<CR>
nnoremap <Leader>tQ <Cmd>windo bwipeout!<CR>
nnoremap <Leader>to <Cmd>tabonly<CR>

" Tab navigation and ordering
nnoremap <Leader>tp <Cmd>tabnext #<CR>
nnoremap <Leader>th <Cmd>tabprevious<CR>
nnoremap <Leader>tj <Cmd>lua require('self.tabpage').move('-')<CR>
nnoremap <Leader>tk <Cmd>lua require('self.tabpage').move('+')<CR>
nnoremap <Leader>tl <Cmd>tabnext<CR>
nnoremap <Leader>t1 <Cmd>tabnext 1<CR>
nnoremap <Leader>t2 <Cmd>tabnext 2<CR>
nnoremap <Leader>t3 <Cmd>tabnext 3<CR>
nnoremap <Leader>t4 <Cmd>tabnext 4<CR>
nnoremap <Leader>t5 <Cmd>tabnext 5<CR>
nnoremap <Leader>t6 <Cmd>tabnext 6<CR>
nnoremap <Leader>t7 <Cmd>tabnext 7<CR>
nnoremap <Leader>t8 <Cmd>tabnext 8<CR>
nnoremap <Leader>t9 <Cmd>tabnext 9<CR>
