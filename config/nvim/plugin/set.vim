"---------------------------------------- BUILT-IN OPTIONS ----------------------------------------"

set number
set noruler
set scrolloff=4
set ignorecase
set history=100
set sessionoptions=buffers,folds,globals,help,tabpages,winsize
set shada=!,'100,<10,h,s10
" XXX: continue with usr_21

" fold method
" TODO: display foldcolumn in statuscolumn
set foldexpr=v:lua.vim.treesitter.foldexpr()
set foldlevelstart=99
set foldopen+=insert,jump
set foldtext=

" edit formatting
set backspace+=nostop
set expandtab
set shiftwidth=4
set softtabstop=-1
set textwidth=100
set colorcolumn=+1

" custom tabline
function TempTabLine()
    let s = ''
    for i in nvim_list_tabpages()
        " tab highlight
        let s ..= i == nvim_get_current_tabpage() ? '%#TabLineSel#' : '%#TabLine#'
        try | let name = nvim_tabpage_get_var(i, 'tabpage_name')
        catch | let name = '[no name]' | endtry
        let s ..= ' ' .. name .. ' '
    endfor
    " empty fill highlight
    let s ..= '%#TabLineFill#'
    return s
endfunction
set tabline=%!TempTabLine()
set showtabline=2

" temporary highlights
highlight! link WinSeparator Normal
highlight! link NormalFloat Normal
