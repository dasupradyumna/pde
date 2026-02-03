"------------------------------------ PERSISTENT TOGGLE SCRATCH -----------------------------------"
" Toggle persistent scratch file in movable float

const s:scratch_file = $HOME .. '/obsidian-vault/scratch.md' " Scratch file path
let s:buf_nr = 0 " Scratch buffer number
let s:win_id = 0 " Floating window ID

" Rotate between left and right float positions
function! s:rotate_win_config() abort
    if s:win_id == 0 | return | endif

    " Left-side: col==0, right-side: col!=0
    let config = nvim_win_get_config(s:win_id)
    let config.col = config.col == 0 ? max([0, &columns - config.width - 2]) : 0
    call nvim_win_set_config(s:win_id, config)
endfunction

" Ensure the scratch buffer exists
function! s:ensure_buf_exists() abort
    " Skip if buffer already exists
    if s:buf_nr != 0 | return | endif

    " Create buffer and load scratch file contents
    const buf = nvim_create_buf(v:false, v:true)
    let s:buf_nr = buf
    call nvim_buf_set_name(buf, s:scratch_file)
    const contents = filereadable(s:scratch_file) ? readfile(s:scratch_file) : []
    call nvim_buf_set_lines(buf, 0, -1, v:false, contents)

    const curr = bufnr('%')
    keepalt call nvim_win_set_buf(0, buf)
    " Ensure scratch buffer has normal editing options
    setlocal swapfile buftype= filetype=markdown
    " Keymap to rotate scratch float between left and right positions
    nnoremap <buffer> <C-R> <Cmd>call <SID>rotate_win_config()<CR>
    " Autocommand to clear cached scratch buffer and float IDs
    autocmd BufWipeout <buffer> let s:buf_nr = 0 | let s:win_id = 0
    " Save changes to scratch automatically - user need not save
    autocmd CursorHold,CursorHoldI <buffer> silent write!
    keepalt call nvim_win_set_buf(0, curr)
endfunction

" Load the scratch buffer in a new or existing float
function! s:float_load_buf() abort
    if s:win_id != 0
        " Set the scratch buffer if floating window is already open
        call nvim_set_current_win(s:win_id)
        call nvim_win_set_buf(0, s:buf_nr)
        return
    endif

    " Configure floating window to cover entire screen
    const config = #{ relative: 'editor', width: &columns / 2 - 5, height: &lines - 4,
                \     row: 0, col: 0, border: 'rounded', title: ' Scratch ', title_pos: 'center' }
    let s:win_id = nvim_open_win(s:buf_nr, v:true, config)

    " Autocommand to clear cached floating window ID
    execute 'autocmd WinClosed' s:win_id '++once let s:win_id = 0'
endfunction

" Scratch keymap
nnoremap <Leader>s <Cmd>call <SID>ensure_buf_exists() <Bar> call <SID>float_load_buf()<CR>
