"---------------------------------------- CLI-TOOL LAUNCHER ---------------------------------------"
" Launch command-line tool in a full-screen float

let s:tool2buf = {}
let s:win_id = 0
let s:last_used = 'lazygit'

" Ensure a buffer exists for launching the specified tool
function! s:ensure_buf_exists(tool) abort
    " Skip if a buffer already exists for the tool
    if s:tool2buf->has_key(a:tool) | return | endif

    " Create a scratch buffer
    const buf = nvim_create_buf(v:false, v:true)
    let s:tool2buf[a:tool] = buf

    " Cache the current buffer and focus on scratch buffer to start a job with command
    const curr = bufnr('%')
    keepalt call nvim_win_set_buf(0, buf)
    call jobstart([a:tool], #{ term: v:true })

    " Keymap to suspend tool and autocommand to clear cached its buffer ID
    tnoremap <buffer> <M-z> <Cmd>close<CR>
    execute 'autocmd TermClose <buffer>'
                \ printf('unlet s:tool2buf["%s"] | let s:win_id = 0 | bwipeout', a:tool)

    " Restore cached original buffer
    keepalt call nvim_win_set_buf(0, curr)
endfunction

" Load the tool buffer in a new or existing float
function! s:float_load_buf(tool) abort
    if s:win_id != 0
        " Set the tool buffer if floating window is already open
        call nvim_win_set_buf(0, s:tool2buf[a:tool])
    else
        " Configure floating window to cover entire screen
        const config = #{ relative: 'editor', width: &columns, height: &lines - 2, row: 0, col: 0 }
        let s:win_id = nvim_open_win(s:tool2buf[a:tool], v:true, config)

        " Prevent horizontal scrolling
        setlocal sidescrolloff=0
        " Autocommand to clear cached floating window ID
        execute 'autocmd WinClosed' s:win_id '++once let s:win_id = 0'
    endif
endfunction

" Launch the specified tool
function! s:launch(...) abort
    let tool = a:0 == 0 ? s:last_used : a:1
    let s:last_used = tool
    call s:ensure_buf_exists(tool)
    call s:float_load_buf(tool)
    startinsert
endfunction

" Tool launcher keymaps
nnoremap <M-z> <Cmd>call <SID>launch()<CR>
nnoremap <M-a> <Cmd>call <SID>launch('aider')<CR>
tnoremap <M-a> <Cmd>call <SID>launch('aider')<CR>
nnoremap <M-l> <Cmd>call <SID>launch('lazygit')<CR>
tnoremap <M-l> <Cmd>call <SID>launch('lazygit')<CR>
nnoremap <M-o> <Cmd>call <SID>launch('opencode')<CR>
tnoremap <M-o> <Cmd>call <SID>launch('opencode')<CR>
