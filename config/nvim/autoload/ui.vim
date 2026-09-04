"------------------------------------------ UI COMPONENTS -----------------------------------------"

" Statuscolumn option format string
" > sign-column | line-number | fold-column
function! ui#statuscolumn()
    let fold = '  '
    if foldclosed(v:lnum) == v:lnum
        let fold = ' '
    elseif foldlevel(v:lnum) > foldlevel(v:lnum - 1)
        let fold = ' '
    endif

    return ' %=%s%=%l %#FoldColumn#' .. fold
endfunction

" Statusline option format string
function! ui#statusline()
    return '%= %l/%L,%02c '
endfunction

" Tabline option format string
" > [tab-names] | show-cmd
function ui#tabline()
    let tabline = '%10(%)%='
    let n_chars = 0
    for tab in nvim_list_tabpages()
        " Tab name highlight
        let tabline ..= tab == nvim_get_current_tabpage() ? '%#TabLineSel#' : '%#TabLine#'
        let name = v:lua.require('self.tabpage').get_name(tab, 'NO_NAME')
        let name = name != '' ? name : 'NO_NAME'
        let tabline ..= ' ' .. name .. ' '
        let n_chars += len(name) + 2
    endfor

    " Reset the tabline highlight after names
    let tabline ..= '%#TabLineFill#'
    " Display the `showcmd` string
    let tabline ..= '%=%10(%S%) '
    return tabline
endfunction

"--------------------------- WINBAR COMPONENTS ---------------------------"

let s:winbar = {}

" Return the formatted buffer name
function! s:winbar.bufname()
    if &l:filetype == 'help' | return 'HELP: ' .. expand('%:t:r')->toupper() | endif
    return expand('%:.')
endfunction

" Render diagnostic count for different types with respective highlights
let s:winbar.diagnostic = #{ draw: [['Error', 'X'], ['Warn', '!'], ['Info', 'i'], ['Hint', '?']] }
function! s:winbar.diagnostic.info()
    let data = v:lua.vim.diagnostic.count(0)
    if data->empty() | return '' | endif

    return data->map({i,count -> [self.draw[i][0], self.draw[i][1], count]})
                \ ->filter('type(v:val[2]) == 0')
                \ ->map({_,v -> printf('%%#Diagnostic%s#%s %d', v[0], v[1], v[2])})
                \ ->join()
endfunction

" Compute the highlighted format string with git status for current buffer
let s:winbar.gitsigns = #{ draw: { '+': 'Add', '~': 'Change', '-': 'Delete' } }
function! s:winbar.gitsigns.info()
    let data = b:->get('gitsigns_status', '')->split()
    if data->empty() | return '' | endif

    return data->map({_,v -> printf('%%#GitSigns%s#%s', self.draw[v[0]], v)})->join()
endfunction

" Winbar option format string
" > buffer-name | diagnostic-info | ... | git-signs-info
function! ui#winbar()
    let modified = &l:modified ? '%#@markup.italic#' : ''  " TODO: add bold here, remove from winbar
    return printf(' %s %s   %s%%=%s ',
                \ modified,
                \ s:winbar.bufname(),
                \ s:winbar.diagnostic.info(),
                \ s:winbar.gitsigns.info())
endfunction
