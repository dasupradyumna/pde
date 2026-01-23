"---------------------------------------- CLI-TOOL LAUNCHER ---------------------------------------"

" Mapping from tool name to buffer ID
let s:tool2buf = {}
let s:win_id = 0

" Create a buffer for launching the specified tool
function! s:create_buf(tool)
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
    execute 'autocmd TermClose <buffer> ++once'
                \ printf('unlet s:tool2buf["%s"] | let s:win_id = 0 | bwipeout', a:tool)

    " Restore cached original buffer
    keepalt call nvim_win_set_buf(0, curr)
endfunction

" Open a floating window for specified tool
function! s:open_win(tool)
    " Set the tool buffer if floating window is already open
    if s:win_id != 0 | call nvim_win_set_buf(0, s:tool2buf[a:tool]) | return | endif

    " Configure floating window to cover entire screen
    const win_config = #{ relative: 'editor', width: &columns, height: &lines - 2, row: 0, col: 0 }
    let s:win_id = nvim_open_win(s:tool2buf[a:tool], v:true, win_config)

   " Window-local options to prevent horizontal scrolling and correct background highlight
    setlocal sidescrolloff=0
    setlocal winhighlight=NormalFloat:Normal

    " Autocommand to clear cached floating window ID
    execute 'autocmd WinClosed' s:win_id '++once let s:win_id = 0'
endfunction

" Launch the specified tool
function! s:launch(tool)
    call s:create_buf(a:tool)
    call s:open_win(a:tool)
    startinsert
endfunction

" Tool launcher keymaps
nnoremap <M-a> <Cmd>call <SID>launch('aider')<CR>
tnoremap <M-a> <Cmd>call <SID>launch('aider')<CR>
nnoremap <M-l> <Cmd>call <SID>launch('lazygit')<CR>
tnoremap <M-l> <Cmd>call <SID>launch('lazygit')<CR>
nnoremap <M-o> <Cmd>call <SID>launch('opencode')<CR>
tnoremap <M-o> <Cmd>call <SID>launch('opencode')<CR>
