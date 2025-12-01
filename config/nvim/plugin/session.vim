"----------------------------------------- SESSION MANAGER ----------------------------------------"

" Standard directory to store sessions
const s:sessions_dir = stdpath('state') .. '/sessions'
call mkdir(s:sessions_dir, 'p')

" Helper to use notification manager from lua
function! s:notify(type, msg)
    call luaeval(printf("require('self.notify').%s(_A)", a:type), a:msg)
endfunction

" Check if current session only has empty buffers
function! s:is_current_session_empty()
    return nvim_list_bufs()
                \ ->filter({i,v-> nvim_get_option_value('buftype', { 'buf': v }) == ''
                \                 && nvim_buf_get_name(v) != ''})
                \ ->empty()
endfunction

"--------------------- IMPLEMENTATION ---------------------"

let s:session_manager = { 'disabled': v:false }

" Construct session file name from CWD
function! s:session_manager.set_file()
    let session_file = getcwd(-1, -1) " Returns global CWD (not window or tab local)
    let session_file = session_file->substitute('@', '@@', 'g')->substitute('[/\:]', '@', 'g')
    let self.file = printf('%s/%s.vim', s:sessions_dir, session_file)
endfunction

" Save current session
function! s:session_manager.save()
    call self.set_file()
    if self.disabled | return | endif
    if s:is_current_session_empty() | call self.delete() | return | endif

    execute 'mksession!' fnameescape(self.file)
    call s:notify('info', printf('Session saved (%s)', getcwd(-1, -1)))
endfunction

" Load session for CWD
function! s:session_manager.load()
    call self.set_file()
    if self.disabled | return | endif
    if !filereadable(self.file) | call s:notify('warn', 'No session found') | return | endif

    silent %bwipeout!
    try
        execute 'silent source' fnameescape(self.file)
        call s:notify('info', printf('Session loaded (%s)', getcwd(-1, -1)))
    catch
        let self.disabled = v:true
        call s:notify('error', printf('Failed to load session! (%s)\n\n%s',
                    \                   getcwd(-1, -1), v:exception))
    endtry
endfunction

function! s:session_manager.delete()
    call delete(self.file)
endfunction

"--------------------- CMDS & AUTOCMDS --------------------"

" Setup user commands
command! SessionSave call s:session_manager.save()
command! SessionLoad call s:session_manager.load()
command! SessionDelete call s:session_manager.delete()
command! SessionEnable let s:session_manager.disabled = v:false
command! SessionDisable let s:session_manager.disabled = v:true

" Setup autocommands
augroup __session_manager__
    autocmd!

    " Load session on startup (only if no files were specified)
    autocmd VimEnter * ++nested
                \ if argc() > 0 && getcwd() ==# $HOME |
                \     let s:session_manager.disabled = v:true |
                \ endif |
                \ SessionLoad

    " Save session on exit
    autocmd VimLeavePre * SessionSave

augroup END
