"---------------------------------------- CLI-TOOL LAUNCHER ---------------------------------------"
" Launch command-line tool in a full-screen float

let s:active = {}
let s:win_id = 0
let s:last_used = 'bash'

" Delete terminal buffer, reset cached variables and remove tool from active list
function! s:on_job_exit(job, _, __) abort
    " Do nothing if Neovim is exiting
    if v:exiting isnot v:null | return | endif
    bwipeout
    let s:win_id = 0
    unlet s:active[s:active->keys()->filter({_,k -> s:active[k].job == a:job})[0]]
endfunction

" Ensure a buffer exists for launching the specified tool
function! s:ensure_buf_exists(tool) abort
    " Skip if a buffer already exists for the tool
    if s:active->has_key(a:tool) | return | endif

    " Create a scratch buffer
    let tool_info = #{ buf: nvim_create_buf(v:false, v:true) }

    " Cache the current buffer and focus on scratch buffer to start a job with command
    const curr = bufnr('%')
    keepalt call nvim_win_set_buf(0, tool_info.buf)
    let tool_info.job = jobstart([a:tool], #{ term: v:true, on_exit: function('s:on_job_exit') })
    setlocal filetype=self_tool_launcher

    " Keymap to suspend tool
    tnoremap <buffer> <M-z> <Cmd>close<CR>

    " Restore cached original buffer
    keepalt call nvim_win_set_buf(0, curr)

    " Cache active tool on success
    let s:active[a:tool] = tool_info
endfunction

" Load the tool buffer in a new or existing float
function! s:float_load_buf(tool) abort
    if s:win_id != 0
        " Set the tool buffer if floating window is already open
        call nvim_win_set_buf(0, s:active[a:tool].buf)
    else
        " Configure floating window to cover entire screen
        const config = #{ relative: 'editor', style: 'minimal',
                            \ width: &columns, height: &lines, row: 0, col: 0 }
        let s:win_id = nvim_open_win(s:active[a:tool].buf, v:true, config)

        " Prevent horizontal scrolling and disable statuscolumn
        setlocal sidescrolloff=0 statuscolumn=
        " Autocommand to clear cached floating window ID
        execute 'autocmd WinClosed' s:win_id '++once let s:win_id = 0'
    endif
endfunction

" Launch the specified tool
function! s:launch(...) abort
    let s:last_used = a:0 == 0 ? s:last_used : a:1
    call s:ensure_buf_exists(s:last_used)
    call s:float_load_buf(s:last_used)
    startinsert
endfunction

" Tool launcher keymaps
nnoremap <M-z> <Cmd>call <SID>launch()<CR>
nnoremap <M-a> <Cmd>call <SID>launch('aider')<CR>
tnoremap <M-a> <Cmd>call <SID>launch('aider')<CR>
nnoremap <M-b> <Cmd>call <SID>launch('bash')<CR>
tnoremap <M-b> <Cmd>call <SID>launch('bash')<CR>
nnoremap <M-l> <Cmd>call <SID>launch('lazygit')<CR>
tnoremap <M-l> <Cmd>call <SID>launch('lazygit')<CR>
nnoremap <M-o> <Cmd>call <SID>launch('opencode')<CR>
tnoremap <M-o> <Cmd>call <SID>launch('opencode')<CR>

" Send SIGKILL to all active tools
function! s:kill_active_tools() abort
    for tool in s:active->values()
        const pid = jobpid(tool.job)
        if pid > 0 | call system(['kill', '-9', string(pid)]) | endif
    endfor
endfunction

" Setup autocommand group
augroup __tool_launcher__
    autocmd!

    " Kill all active tools before exiting neovim
    autocmd VimLeavePre * call <SID>kill_active_tools()

augroup END
