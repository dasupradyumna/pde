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
