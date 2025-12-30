"----------------------------------------- CUSTOM KEYMAPS -----------------------------------------"

" Disable <Space> and <BS> outside insertion
map <Space> <NOP>
map <BS> <NOP>

" Easier command mode
noremap ; :
noremap : ;

" Swap marks (line and character)
noremap ' `
noremap ` '

" Replace <Esc> with <C-;> - more uniform across modes
noremap <C-;> <C-\><C-n>
noremap! <C-;> <C-\><C-n>
tnoremap <C-;> <C-\><C-n>
map <Esc> <NOP>
map! <Esc> <NOP>

" Clear search highlight
nnoremap <Leader>/ <Cmd>nohlsearch<CR>

" Close window convenience
nnoremap <C-Q> <C-W>q

"--------------------------------- NAVIGATION ---------------------------------"

" Swap start-of-line and first-character
noremap 0 ^
noremap ^ 0

" Swap end-of-line and last-character
noremap $ g_
noremap g_ $

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
nnoremap <C-R> <NOP>

" Cursor movement in insert mode
" - <C-G>U prevents undo block creation on line breaks
inoremap <Left> <C-G>U<Left>
inoremap <Right> <C-G>U<Right>
imap <C-H> <Left>
imap <C-J> <Down>
imap <C-K> <Up>
imap <C-L> <Right>

" System clipboard helpers
nnoremap <Leader>cc "+y
nnoremap <Leader>cx "+d
nnoremap <Leader>cp "+p
nnoremap <Leader>cP "+P
xnoremap <Leader>cc "+y
xnoremap <Leader>cx "+d
xnoremap <Leader>cp "+p
xnoremap <Leader>cP "+P

"----------------------------------- TABPAGE ----------------------------------"

nnoremap <C-T>c <Cmd>lua require('self.tabpage').create()<CR>
nnoremap <C-T>r <Cmd>lua require('self.tabpage').rename()<CR>
nnoremap <C-T>q <Cmd>tabclose<CR>
nnoremap <C-T>Q <Cmd>windo bwipeout!<CR>
nnoremap <C-T>o <Cmd>tabonly<CR>

" Tab navigation and ordering
nnoremap <C-T>p <Cmd>tabnext #<CR>
nnoremap <C-T>h <Cmd>tabprevious<CR>
nnoremap <C-T>j <Cmd>lua require('self.tabpage').move('-')<CR>
nnoremap <C-T>k <Cmd>lua require('self.tabpage').move('+')<CR>
nnoremap <C-T>l <Cmd>tabnext<CR>
nnoremap <C-T>1 <Cmd>tabnext 1<CR>
nnoremap <C-T>2 <Cmd>tabnext 2<CR>
nnoremap <C-T>3 <Cmd>tabnext 3<CR>
nnoremap <C-T>4 <Cmd>tabnext 4<CR>
nnoremap <C-T>5 <Cmd>tabnext 5<CR>
nnoremap <C-T>6 <Cmd>tabnext 6<CR>
nnoremap <C-T>7 <Cmd>tabnext 7<CR>
nnoremap <C-T>8 <Cmd>tabnext 8<CR>
nnoremap <C-T>9 <Cmd>tabnext 9<CR>
