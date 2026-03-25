"----------------------------------- NOTIFICATION MANAGER (VIM) -----------------------------------"

function! s:notify_with_level(lvl, ...)
    call luaeval(printf("require('self.notify').%s(_A)", a:lvl), call('printf', a:000))
endfunction

function! notify#info(...)
    call call('s:notify_with_level', ['info'] + a:000)
endfunction

function! notify#warn(...)
    call call('s:notify_with_level', ['warn'] + a:000)
endfunction

function! notify#error(...)
    call call('s:notify_with_level', ['error'] + a:000)
endfunction
