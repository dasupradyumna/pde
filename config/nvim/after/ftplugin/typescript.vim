"--------------------------------------- TYPESCRIPT FTPLUGIN --------------------------------------"
" Script guard
if exists('b:user_ftplugin') | finish | endif
let b:user_ftplugin = 1

"------------------------- Auto-format using Prettier -------------------------"

const s:config_path = stdpath("config") .. "/tool-cfg/prettier.yaml"

function! s:prettier_format_buffer()
    redir => output
        silent exe "!npx prettier --config" s:config_path "--write" expand("%:p")
    redir END
    if v:shell_error
        call v:lua.vim.notify("Formatting failed!" .. output, 3)
    endif
endfunction

autocmd BufWritePost <buffer> call s:prettier_format_buffer()
